class_name _ECS
extends Node

var _world: World = null
var world: World:
    get:
        return _world
    set(value):
        _world = value

var entity_preprocessors: Array[Callable] = []
var entity_postprocessors: Array[Callable] = []

func process(delta: float, group: String = "") -> void:
    if world:
        world.process(delta, group)

var wildcard = null

func get_components(entities: Array[Entity], component_type: Variant, default_component: Variant = null) -> Array:
    var components: Array = []
    for entity in entities:
        var component: Component = entity.components.get(component_type.component_id, null)
        if not component and not default_component:
            assert(component, "Entity does not have component: " + str(component_type))
        if not component and default_component:
            component = default_component
        components.append(component)
    return components
