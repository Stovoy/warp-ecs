class_name CachedQuery

var all_components: Array[Script] = []
var any_components: Array[Script] = []
var exclude_components: Array[Script] = []
var relationships: Array[Relationship] = []
var exclude_relationships: Array[Relationship] = []
var all_components_queries: Array[Dictionary] = []
var any_components_queries: Array[Dictionary] = []

# Precomputed bitmask values for the "all", "any" and "exclude" filters.
var required_bitmask: int = 0
var any_bitmask: int = 0
var exclude_bitmask: int = 0

# Set of dependency keys (e.g. "c:12", "r:34", "global").
var dependencies: Array[int] = []

# Live result stored as a Dictionary mapping entity.get_instance_id() → entity.
var result: Dictionary[int, Entity] = {}

var all_component_ids: Array[int] = []
var any_component_ids: Array[int] = []
var exclude_component_ids: Array[int] = []

func _init(all_components: Array[Script], any_components: Array[Script], exclude_components: Array[Script], 
        relationships: Array[Relationship], exclude_relationships: Array[Relationship], 
        all_components_queries: Array[Dictionary], any_components_queries: Array[Dictionary]) -> void:
    self.all_components = all_components
    self.any_components = any_components
    self.exclude_components = exclude_components
    self.relationships = relationships
    self.exclude_relationships = exclude_relationships
    self.all_components_queries = all_components_queries
    self.any_components_queries = any_components_queries

    for comp in all_components:
        var comp_id = comp.component_id
        required_bitmask |= (1 << comp_id)
        all_component_ids.append(comp_id)

    for comp in any_components:
        var comp_id = comp.component_id
        any_bitmask |= (1 << comp_id)
        any_component_ids.append(comp_id)

    for comp in exclude_components:
        var comp_id = comp.component_id
        exclude_bitmask |= (1 << comp_id)
        exclude_component_ids.append(comp_id)

    var deps = {}
    dependencies.clear()

    for comp_id in all_component_ids:
        if not deps.has(comp_id):
            deps[comp_id] = true
            dependencies.append(comp_id)

    for comp_id in any_component_ids:
        if not deps.has(comp_id):
            deps[comp_id] = true
            dependencies.append(comp_id)

    for comp_id in exclude_component_ids:
        if not deps.has(comp_id):
            deps[comp_id] = true
            dependencies.append(comp_id)

    for rel in relationships:
        if rel.relation:
            var id = -rel.relation.component_id
            if not deps.has(id):
                deps[id] = true
                dependencies.append(id)

    for rel in exclude_relationships:
        if rel.relation:
            var id = -rel.relation.component_id
            if not deps.has(id):
                deps[id] = true
                dependencies.append(id)

    if not deps.has(0):
        dependencies.append(0)

# Compute the full result from scratch (used when a query is first created).
func full_update(world: World) -> void:
    var candidates = world._query(all_components, any_components, exclude_components)
    result.clear()
    for entity in candidates:
        if qualifies(entity):
            result[entity.get_instance_id()] = entity

# Returns the result as an Array.
func result_array() -> Array[Entity]:
    return result.values()

# For a single entity, check if it now qualifies and update the result accordingly.
func update_entity(entity: Entity) -> void:
    var eid = entity.get_instance_id()
    if qualifies(entity):
        result[eid] = entity
    else:
        result.erase(eid)

# When an entity is removed, ensure it is no longer in the result.
func remove_entity(entity: Entity) -> void:
    result.erase(entity.get_instance_id())

# Determine whether an entity qualifies for this query.
func qualifies(entity: Entity) -> bool:
    if not entity.enabled:
        return false
    # Bitmask filtering:
    if required_bitmask != 0 and (entity.component_bitmask & required_bitmask) != required_bitmask:
        return false
    if any_bitmask != 0 and (entity.component_bitmask & any_bitmask) == 0:
        return false
    if exclude_bitmask != 0 and (entity.component_bitmask & exclude_bitmask) != 0:
        return false

    # Property queries for "all" components:
    var len_all = all_components.size()
    for i in len_all:
        var comp = entity.get_component(all_components[i])
        if not comp or not _matches_component_query(comp, all_components_queries[i]):
            return false

    # For "any" components, at least one must match:
    if not any_components.is_empty():
        var any_matches = false
        var len_any = any_components.size()
        for i in len_any:
            var comp = entity.get_component(any_components[i])
            if comp and _matches_component_query(comp, any_components_queries[i]):
                any_matches = true
                break
        if not any_matches:
            return false

    # Relationship filters:
    for rel in relationships:
        if not entity.has_relationship(rel):
            return false
    for rel in exclude_relationships:
        if entity.has_relationship(rel):
            return false
    return true

# (Helper functions for property query filtering, similar to your original implementation.)
func _matches_component_query(component: Component, query: Dictionary) -> bool:
    if query.is_empty():
        return true
    for property in query.keys():
        var value = component.get(property)
        if value == null:
            return false
        var property_query = query[property]
        for operator in property_query.keys():
            var condition = property_query[operator]
            if operator == "func":
                if not condition.call(value):
                    return false
            elif operator == "_eq":
                if value != condition:
                    return false
            elif operator == "_gt":
                if value <= condition:
                    return false
            elif operator == "_lt":
                if value >= condition:
                    return false
            elif operator == "_gte":
                if value < condition:
                    return false
            elif operator == "_lte":
                if value > condition:
                    return false
            elif operator == "_ne":
                if value == condition:
                    return false
            elif operator == "_nin":
                if condition.has(value):
                    return false
            elif operator == "_in":
                if not condition.has(value):
                    return false
    return true
