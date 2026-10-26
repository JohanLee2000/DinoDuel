class_name PartyCode
extends RefCounted
## Party codes (Jo, 2026-10-26): a short text code for a party of 6 that players share through any
## app. A friend enters it on the Party tab and duels that party, played by the game's AI (a "ghost
## duel"). There's no server: the code itself holds everything (the player's name, the party's
## name, the 6 dinos and which are Shiny), so it all works offline.
##
## A code is PREFIX + base64url of: [version, 6 dino numbers, Shiny bits, name length, name,
## party name length, party name, 2-byte checksum]. Dino numbers are positions in DINO_NUMBERS.

const PREFIX := "DD1-"
const VERSION := 1
## Ghost duels' rival id (RivalDef.id), so nothing confuses them with a Journey stage.
const FRIEND_ID := &"friend"
## Every dino's permanent number in codes. NEW DINOS GO AT THE END: never reorder or remove, or old
## codes would turn into different parties.
const DINO_NUMBERS: Array[StringName] = [
	&"coelophysis", &"stegosaurus", &"velociraptor", &"triceratops", &"t_rex", &"eudimorphodon",
	&"rhamphorhynchus", &"archaeopteryx", &"pteranodon", &"quetzalcoatlus", &"nothosaurus", &"ichthyosaurus",
	&"plesiosaurus", &"liopleurodon", &"mosasaurus", &"postosuchus", &"plateosaurus", &"icarosaurus",
	&"tanystropheus", &"shonisaurus", &"allosaurus", &"brachiosaurus", &"dilophosaurus", &"dimorphodon",
	&"pterodactylus", &"spinosaurus", &"ankylosaurus", &"parasaurolophus", &"archelon", &"microraptor",
	&"cymbospondylus", &"liliensternus", &"herrerasaurus", &"desmatosuchus", &"raeticodactylus", &"sharovipteryx",
	&"placodus", &"torvosaurus", &"cryolophosaurus", &"ceratosaurus", &"dakosaurus", &"yi_qi",
	&"protoceratops", &"hesperornis", &"tapejara", &"eoraptor", &"iguanodon", &"pterodaustro",
	&"mixosaurus", &"kentrosaurus", &"nyctosaurus", &"stygimoloch", &"carnotaurus", &"amargasaurus",
	&"styracosaurus", &"henodus", &"elasmosaurus", &"smilosuchus", &"ornithocheirus", &"diplodocus",
	&"tylosaurus", &"gojirasaurus", &"lessemsaurus", &"hatzegopteryx", &"therizinosaurus", &"giganotosaurus",
	&"fasolasuchus", &"argentinosaurus",
]
## A ghost plays like a mid-Journey rival that learns your habits.
const FRIEND_TEMPERATURE := 0.15


## The code for a party. `shiny_ids`: which of `ids` are Shiny (they look Shiny to the friend too).
static func encode(player_name: String, party_name: String, ids: Array[StringName],
		shiny_ids: Array[StringName] = []) -> String:
	var bytes := PackedByteArray([VERSION])
	var shiny_bits := 0
	for i in ids.size():
		bytes.append(DINO_NUMBERS.find(ids[i]))
		if ids[i] in shiny_ids:
			shiny_bits |= 1 << i
	bytes.append(shiny_bits)
	for text in [player_name.strip_edges().left(PlayerProfile.NAME_MAX_LENGTH),
			party_name.strip_edges().left(PlayerProfile.PARTY_NAME_MAX_LENGTH)]:
		var utf8: PackedByteArray = (text as String).to_utf8_buffer()
		bytes.append(utf8.size())
		bytes.append_array(utf8)
	var check := _checksum(bytes)
	bytes.append(check >> 8)
	bytes.append(check & 0xff)
	return PREFIX + Marshalls.raw_to_base64(bytes).replace("+", "-").replace("/", "_").trim_suffix("=").trim_suffix("=")


## Reads the first code in `text` (a whole pasted message is fine). Returns {} if there's none, or
## it's damaged, or its party can't battle; otherwise {code, player, party, ids, shiny_ids}.
static func decode(text: String, catalog: DinoCatalog) -> Dictionary:
	var finder := RegEx.create_from_string(PREFIX.replace("-", "\\-") + "[A-Za-z0-9_-]+")
	var found := finder.search(text)
	if found == null:
		return {}
	var code := found.get_string()
	var body := code.trim_prefix(PREFIX).replace("-", "+").replace("_", "/")
	while body.length() % 4 != 0:
		body += "="
	var bytes := Marshalls.base64_to_raw(body)
	if bytes.size() < 1 + PartyRules.BRING_SIZE + 1 + 2 + 2 or bytes[0] != VERSION:
		return {}
	var payload := bytes.slice(0, bytes.size() - 2)
	if _checksum(payload) != (bytes[bytes.size() - 2] << 8 | bytes[bytes.size() - 1]):
		return {}
	var ids: Array[StringName] = []
	var shiny_ids: Array[StringName] = []
	var shiny_bits := payload[1 + PartyRules.BRING_SIZE]
	for i in PartyRules.BRING_SIZE:
		var number := payload[1 + i]
		if number >= DINO_NUMBERS.size() or catalog.find(DINO_NUMBERS[number]) == null or DINO_NUMBERS[number] in ids:
			return {}
		ids.append(DINO_NUMBERS[number])
		if shiny_bits & (1 << i):
			shiny_ids.append(DINO_NUMBERS[number])
	var at := 2 + PartyRules.BRING_SIZE
	var names: Array[String] = []
	for i in 2:
		if at >= payload.size():
			return {}
		var length := payload[at]
		if at + 1 + length > payload.size():
			return {}
		names.append(payload.slice(at + 1, at + 1 + length).get_string_from_utf8().strip_edges())
		at += 1 + length
	var defs: Array[DinoDef] = []
	for id in ids:
		defs.append(catalog.find(id))
	if not PartyRules.has_valid_pick(defs):
		return {}
	return {"code": code, "player": names[0] if names[0] != "" else "A friend",
			"party": names[1] if names[1] != "" else "Party", "ids": ids, "shiny_ids": shiny_ids}


## The rival for a ghost duel: the friend's 6, played by the AI.
static func make_rival(info: Dictionary, catalog: DinoCatalog) -> RivalDef:
	var rival := RivalDef.new()
	rival.id = FRIEND_ID
	rival.display_name = info["player"]
	rival.intro = "%s's party, %s." % [info["player"], info["party"]]
	var brings: Array[DinoDef] = []
	for id in info["ids"]:
		brings.append(catalog.find(id))
	rival.brings = brings
	rival.temperature = FRIEND_TEMPERATURE
	rival.learns_habits = true
	return rival


## Fletcher-16: catches a mistyped or cut-off code.
static func _checksum(bytes: PackedByteArray) -> int:
	var a := 0
	var b := 0
	for byte in bytes:
		a = (a + byte) % 255
		b = (b + a) % 255
	return b << 8 | a
