extends Node

signal sync_started()
signal sync_completed(success_count: int, fail_count: int)
signal connection_status_changed(is_online: bool)

var is_online: bool = false

func _ready() -> void:
    print("NetworkManager initialized")

func observe_connection() -> void:
    is_online = true
    emit_signal("connection_status_changed", true)