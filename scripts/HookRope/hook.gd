class_name Hook
extends RigidBody2D

enum State { IDLE, FLYING, STUCK, RECALLING }

@export var throw_speed := 800.0
@export var recall_speed := 1000.0
@export var max_range := 500.0
@export var min_range := 5.0
@export var reel_speed := 200.0  # how fast climb_up/climb_down changes rope length
@export_flags_2d_physics var stick_to_layers := 1 + 4  # tick World/Objects etc. in inspector
@export var player: CharacterBody2D  # assign the character node in inspector
@export_range(0.0, 1.0) var attached_friction := 0.1  # friction applied to a stuck RigidBody2D while attached
@export var drag_strength := 900.0     # extra pull toward the player on an attached object, once taut
@export var reel_pull_strength := 600.0  # winch force (mass-normalized) on a stuck RigidBody2D while climb_up/down held

@onready var line: Line2D = $Line2D
@onready var thrower: HookThrower = $HookThrower
@onready var recaller: HookRecaller = $HookRecaller
@onready var attachment: HookAttachment = $HookAttachment
@onready var reel: RopeReel = $RopeReel
@onready var swing_controller: SwingController = $SwingController
@onready var rope_renderer: RopeLineRenderer = $RopeLineRenderer
@onready var input_handler: HookInput = $HookInput

var state := State.IDLE
var stuck_body: RigidBody2D = null
var current_rope_length := 0.0
var attach_offset := Vector2.ZERO  # hook's stick point, relative to stuck_body's origin
var _original_physics_material: PhysicsMaterial = null

func _ready():
	top_level = true
	line.clear_points()
	line.add_point(Vector2.ZERO)  # point 0 - player side
	line.add_point(Vector2.ZERO)  # point 1 - hook side
	hide()
	freeze = true  # hook stays still until thrown

	collision_mask = stick_to_layers
	contact_monitor = true
	max_contacts_reported = 4
	body_entered.connect(attachment._on_body_entered)

func _physics_process(delta):
	match state:
		State.RECALLING:
			recaller.recall_hook()
		State.FLYING:
			thrower.check_range()
		State.STUCK:
			reel.handle_reel(delta)
			swing_controller.constrain_rope(delta)

	rope_renderer.simulate(delta)

# Attaches to a movable object the hook stuck to: records where on the body
# it stuck (offset) and temporarily overrides its friction so it can be
# dragged instead of fighting ground friction the whole way.
func attach_stuck_body(body: RigidBody2D, offset: Vector2) -> void:
	stuck_body = body
	attach_offset = offset
	_original_physics_material = body.physics_material_override
	var mat := PhysicsMaterial.new()
	mat.friction = attached_friction
	body.physics_material_override = mat

# Restores the object's original friction and clears stuck_body. Always use
# this (not "stuck_body = null" directly) so friction is never left changed.
func detach_stuck_body() -> void:
	if stuck_body:
		stuck_body.physics_material_override = _original_physics_material
	stuck_body = null
