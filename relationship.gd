class_name Relationship
extends Resource

var relation: Variant = null
var target: Variant = null
var source: Variant = null

func _init(_relation = null, _target = null) -> void:
    assert(not (_relation != null and (_relation is GDScript or _relation is Script)), "Relation must be an instance of Component")
    assert(_relation == null or _relation is Component, "Relation must be null or a Component instance")
    assert(not (_target != null and _target is GDScript and _target is Component), "Target must be an instance of Component")
    assert(_target == null or _target is Entity or _target is Script, "Target must be null, an Entity instance, or a Script archetype")
    relation = _relation
    target = _target

func matches(other: Relationship) -> bool:
    var rel_match = (other.relation == null or relation == null) or relation.equals(other.relation)
    var target_match = false
    if other.target == null or target == null:
        target_match = true
    else:
        if target == other.target:
            target_match = true
        elif target is Entity and other.target is Script:
            target_match = (target.get_script() == other.target)
        elif target is Script and other.target is Entity:
            target_match = (other.target.get_script() == target)
        elif target is Entity and other.target is Entity:
            target_match = (target == other.target)
        elif target is Script and other.target is Script:
            target_match = (target == other.target)
        else:
            target_match = false
    return rel_match and target_match

func valid() -> bool:
    var relation_valid = (target == null) or is_instance_valid(target)
    var source_valid = is_instance_valid(source)
    return relation_valid and source_valid
