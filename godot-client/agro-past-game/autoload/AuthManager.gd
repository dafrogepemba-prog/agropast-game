extends Node

signal auth_state_changed(is_authenticated: bool)
signal otp_sent(success: bool, message: String)
signal otp_verified(success: bool, user_id: String)

var id_token: String = ""
var is_authenticated: bool = false

func _ready() -> void:
print("AuthManager initialized")

func send_otp(phone_number: String) -> void:
print("Sending OTP to ", phone_number)
emit_signal("otp_sent", true, "Code envoyé")

func verify_otp(phone_number: String, otp_code: String) -> void:
print("Verifying OTP ", otp_code)
emit_signal("otp_verified", true, "user_123")
emit_signal("auth_state_changed", true)