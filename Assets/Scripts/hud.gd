extends CanvasLayer

# ── Node Referansları ────────────────────────────────────────────────────────
@onready var waiting_panel: Control  = $WaitingPanel
@onready var waiting_label: Label    = $WaitingPanel/VBox/CountLabel
@onready var hud_panel: Control      = $HUDPanel
@onready var timer_label: Label      = $HUDPanel/TimerLabel
@onready var tag_label: Label        = $HUDPanel/TagLabel
@onready var game_over_panel: Control = $GameOverPanel
@onready var result_label: Label     = $GameOverPanel/VBox/ResultLabel

# ── Bağlantı ─────────────────────────────────────────────────────────────────
var _game_manager: Node = null


func _ready() -> void:
	# GameManager sahneye tam yüklendikten sonra bağlan
	await get_tree().process_frame
	_game_manager = get_tree().get_first_node_in_group("game_manager")
	if _game_manager:
		_game_manager.game_started.connect(_on_game_started)
		_game_manager.game_ended.connect(_on_game_ended)
		_game_manager.player_count_changed.connect(_on_player_count_changed)
		_game_manager.tag_assigned.connect(_on_tag_assigned)

	_show_waiting_screen()


# ── Frame Döngüsü ─────────────────────────────────────────────────────────────

func _process(_delta: float) -> void:
	if _game_manager == null:
		return
	if _game_manager.game_state != _game_manager.GameState.PLAYING:
		return
	# Sayacı her frame güncelle — game_manager.time_remaining server'da azalır
	var t: float = maxf(_game_manager.time_remaining, 0.0)
	timer_label.text = "%02d:%02d" % [int(t) / 60, int(t) % 60]


# ── Ekran Geçişleri ───────────────────────────────────────────────────────────

func _show_waiting_screen() -> void:
	waiting_panel.visible  = true
	hud_panel.visible      = false
	game_over_panel.visible = false


func _show_hud() -> void:
	waiting_panel.visible  = false
	hud_panel.visible      = true
	game_over_panel.visible = false


func _show_game_over() -> void:
	waiting_panel.visible  = false
	hud_panel.visible      = false
	game_over_panel.visible = true


# ── Sinyal Callback'leri ──────────────────────────────────────────────────────

func _on_player_count_changed(current: int, required: int) -> void:
	waiting_label.text = "%d / %d oyuncu" % [current, required]


func _on_game_started() -> void:
	_show_hud()
	tag_label.text = ""


func _on_tag_assigned(player_id: int) -> void:
	# Ebeyi vurgula; kendi ID'n ise özel mesaj göster
	if player_id == multiplayer.get_unique_id():
		tag_label.text = "🎯 SEN EBESIN!"
	else:
		tag_label.text = "Ebe: Oyuncu %d" % player_id


func _on_game_ended(loser_id: int) -> void:
	_show_game_over()
	if loser_id == multiplayer.get_unique_id():
		result_label.text = "😵 Kaybettin!\nEbeyken süre doldu."
	else:
		result_label.text = "🏆 Kazandın!\nOyuncu %d ebe kaldı." % loser_id
