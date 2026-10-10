class_name DinoSets
extends RefCounted
## Set badges (Jo, 2026-10-09): six families that split every dino between them, plus themed sets
## that cross types and can overlap. Owning every dino in a set unlocks its Amber reward
## (AMBER_PER_DINO for each dino in it) and a badge, shown in Goals and in the full card view.
## Claims are kept in PlayerProfile.claimed_goals as "set_<id>".

const AMBER_PER_DINO := 30

## id -> [name, blurb, dino ids]. Every dino is in exactly one family (see the tests); new dinos must
## be added to one.
const FAMILIES := {
	&"hunters": ["Hunters", "Meat-eating theropods, from Coelophysis to T. rex.", [
		&"coelophysis", &"herrerasaurus", &"liliensternus", &"dilophosaurus", &"cryolophosaurus",
		&"ceratosaurus", &"allosaurus", &"torvosaurus", &"velociraptor", &"spinosaurus", &"t_rex",
		&"eoraptor", &"gojirasaurus", &"carnotaurus", &"giganotosaurus"]],
	&"plant_eaters": ["Plant-Eaters", "Long necks, horns, plates, clubs and duck bills.", [
		&"plateosaurus", &"brachiosaurus", &"stegosaurus", &"ankylosaurus", &"triceratops",
		&"protoceratops", &"parasaurolophus", &"therizinosaurus", &"amargasaurus", &"diplodocus",
		&"kentrosaurus", &"styracosaurus", &"iguanodon", &"stygimoloch", &"lessemsaurus", &"argentinosaurus"]],
	&"croc_cousins": ["Croc Cousins", "Relatives of crocodiles, on land and at sea.", [
		&"postosuchus", &"desmatosuchus", &"dakosaurus", &"fasolasuchus", &"smilosuchus"]],
	&"pterosaurs": ["Pterosaurs", "Flying reptiles, the first animals with backbones to truly fly.", [
		&"eudimorphodon", &"raeticodactylus", &"dimorphodon", &"rhamphorhynchus", &"pterodactylus",
		&"pteranodon", &"tapejara", &"quetzalcoatlus", &"nyctosaurus", &"pterodaustro", &"ornithocheirus",
		&"hatzegopteryx"]],
	&"feathers_gliders": ["Feathers & Gliders", "Early birds, feathered dinosaurs and gliding reptiles.", [
		&"icarosaurus", &"sharovipteryx", &"archaeopteryx", &"yi_qi", &"microraptor", &"hesperornis"]],
	&"sea_reptiles": ["Sea Reptiles", "They ruled the oceans while dinosaurs ruled the land.", [
		&"nothosaurus", &"placodus", &"tanystropheus", &"cymbospondylus", &"shonisaurus",
		&"ichthyosaurus", &"plesiosaurus", &"liopleurodon", &"archelon", &"mosasaurus", &"henodus",
		&"mixosaurus", &"elasmosaurus", &"tylosaurus"]],
}

const THEMES := {
	&"famous_five": ["Famous Five", "The dinosaurs everyone knows.", [
		&"t_rex", &"triceratops", &"stegosaurus", &"brachiosaurus", &"velociraptor"]],
	&"crested_heads": ["Crested Heads", "Showy head crests, probably for display.", [
		&"dilophosaurus", &"cryolophosaurus", &"raeticodactylus", &"tapejara", &"parasaurolophus", &"nyctosaurus"]],
	&"ichthyosaurs": ["Ichthyosaurs", "Dolphin-shaped reptiles that gave birth at sea.", [
		&"cymbospondylus", &"shonisaurus", &"ichthyosaurus", &"mixosaurus"]],
	&"giants": ["Giants", "The biggest of their kind.", [
		&"brachiosaurus", &"spinosaurus", &"quetzalcoatlus", &"shonisaurus", &"cymbospondylus",
		&"mosasaurus", &"argentinosaurus", &"giganotosaurus", &"hatzegopteryx"]],
	&"horns_armor": ["Horns & Armor", "Built for defense.", [
		&"triceratops", &"protoceratops", &"ankylosaurus", &"stegosaurus", &"desmatosuchus", &"styracosaurus",
		&"kentrosaurus"]],
	&"gliders": ["Gliders", "Took to the air without flapping.", [
		&"icarosaurus", &"sharovipteryx", &"yi_qi", &"microraptor"]],
	&"bird_origins": ["Bird Origins", "Feathered dinosaurs on the road to birds.", [
		&"archaeopteryx", &"microraptor", &"yi_qi", &"velociraptor", &"hesperornis"]],
	&"sea_monsters": ["Sea Monsters", "Top predators of ancient seas.", [
		&"mosasaurus", &"liopleurodon", &"dakosaurus", &"cymbospondylus", &"tylosaurus"]],
}


## Families first, then themes, in listing order.
static func ids() -> Array[StringName]:
	var all: Array[StringName] = []
	all.assign(FAMILIES.keys() + THEMES.keys())
	return all


static func info(id: StringName) -> Array:
	return FAMILIES[id] if FAMILIES.has(id) else THEMES[id]


static func title_of(id: StringName) -> String:
	return info(id)[0]


static func blurb(id: StringName) -> String:
	return info(id)[1]


static func members(id: StringName) -> Array:
	return info(id)[2]


static func reward(id: StringName) -> int:
	return members(id).size() * AMBER_PER_DINO


## [owned, total].
static func progress(profile: PlayerProfile, id: StringName) -> Array:
	var dinos := members(id)
	return [dinos.filter(func(d: StringName) -> bool: return profile.owns(d)).size(), dinos.size()]


static func complete(profile: PlayerProfile, id: StringName) -> bool:
	var counts := progress(profile, id)
	return counts[0] >= counts[1]


static func claimed(profile: PlayerProfile, id: StringName) -> bool:
	return profile.claimed_goals.get("set_%s" % id, false)


static func ready(profile: PlayerProfile, id: StringName) -> bool:
	return complete(profile, id) and not claimed(profile, id)


static func claim(profile: PlayerProfile, id: StringName) -> bool:
	if not ready(profile, id):
		return false
	profile.claimed_goals["set_%s" % id] = true
	profile.amber += reward(id)
	return true


static func any_ready(profile: PlayerProfile) -> bool:
	return ids().any(func(id: StringName) -> bool: return ready(profile, id))


## The sets a dino belongs to: its family first, then any themes.
static func sets_of(dino_id: StringName) -> Array[StringName]:
	var found: Array[StringName] = []
	for id in ids():
		if dino_id in members(id):
			found.append(id)
	return found
