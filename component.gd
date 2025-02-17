class_name Component
extends Resource

static var component_id = 0

func equals(other: Component) -> bool:
    for prop in self.get_property_list():
        var prop_name = prop.name
        if self.get(prop_name) != other.get(prop_name):
            return false
    return true
