class_name Hook
extends RigidBody2D

enum State { IDLE, FLYING, STUCK, RECALLING }

@export var throw_speed := 800.0
@export var recall_speed := 1000.0
@export var max_range := 500.0
@export var min_range := 5.0
@export var reel_speed := 200.0  # how fast climb_up/climb_down changes rope length
@export var drag_force := 20000.0
@export_flags_2d_physics var stick_to_layers := 1 + 4  # tick World/Objects etc. in inspector
@export var player: CharacterBody2D  # assign the character node in inspector

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
