extends RefCounted
class_name QueryBuilder

var _world: World
var _all_components: Array[Script] = []
var _any_components: Array[Script] = []
var _exclude_components: Array[Script] = []
var _relationships: Array[Relationship] = []
var _exclude_relationships: Array[Relationship] = []
var _all_components_queries: Array[Dictionary] = []
var _any_components_queries: Array[Dictionary] = []

func _init(world: World) -> void:
    _world = world

func clear() -> QueryBuilder:
    _all_components.clear()
    _any_components.clear()
    _exclude_components.clear()
    _relationships.clear()
    _exclude_relationships.clear()
    _all_components_queries.clear()
    _any_components_queries.clear()
    return self

func _process_component_list(components: Array) -> Dictionary:
    var result = {
        "components": [] as Array[Script],
        "queries": [] as Array[Dictionary]
    }
    for component in components:
        if component is Dictionary:
            for component_type in component:
                result.components.append(component_type)
                result.queries.append(component[component_type])
        else:
            result.components.append(component)
            result.queries.append({})
    return result

func with_all(components: Array = []) -> QueryBuilder:
    var processed: Dictionary = _process_component_list(components)
    _all_components = processed.components
    _all_components_queries = processed.queries
    return self

func with_any(components: Array = []) -> QueryBuilder:
    var processed: Dictionary = _process_component_list(components)
    _any_components = processed.components
    _any_components_queries = processed.queries
    return self

func with_none(components: Array = []) -> QueryBuilder:
    _exclude_components.clear()
    for component in components:
        if component is Dictionary:
            _exclude_components.append(component.keys()[0])
        else:
            _exclude_components.append(component)
    return self

func with_relationship(relationships: Array = []) -> QueryBuilder:
    _relationships = relationships
    return self

func without_relationship(relationships: Array = []) -> QueryBuilder:
    _exclude_relationships = relationships
    return self

func with_reverse_relationship(relationships: Array = []) -> QueryBuilder:
    for relationship in relationships:
        if relationship.relation != null:
            var reverse_key = "reverse_" + str(relationship.relation.component_id)
            if _world.reverse_relationship_index.has(reverse_key):
                return self.with_all(_world.reverse_relationship_index[reverse_key])
    return self

func _compute_hash_for_query(query: Dictionary) -> int:
    var hash_value = 17
    var keys = query.keys()
    keys.sort()
    for key in keys:
        hash_value = hash_value * 31 + key.hash()
        hash_value = hash_value * 31 + str(query[key]).hash()
    return hash_value

func _compute_cache_key() -> int:
    var hash_value = 17
    var req = 0
    for comp in _all_components:
        req |= (1 << comp.component_id)
    var any_val = 0
    for comp in _any_components:
        any_val |= (1 << comp.component_id)
    var excl = 0
    for comp in _exclude_components:
        excl |= (1 << comp.component_id)
    hash_value = hash_value * 31 + req
    hash_value = hash_value * 31 + any_val
    hash_value = hash_value * 31 + excl
    for query in _all_components_queries:
        hash_value = hash_value * 31 + _compute_hash_for_query(query)
    for query in _any_components_queries:
        hash_value = hash_value * 31 + _compute_hash_for_query(query)
    for relationship in _relationships:
        var rel_id = relationship.relation.component_id if relationship.relation else 0
        var target_id = 0
        if relationship.target:
            if relationship.target is Entity:
                target_id = relationship.target.get_instance_id()
            else:
                target_id = relationship.target.component_id
        hash_value = hash_value * 31 + rel_id
        hash_value = hash_value * 31 + target_id
    for relationship in _exclude_relationships:
        var rel_id_ex = relationship.relation.component_id if relationship.relation else 0
        var target_id_ex = 0
        if relationship.target:
            if relationship.target is Entity:
                target_id_ex = relationship.target.get_instance_id()
            else:
                target_id_ex = relationship.target.component_id
        hash_value = hash_value * 31 + rel_id_ex
        hash_value = hash_value * 31 + target_id_ex
    hash_value = hash_value * 31 + _world.version
    return hash_value

func _serialize_query(query: Dictionary) -> String:
    var keys = query.keys()
    keys.sort()
    var parts = []
    for key in keys:
        parts.append(str(key) + ":" + str(query[key]))
    return "{" + ",".join(parts) + "}"

func _serialize_relationship(relationship: Relationship) -> String:
    var rel_id = str(relationship.relation.component_id) if relationship.relation else "null"
    var target_id = ""
    if relationship.target:
        if relationship.target is Entity:
            target_id = "entity:" + str(relationship.target.get_instance_id())
        else:
            target_id = "script:" + str(relationship.target.component_id)
    else:
        target_id = "null"
    return "(" + rel_id + "," + target_id + ")"

func execute() -> Array[Entity]:
    var cache_key = _compute_cache_key()
    if _world.query_cache.has(cache_key):
        return _world.query_cache[cache_key].result_array()
    var cq = CachedQuery.new(_all_components, _any_components, _exclude_components,
        _relationships, _exclude_relationships, _all_components_queries, _any_components_queries)
    cq.full_update(_world)
    _world.query_cache[cache_key] = cq
    _world._register_cached_query(cache_key, cq)
    return cq.result_array()

func combine(other: QueryBuilder) -> QueryBuilder:
    for comp in other._all_components:
        _all_components.append(comp)
    for query in other._all_components_queries:
        _all_components_queries.append(query)
    for comp in other._any_components:
        _any_components.append(comp)
    for query in other._any_components_queries:
        _any_components_queries.append(query)
    for comp in other._exclude_components:
        _exclude_components.append(comp)
    for rel in other._relationships:
        _relationships.append(rel)
    for rel in other._exclude_relationships:
        _exclude_relationships.append(rel)
    return self

func as_array() -> Array:
    return [
        _all_components,
        _any_components,
        _exclude_components,
        _relationships,
        _exclude_relationships
    ]

func is_empty() -> bool:
    return _all_components.is_empty() and _any_components.is_empty() and _exclude_components.is_empty() and _relationships.is_empty() and _exclude_relationships.is_empty()

func compile(query: String) -> QueryBuilder:
    return QueryBuilder.new(_world)
