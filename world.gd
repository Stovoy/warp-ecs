class_name World
extends RefCounted

var entities: HashSet = HashSet.new()
var systems: Array = []
var systems_by_group: Dictionary = {}
var component_entity_index: Dictionary = {}
var query: QueryBuilder
var relationship_entity_index: Dictionary = {}
var reverse_relationship_index: Dictionary = {}

var query_cache: Dictionary = {}
var query_dependency_index: Dictionary = {}
var version: int = 0
var _pending_entity_updates: Dictionary[int, Entity] = {}

func _init() -> void:
    query = QueryBuilder.new(self)

func _ready() -> void:
    initialize()

func initialize() -> void:
    entities = HashSet.new()
    systems = []
    systems_by_group = {}
    component_entity_index = {}
    relationship_entity_index = {}
    reverse_relationship_index = {}
    query_cache.clear()
    query_dependency_index.clear()
    version = 0
    if not query:
        query = QueryBuilder.new(self)

func process(delta: float, group: String = "") -> void:
    _process_pending_updates()
    if group == "":
        for system in systems:
            if system.active:
                system._handle(delta)
    else:
        if systems_by_group.has(group):
            for system in systems_by_group[group]:
                if system.active:
                    system._handle(delta)

func add_entity(entity: Entity, components = null) -> void:
    entities.add(entity)
    for component_id in entity.components.keys():
        _add_entity_to_index(entity, component_id)
    if components:
        entity.add_components(components)
    for processor in ECS.entity_preprocessors:
        processor.call(entity)
    version += 1
    _on_entity_added(entity)

func add_entities(_entities: Array, components = null) -> void:
    for _entity in _entities:
        add_entity(_entity, components)

func remove_entity(entity: Entity) -> void:
    for processor in ECS.entity_postprocessors:
        processor.call(entity)
    entities.erase(entity)
    for component_key in entity.components.keys():
        _remove_entity_from_index(entity, component_key)
    entity.on_destroy()
    version += 1
    _on_entity_removed(entity)

func disable_entity(entity: Entity) -> Entity:
    entity.enabled = false
    entity.on_disable()
    version += 1
    _on_entity_component_changed(entity, 0)
    return entity

func enable_entity(entity: Entity, components = null) -> void:
    entity.enabled = true
    if components:
        entity.add_components(components)
    entity.on_enable()
    version += 1
    _on_entity_component_changed(entity, 0)

func add_system(system: System) -> void:
    systems.append(system)
    if not systems_by_group.has(system.group):
        systems_by_group[system.group] = []
    systems_by_group[system.group].push_back(system)
    system.setup()

func add_systems(_systems: Array) -> void:
    for _system in _systems:
        add_system(_system)

func remove_system(system: System) -> void:
    systems.erase(system)
    systems_by_group[system.group].erase(system)
    if systems_by_group[system.group].size() == 0:
        systems_by_group.erase(system.group)

func purge(should_free = true, keep := []) -> void:
    for entity in entities.to_array():
        if not keep.has(entity):
            remove_entity(entity)
    for system in systems.duplicate():
        remove_system(system)

func _query(all_components: Array = [], any_components: Array = [], exclude_components: Array = []) -> Array:
    var required_bitmask = 0
    for component in all_components:
        required_bitmask |= (1 << component.component_id)
    var any_bitmask = 0
    for component in any_components:
        any_bitmask |= (1 << component.component_id)
    var exclude_bitmask = 0
    for component in exclude_components:
        exclude_bitmask |= (1 << component.component_id)
    var cache_key = required_bitmask << 48 | any_bitmask << 32 | exclude_bitmask << 16 | (version & 0xFFFF)
    if query_cache.has(cache_key):
        return query_cache[cache_key]
    var candidate_entities: Array = []
    if required_bitmask != 0:
        var required_component_ids: Array = []
        for component in all_components:
            required_component_ids.append(component.component_id)
        var smallest_set: HashSet = null
        for component_id in required_component_ids:
            var component_set = component_entity_index.get(component_id)
            if not component_set or component_set.size() == 0:
                query_cache[cache_key] = []
                return []
            if smallest_set == null or component_set.size() < smallest_set.size():
                smallest_set = component_set
        candidate_entities = smallest_set.to_array()
    elif any_bitmask != 0:
        var union_set: HashSet = HashSet.new()
        for component in any_components:
            var component_set = component_entity_index.get(component.component_id)
            if component_set:
                union_set = union_set.union(component_set)
        candidate_entities = union_set.to_array()
    else:
        candidate_entities = entities.to_array()
    var result: Array = []
    for entity in candidate_entities:
        if not entity.enabled:
            continue
        if required_bitmask != 0 and (entity.component_bitmask & required_bitmask) != required_bitmask:
            continue
        if any_bitmask != 0 and (entity.component_bitmask & any_bitmask) == 0:
            continue
        if exclude_bitmask != 0 and (entity.component_bitmask & exclude_bitmask) != 0:
            continue
        result.append(entity)
    query_cache[cache_key] = result
    return result

func _add_entity_to_index(entity: Entity, component_id: int) -> void:
    if not component_entity_index.has(component_id):
        component_entity_index[component_id] = HashSet.new()
    var entity_hash_set: HashSet = component_entity_index[component_id]
    if not entity_hash_set.contains(entity):
        entity_hash_set.add(entity)

func _remove_entity_from_index(entity: Entity, component_id: int) -> void:
    if component_entity_index.has(component_id):
        var entity_hash_set: HashSet = component_entity_index[component_id]
        entity_hash_set.remove(entity)
        if entity_hash_set.size() == 0:
            component_entity_index.erase(component_id)

func _on_entity_component_added(entity: Entity, component: Component) -> void:
    _add_entity_to_index(entity, component.component_id)

func _on_entity_component_removed(entity: Entity, component: Component) -> void:
    _remove_entity_from_index(entity, component.component_id)

func _on_entity_relationship_added(entity: Entity, relationship: Relationship) -> void:
    var key: int = relationship.relation.component_id
    if not relationship_entity_index.has(key):
        relationship_entity_index[key] = []
    relationship_entity_index[key].append(entity)
    var reverse_key: String = "reverse_" + str(key)
    if relationship.target is Entity:
        var targetComponent: Component = relationship.target.get_component(relationship.relation)
        if targetComponent:
            if not reverse_relationship_index.has(reverse_key):
                reverse_relationship_index[reverse_key] = []
            reverse_relationship_index[reverse_key].append(targetComponent)
    elif relationship.target:
        if not reverse_relationship_index.has(reverse_key):
            reverse_relationship_index[reverse_key] = []
        reverse_relationship_index[reverse_key].append(relationship.target)

func _on_entity_relationship_removed(entity: Entity, relationship: Relationship) -> void:
    var key: int = relationship.relation.component_id
    if relationship_entity_index.has(key):
        relationship_entity_index[key].erase(entity)
    if relationship.target is Entity:
        var reverse_key: String = "reverse_" + str(key)
        if reverse_relationship_index.has(reverse_key):
            reverse_relationship_index[reverse_key].erase(relationship.target)

func _on_entity_added(entity: Entity) -> void:
    var deps = _get_entity_dependency_keys(entity)
    var updated_queries = {}
    for dep in deps:
        if query_dependency_index.has(dep):
            for cache_key in query_dependency_index[dep]:
                updated_queries[cache_key] = true
    for cache_key in updated_queries:
        if query_cache.has(cache_key):
            query_cache[cache_key].update_entity(entity)

func _on_entity_removed(entity: Entity) -> void:
    var deps = _get_entity_dependency_keys(entity)
    var updated_queries = {}
    for dep in deps:
        if query_dependency_index.has(dep):
            for cache_key in query_dependency_index[dep]:
                updated_queries[cache_key] = true
    for cache_key in updated_queries:
        if query_cache.has(cache_key):
            query_cache[cache_key].remove_entity(entity)

func _on_entity_component_changed(entity: Entity, comp_id: int) -> void:
    _pending_entity_updates[entity.get_instance_id()] = entity

func _on_entity_relationship_changed(entity: Entity, relation_comp_id: int) -> void:
    _pending_entity_updates[entity.get_instance_id()] = entity

func _process_pending_updates() -> void:
    if _pending_entity_updates.is_empty():
        return
    var queries_to_update = {}
    for entity in _pending_entity_updates.values():
        var deps = _get_entity_dependency_keys(entity)
        for dep in deps:
            if query_dependency_index.has(dep):
                for cache_key in query_dependency_index[dep]:
                    queries_to_update[cache_key] = true
    for cache_key in queries_to_update.keys():
        if query_cache.has(cache_key):
            for entity in _pending_entity_updates.values():
                query_cache[cache_key].update_entity(entity)
    _pending_entity_updates.clear()

func _register_cached_query(cache_key: int, cq: CachedQuery) -> void:
    for dep in cq.dependencies:
        if not query_dependency_index.has(dep):
            query_dependency_index[dep] = []
        query_dependency_index[dep].append(cache_key)

func _get_entity_dependency_keys(entity: Entity) -> Array:
    var deps = {}
    for comp_id in entity.components.keys():
        deps[comp_id] = true
    for relationship in entity.relationships:
        if relationship.relation:
            deps[-relationship.relation.component_id] = true
    deps[0] = true
    return deps.keys()
