extends CharacterBody2D

const MAX_SPEED = 520.0
const ACCELERATION = 2600.0
const FRICTION = 2100.0
const JUMP_VELOCITY = -600.0
const FALL_LIMIT := 1500.0
const SPAWN_CELL := Vector2i(13, 8)
const LOOP_TOTAL := 10

const PERIODS: Array[String] = [
	"Dawn",
	"Sunrise",
	"Morning",
	"Noon",
	"Afternoon",
	"Golden Hour",
	"Sunset",
	"Dusk",
	"Night",
	"Midnight",
]

const SKIES: Array[Texture2D] = [
	preload("res://assets/sky_dawn.png"),
	preload("res://assets/sky_sunrise.png"),
	preload("res://assets/sky_morning.png"),
	preload("res://assets/sky_noon.png"),
	preload("res://assets/sky_afternoon.png"),
	preload("res://assets/sky_golden.png"),
	preload("res://assets/sky_sunset.png"),
	preload("res://assets/sky_dusk.png"),
	preload("res://assets/sky_night.png"),
	preload("res://assets/sky_midnight.png"),
]

@onready var timer_label: Label = %TimerLabel
@onready var victory_label: Label = %VictoryLabel
@onready var period_label: Label = %PeriodLabel
@onready var background: Sprite2D = %Background
@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var camera: Camera2D = $Camera2D

var time_elapsed: float = 0.0
var timer_active: bool = true
var spawn_position: Vector2
var period_index: int = 0
var laps_cleared: int = 0
var has_won: bool = false
var resetting: bool = false

func _ready() -> void:
	_fit_clock()
	_place_on_spawn()
	spawn_position = global_position
	_apply_period(0)

func _place_on_spawn() -> void:
	var map := get_parent().get_node_or_null("TileMapLayer") as TileMapLayer
	if map == null or map.tile_set == null:
		return
	var center := map.to_global(map.map_to_local(SPAWN_CELL))
	var half_tile := float(map.tile_set.tile_size.y) * map.global_scale.y * 0.5
	var half_body := 29.0
	if collision_shape and collision_shape.shape is RectangleShape2D:
		half_body = (collision_shape.shape as RectangleShape2D).size.y * 0.5
	global_position = center + Vector2(0.0, -half_tile - half_body - 4.0)

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	if Input.is_action_just_pressed("jump") and is_on_floor() and not has_won:
		velocity.y = JUMP_VELOCITY

	var direction := Input.get_axis("left", "right")
	if has_won:
		direction = 0.0

	if direction:
		velocity.x = move_toward(velocity.x, direction * MAX_SPEED, ACCELERATION * delta)
	else:
		velocity.x = move_toward(velocity.x, 0, FRICTION * delta)

	move_and_slide()
	_aim_camera(direction, delta)

	if global_position.y > FALL_LIMIT and not has_won:
		velocity = Vector2.ZERO
		global_position = spawn_position

	if timer_active and timer_label:
		time_elapsed += delta
		_update_timer_label()

func _update_timer_label() -> void:
	timer_label.text = _format_time(time_elapsed)

func _format_time(seconds: float) -> String:
	var minutes: int = int(seconds) / 60
	var secs: int = int(seconds) % 60
	return "%02d:%02d" % [minutes, secs]

func _on_finish_zone_body_entered(body: Node) -> void:
	if body != self or has_won or resetting:
		return

	laps_cleared += 1
	if laps_cleared >= LOOP_TOTAL:
		_win()
		return

	_return_to_start(laps_cleared)

func _return_to_start(next_period: int) -> void:
	resetting = true
	velocity = Vector2.ZERO
	global_position = spawn_position
	_apply_period(next_period)
	# Wait until the body has left the finish zone before accepting another lap.
	await get_tree().physics_frame
	await get_tree().physics_frame
	resetting = false

func _win() -> void:
	has_won = true
	timer_active = false
	velocity = Vector2.ZERO
	global_position = spawn_position
	_apply_period(0)
	if period_label:
		period_label.text = "Dawn again"
	if victory_label:
		victory_label.text = "FULL CIRCLE\n%s" % _format_time(time_elapsed)
		victory_label.visible = true

func _apply_period(index: int) -> void:
	period_index = wrapi(index, 0, LOOP_TOTAL)
	if background:
		background.texture = SKIES[period_index]
		_fit_background()
	if period_label and not has_won:
		period_label.text = "%s    %d / %d" % [PERIODS[period_index], period_index + 1, LOOP_TOTAL]

func _fit_clock() -> void:
	if sprite.texture == null:
		return
	var target_size := 64.0
	var tex_size := sprite.texture.get_size()
	var largest := maxf(tex_size.x, tex_size.y)
	var fitted := target_size / largest
	sprite.scale = Vector2(fitted, fitted)
	sprite.position = collision_shape.position

func _aim_camera(direction: float, delta: float) -> void:
	if camera == null:
		return
	var aim_x := -160.0
	if direction:
		aim_x = -direction * 220.0
	camera.position.x = move_toward(camera.position.x, aim_x, 700.0 * delta)
	camera.position.y = 150.0

func _fit_background() -> void:
	if background == null or background.texture == null:
		return
	var view := get_viewport().get_visible_rect().size
	var tex_size := background.texture.get_size()
	background.centered = true
	background.position = view * 0.5
	background.scale = Vector2(view.x / tex_size.x, view.y / tex_size.y)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_SIZE_CHANGED:
		_fit_background()
