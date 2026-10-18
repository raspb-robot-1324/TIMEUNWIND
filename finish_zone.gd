extends Area2D

func _ready() -> void:
	pass
	
func _on_finish_zone_body_entered(body: Node) -> void:
	if body.has_method("stop_timer"):
		body.stop_timer()

func _process(delta: float) -> void:
	pass
