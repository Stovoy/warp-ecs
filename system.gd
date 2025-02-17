class_name System
extends RefCounted

var group: String = ""
var active: bool = true
var q: QueryBuilder

var _using_subsystems: bool = true

func _init() -> void:
    setup()

func query() -> QueryBuilder:
    return q

func sub_systems() -> Array:
    _using_subsystems = false
    return []

func setup() -> void:
    pass

func process_all(entities: Array[Entity], delta: float) -> void:
    pass

func _handle(delta: float) -> void:
    if _handle_subsystems(delta):
        return
    q = ECS.world.query
    var entities = query().execute()
    process_all(entities, delta)

func _handle_subsystems(delta: float) -> bool:
    var subsystems = sub_systems()
    if not _using_subsystems:
        return false
    q = ECS.world.query
    var sub_systems_ran = false
    for sub_sys_tuple in subsystems:
        var did_run = false
        sub_systems_ran = true
        var query_instance = sub_sys_tuple[0]
        var sub_sys_process = sub_sys_tuple[1] as Callable
        var should_process_all = sub_sys_tuple[2] if sub_sys_tuple.size() > 2 else false
        var entities = query_instance.execute()
        if should_process_all:
            did_run = sub_sys_process.call(entities, delta)
        else:
            for entity in entities:
                did_run = true
                sub_sys_process.call(entity, delta)
    return sub_systems_ran
