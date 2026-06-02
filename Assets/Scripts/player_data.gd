extends Node

## Oyuncu verilerini tüm sahnelerde erişilebilir tutan global singleton.
## Autoload olarak eklenmeli: Project > Project Settings > Autoload

const DEFAULT_NICKNAME: String = "Oyuncu"
const MAX_NICKNAME_LENGTH: int = 10

var nickname: String = DEFAULT_NICKNAME
