extends Node

signal player_loaded(profile: Dictionary)
signal wallet_changed(balance: int, bio_points: int)

var player_profile: Dictionary = {
    "user_id": "",
    "pseudo": "",
    "phone": "",
    "operator": "",
    "city": "",
    "account_status": "active"
}

var wallet: Dictionary = {
    "coin_balance": 0,
    "bio_points": 0
}

func _ready() -> void:
    print("GameState initialized")

func update_wallet(coins_delta: int, bio_delta: int) -> void:
    wallet.coin_balance += coins_delta
    wallet.bio_points += bio_delta
    emit_signal("wallet_changed", wallet.coin_balance, wallet.bio_points)