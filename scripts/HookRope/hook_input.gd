class_name HookInput
extends Node

@onready var hook: Hook = get_parent()

func _input(event):
	if event.is_action_pressed("shoot"):
		if hook.state == Hook.State.IDLE and HeldItemManager.is_held == false:
			hook.thrower.throw()
		elif hook.state == Hook.State.FLYING or hook.state == Hook.State.STUCK:
			hook.recaller.recall()

	# jump while swinging: give the jump impulse first (while we still know
	# is_swinging was true), then recall — otherwise recall() clears the flag
	# before the player's own _physics_process ever sees it was true
	if event.is_action_pressed("jump") and hook.player.is_swinging:
		hook.player.velocity.y = hook.player.JUMP_VELOCITY
		hook.recaller.recall()
