extends SceneLogic
## S07 glue: starts/stops the ChaseDirector (all chase rules live there + data/ep01/chase.json).


func enter() -> void:
	if Services.chase:
		Services.chase.start()


func tick(delta: float) -> void:
	# headless sims drive the director from here (the 3D world drives it in _physics_process)
	if Services.chase and Services.world == null:
		Services.chase.tick(delta)


func exit() -> void:
	if Services.chase and Services.chase.active:
		Services.chase.stop()
	ep().clear_flag("chase_active")
