class_name MultiTargetCamera2D
extends Camera2D

# ── Dışa Aktarılan Parametreler ──────────────────────────────────────────────
## Takip edilecek oyuncu grubunun adı
@export var target_group: StringName = &"players"

## Kameranın oyuncuların merkezine yaklaşma hızı (Lerp katsayısı)
@export var move_speed: float = 6.0

## Zoom değişim yumuşatma katsayısı
@export var zoom_speed: float = 5.0

## Ekran kenarlarından oyunculara bırakılacak boşluk mesafesi (Padding)
@export var margin: Vector2 = Vector2(160.0, 120.0)

## Minimum zoom sınırı (Oyuncular çok uzaklaştığında en geniş açı sınırı)
@export var min_zoom: float = 0.4

## Maksimum zoom sınırı (Oyuncular çok yakınken en dar açı sınırı)
@export var max_zoom: float = 1.0

# ── Takip Edilen Oyuncular ────────────────────────────────────────────────────
## Sahnedeki tüm oyuncu referanslarını tutan dizi
var players: Array[Node2D] = []


# ══════════════════════════════════════════════════════════════════════════════
# Başlangıç
# ══════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	# Çok oyunculu kamera grubu ve ana kamera olarak belirleme
	add_to_group("multi_target_camera")
	make_current()
	_update_players_list()


# ══════════════════════════════════════════════════════════════════════════════
# Fizik Döngüsü (Kamera Hareketi ve Zoom)
# ══════════════════════════════════════════════════════════════════════════════

func _physics_process(delta: float) -> void:
	_update_players_list()

	var active_targets: Array[Node2D] = _get_active_players()
	if active_targets.is_empty():
		return

	# Hayattaki oyuncuların pozisyonlarını kapsayan sınır kutusu (Bounding Box)
	var bounding_box: Rect2 = _calculate_bounding_box(active_targets)

	# Pozisyon ve zoom değerlerini pürüzsüzce güncelle
	_update_camera_position(bounding_box.get_center(), delta)
	_update_camera_zoom(bounding_box.size, delta)


# ══════════════════════════════════════════════════════════════════════════════
# Oyuncu Listesi Yönetimi
# ══════════════════════════════════════════════════════════════════════════════

func _update_players_list() -> void:
	players.clear()
	var nodes: Array[Node] = get_tree().get_nodes_in_group(target_group)
	for node: Node in nodes:
		if node is Node2D and is_instance_valid(node):
			players.append(node as Node2D)


func _get_active_players() -> Array[Node2D]:
	# Sadece hayatta olan ve geçerli oyuncuları filtrele
	var active_list: Array[Node2D] = []
	for p: Node2D in players:
		if not is_instance_valid(p):
			continue
		# Elenmiş (is_eliminated) oyuncuları odak kutusuna dahil etme
		if p.get("is_eliminated") == true:
			continue
		active_list.append(p)
	return active_list


# ══════════════════════════════════════════════════════════════════════════════
# Bounding Box (Sınır Kutusu) Hesaplama
# ══════════════════════════════════════════════════════════════════════════════

func _calculate_bounding_box(targets: Array[Node2D]) -> Rect2:
	var first_pos: Vector2 = targets[0].global_position
	var box: Rect2 = Rect2(first_pos, Vector2.ZERO)

	for i: int in range(1, targets.size()):
		box = box.expand(targets[i].global_position)

	return box


# ══════════════════════════════════════════════════════════════════════════════
# Yumuşak Takip ve Zoom Güncellemesi (Lerp)
# ══════════════════════════════════════════════════════════════════════════════

func _update_camera_position(target_center: Vector2, delta: float) -> void:
	# Oyuncuların merkez noktasına doğru yumuşak kayma
	global_position = global_position.lerp(target_center, clampf(move_speed * delta, 0.0, 1.0))


func _update_camera_zoom(box_size: Vector2, delta: float) -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return

	# Kenar boşlukları (Margin) eklenmiş hedef görüş alanı
	var padded_size: Vector2 = box_size + (margin * 2.0)

	# Ekran en-boy oranına göre tüm oyuncuları kapsayacak zoom faktörü
	var zoom_x: float = viewport_size.x / padded_size.x
	var zoom_y: float = viewport_size.y / padded_size.y
	var calculated_zoom: float = minf(zoom_x, zoom_y)

	# Min-Max limitlerini uygula
	calculated_zoom = clampf(calculated_zoom, min_zoom, max_zoom)

	var target_zoom: Vector2 = Vector2(calculated_zoom, calculated_zoom)
	zoom = zoom.lerp(target_zoom, clampf(zoom_speed * delta, 0.0, 1.0))
