class_name Entity
extends RefCounted

var enabled: bool = true
var component_resources: Array[Component] = []
var components: Dictionary[int, Component] = {}
var relationships: Array = []
var _state = {}
var component_bitmask: int = 0

func _init() -> void:
    initialize()

func initialize() -> void:
    var defined_components: Array[Component] = define_components()
    for component in defined_components:
        add_component(component)
    on_ready()

func add_component(component: Component) -> void:
    var componentId: int = component.component_id
    components[componentId] = component
    component_bitmask |= (1 << componentId)

func add_components(_components: Array[Component]) -> void:
    for component in _components:
        add_component(component)

func remove_component(component: Component) -> void:
    var componentId: int = component.component_id
    components.erase(componentId)
    component_bitmask &= ~(1 << componentId)

func remove_components(_components: Array[Component]) -> void:
    for _component in _components:
        remove_component(_component)

func get_component(component: Variant) -> Component:
    return components.get(component.component_id, null)

func has_component(component: Variant) -> bool:
    return components.has(component.component_id)

func add_relationship(relationship: Relationship) -> void:
    relationship.source = self
    relationships.append(relationship)

func add_relationships(_relationships: Array) -> void:
    for relationship in _relationships:
        add_relationship(relationship)

func remove_relationship(target_relationship: Relationship) -> void:
    var to_remove: Array = []
    for relationship in relationships:
        if relationship.matches(target_relationship):
            to_remove.append(relationship)
    for relationship in to_remove:
        relationships.erase(relationship)

func remove_relationships(_relationships: Array) -> void:
    for relationship in _relationships:
        remove_relationship(relationship)

func get_relationship(relationship: Relationship, single: bool = true):
    var results: Array = []
    var to_remove: Array = []
    for rel in relationships:
        if not rel.valid():
            to_remove.append(rel)
            continue
        if rel.matches(relationship):
            if single:
                return rel
            results.append(rel)
    for rel in to_remove:
        relationships.erase(rel)
    return null if results.is_empty() else results

func get_relationships(relationship: Relationship) -> Array:
    return get_relationship(relationship, false)

func has_relationship(relationship: Relationship) -> bool:
    return get_relationship(relationship) != null

func on_ready() -> void:
    pass

func on_update(delta: float) -> void:
    pass

func on_destroy() -> void:
    pass

func on_disable() -> void:
    pass

func on_enable() -> void:
    pass

func define_components() -> Array[Component]:
    return []
