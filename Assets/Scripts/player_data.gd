extends Node

## Oyuncu verilerini tüm sahnelerde erişilebilir tutan global singleton.
## Autoload olarak eklenmeli: Project > Project Settings > Autoload

const DEFAULT_NICKNAME: String = "Oyuncu"
const MAX_NICKNAME_LENGTH: int = 10

var nickname: String = DEFAULT_NICKNAME
var server_ip: String = ""

# ── Harita Seçimi ─────────────────────────────────────────────────────────────
const MAPS: Array[Dictionary] = [
	{
		"name": "ARENA 1",
		"path": "res://Assets/Scenes/Levels/map.tscn"
	},
	{
		"name": "TEST ARENASI (DUMMY)",
		"path": "res://Assets/Scenes/Levels/test_arena.tscn"
	}
]
var selected_map_index: int = 0


func get_selected_map_path() -> String:
	return MAPS[selected_map_index]["path"]


func get_selected_map_name() -> String:
	return MAPS[selected_map_index]["name"]


func cycle_map() -> String:
	selected_map_index = (selected_map_index + 1) % MAPS.size()
	return get_selected_map_name()


func get_local_ip() -> String:
	# Yerel ağ IP'sini döndürür; loopback (127.x) ve link-local (169.x) adresleri atlar
	for address: String in IP.get_local_addresses():
		if address.begins_with("127.") or address.begins_with("169.254") or ":" in address:
			continue
		return address
	return "127.0.0.1"
