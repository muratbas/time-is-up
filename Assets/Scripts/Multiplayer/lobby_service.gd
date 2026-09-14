extends Node

## Firebase Realtime Database REST API üzerinden lobi ve IP paylaşımını yöneten servis.
## Autoload olarak çalıştırılır: Project > Project Settings > Autoload

# ── Sabitler ──────────────────────────────────────────────────────────────────
const DATABASE_URL: String = "https://time-is-up-69f8a-default-rtdb.europe-west1.firebasedatabase.app"
const DEBUG_LOBBY_PATH: String = "/debug_lobby.json"

# ── Sinyaller ─────────────────────────────────────────────────────────────────
signal lobby_registered(success: bool)
signal lobby_fetched(ip: String, host_name: String)
signal lobby_fetch_failed(error_message: String)
signal lobby_cleared(success: bool)


# ══════════════════════════════════════════════════════════════════════════════
# Host Tarafı: Lobi Kaydetme / Silme
# ══════════════════════════════════════════════════════════════════════════════

## Host'un yerel IP'sini ve bilgilerini Firebase'e yazar
func register_debug_lobby(host_name: String, ip: String, port: int = 8080) -> void:
	var payload: Dictionary = {
		"host_name": host_name,
		"ip": ip,
		"port": port,
		"timestamp": Time.get_unix_time_from_system()
	}
	var json_body: String = JSON.stringify(payload)
	var url: String = DATABASE_URL + DEBUG_LOBBY_PATH

	var http: HTTPRequest = HTTPRequest.new()
	add_child(http)

	http.request_completed.connect(func(result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
		http.queue_free()
		if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
			print("LobbyService: Lobi basariyla kaydedildi -> %s (%s)" % [host_name, ip])
			lobby_registered.emit(true)
		else:
			print("LobbyService: Lobi kaydedilemedi! Kod: %d, Sonuc: %d" % [response_code, result])
			lobby_registered.emit(false)
	)

	var headers: PackedStringArray = ["Content-Type: application/json"]
	var err: Error = http.request(url, headers, HTTPClient.METHOD_PUT, json_body)
	if err != OK:
		print("LobbyService: HTTP PUT istegi baslatilamadi: %d" % err)
		http.queue_free()
		lobby_registered.emit(false)


## Host lobiden ayrıldığında veya oyun bittiğinde debug lobi kaydını siler
func clear_debug_lobby() -> void:
	var url: String = DATABASE_URL + DEBUG_LOBBY_PATH
	var http: HTTPRequest = HTTPRequest.new()
	add_child(http)

	http.request_completed.connect(func(result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
		http.queue_free()
		if result == HTTPRequest.RESULT_SUCCESS and (response_code == 200 or response_code == 204):
			lobby_cleared.emit(true)
		else:
			lobby_cleared.emit(false)
	)

	var err: Error = http.request(url, PackedStringArray(), HTTPClient.METHOD_DELETE)
	if err != OK:
		http.queue_free()
		lobby_cleared.emit(false)


# ══════════════════════════════════════════════════════════════════════════════
# Client Tarafı: Lobi Bilgisini Çekme
# ══════════════════════════════════════════════════════════════════════════════

## Firebase'den aktif debug host IP'sini sorgular
func fetch_debug_lobby() -> void:
	var url: String = DATABASE_URL + DEBUG_LOBBY_PATH
	var http: HTTPRequest = HTTPRequest.new()
	add_child(http)

	http.request_completed.connect(func(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
		http.queue_free()
		if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
			lobby_fetch_failed.emit("Sunucuya ulasilamadi (HTTP %d)" % response_code)
			return

		var body_str: String = body.get_string_from_utf8()
		var parse_result: Variant = JSON.parse_string(body_str)

		if parse_result == null or not (parse_result is Dictionary):
			lobby_fetch_failed.emit("Aktif bir debug lobisi bulunamadi!")
			return

		var lobby_dict: Dictionary = parse_result as Dictionary
		var ip: String = lobby_dict.get("ip", "")
		var host_name: String = lobby_dict.get("host_name", "Bilinmeyen Host")

		if ip.is_empty():
			lobby_fetch_failed.emit("Lobi IP adresi gecersiz!")
			return

		print("LobbyService: Lobi bulundu -> %s (%s)" % [host_name, ip])
		lobby_fetched.emit(ip, host_name)
	)

	var err: Error = http.request(url, PackedStringArray(), HTTPClient.METHOD_GET)
	if err != OK:
		http.queue_free()
		lobby_fetch_failed.emit("Baglanti istegi olusturulamadi: %d" % err)
