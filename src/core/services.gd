class_name Services
extends RefCounted
## Static handles to the running directors. Any may be null (headless sims wire only what they need).

static var conversation: Node = null   # ConversationDirector
static var traps: Node = null          # TrapDirector
static var scenes: Node = null         # SceneManager
static var world: Node = null          # HotelWorld (3D) — null in logic sims
static var hero: Node = null           # PlayerController
static var read: Node = null           # ReadSystem
static var chase: Node = null          # ChaseDirector
static var hud: Node = null
static var hints: Node = null          # HintDirector


static func clear() -> void:
	conversation = null
	traps = null
	scenes = null
	world = null
	hero = null
	read = null
	chase = null
	hud = null
	hints = null
