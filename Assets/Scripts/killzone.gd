class_name KillZone
extends Area2D

# ── Sinyaller ─────────────────────────────────────────────────────────────────
## Bir oyuncu uçuruma düştüğünde bildirilir
signal player_fell(player: Node2D)

# ══════════════════════════════════════════════════════════════════════════════
# Başlangıç
# ══════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	# Sadece oyuncu grubundaki nesneler için işlem yap
	if not body.is_in_group("players"):
		return

	player_fell.emit(body)

	# Uçuruma düşen oyuncuyu en uygun spawn noktasına geri taşı
	_respawn_player(body)


func _respawn_player(player: Node2D) -> void:
	var spawn_points: Array[Node] = get_tree().get_nodes_in_group("spawn_points")
	if spawn_points.is_empty():
		player.global_position = Vector2(0.0, -150.0)
	else:
		# Rastgele veya ilk uygun noktaya taşı
		var random_point: Marker2D = spawn_points.pick_random() as Marker2D
		player.global_position = random_point.global_position

	# Düşüş hızını ve ivmesini sıfırla
	if "velocity" in player:
		player.set("velocity", Vector2.ZERO)

	# Sersemletme veya efekt tetikleme
	if player.has_method("receive_knockback"):
		player.call("receive_knockback", Vector2(0.0, -100.0))
