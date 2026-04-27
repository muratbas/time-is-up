extends Node2D # veya senin main node'un neyse (Node3D, Node vb.)

func _ready():
    # Sahne yüklendiğinde multiplayer kurulumunu başlat
    NetworkHandler.setup_multiplayer()