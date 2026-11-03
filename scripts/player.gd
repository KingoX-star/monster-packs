extends CharacterBody3D
## Ego-Perspektive: Laufen, Umsehen, Springen, Kamerawackeln.

var camera: Camera3D
var hand: Node3D
var speed := 5.0
var sensitivity := 0.0025
var input_enabled := true
var pitch := 0.0
var shake := 0.0


func _ready() -> void:
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.8
	col.shape = cap
	col.position.y = 0.9
	add_child(col)

	camera = Camera3D.new()
	camera.position.y = 1.6
	camera.fov = 75.0
	add_child(camera)
	camera.current = true

	hand = Node3D.new()
	hand.position = Vector3(0.32, -0.28, -0.62)
	camera.add_child(hand)


func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * sensitivity)
		pitch = clampf(pitch - event.relative.y * sensitivity, -1.45, 1.45)
		camera.rotation.x = pitch


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= 12.0 * delta
	var dir := Vector3.ZERO
	if input_enabled:
		var iv := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		dir = (transform.basis * Vector3(iv.x, 0.0, iv.y)).normalized()
		if Input.is_action_just_pressed("jump") and is_on_floor():
			velocity.y = 4.8
	var s := speed * (1.6 if Input.is_action_pressed("sprint") else 1.0)
	velocity.x = dir.x * s
	velocity.z = dir.z * s
	move_and_slide()

	if shake > 0.0:
		shake = maxf(0.0, shake - delta * 2.5)
		camera.h_offset = randf_range(-1.0, 1.0) * shake * 0.06
		camera.v_offset = randf_range(-1.0, 1.0) * shake * 0.06
	else:
		camera.h_offset = 0.0
		camera.v_offset = 0.0
