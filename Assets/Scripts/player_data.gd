extends Node

## Oyuncu verilerini tüm sahnelerde erişilebilir tutan global singleton.
## Autoload olarak eklenmeli: Project > Project Settings > Autoload

const DEFAULT_NICKNAME: String = "Oyuncu"
const MAX_NICKNAME_LENGTH: int = 10

var nickname: String = DEFAULT_NICKNAME
var server_ip: String = ""


func get_local_ip() -> String:
	# Yerel ağ IP'sini döndürür; loopback (127.x) ve link-local (169.x) adresleri atlar
	for address: String in IP.get_local_addresses():
		if address.begins_with("127.") or address.begins_with("169.254") or ":" in address:
			continue
		return address
	return "127.0.0.1"
