extends Control

@onready var phone_input: LineEdit = %PhoneInput
@onready var btn_mtn: Button = %BtnMTN
@onready var btn_airtel: Button = %BtnAirtel
@onready var otp_section: VBoxContainer = %OTPSection
@onready var otp_container: HBoxContainer = %OTPContainer
@onready var timer_label: Label = %TimerLabel
@onready var btn_connect: Button = %BtnConnect
@onready var error_label: Label = %ErrorLabel

var selected_operator: String = ""
var resend_timer: Timer
var time_left: int = 60

func _ready() -> void:
    btn_mtn.pressed.connect(_on_operator_selected.bind("MTN"))
    btn_airtel.pressed.connect(_on_operator_selected.bind("AIRTEL"))
    btn_connect.pressed.connect(_on_connect_pressed)
    resend_timer = Timer.new()
    resend_timer.wait_time = 1.0
    resend_timer.timeout.connect(_on_timer_tick)
    add_child(resend_timer)

func _on_operator_selected(op: String) -> void:
    selected_operator = op
    if op == "MTN":
        btn_mtn.modulate = Color.WHITE
        btn_airtel.modulate = Color(1, 1, 1, 0.5)
    else:
        btn_mtn.modulate = Color(1, 1, 1, 0.5)
        btn_airtel.modulate = Color.WHITE

func _on_connect_pressed() -> void:
    error_label.text = ""
    if phone_input.text.length() < 9:
        error_label.text = "Numero invalide"
        return
    if selected_operator == "":
        error_label.text = "Choisissez MTN ou Airtel"
        return
    otp_section.visible = true
    btn_connect.text = "VERIFIER"
    btn_connect.pressed.disconnect(_on_connect_pressed)
    btn_connect.pressed.connect(_on_verify_pressed)
    _start_timer()

func _on_verify_pressed() -> void:
    var otp_code: String = ""
    for child in otp_container.get_children():
        if child is LineEdit:
            otp_code += child.text
    if otp_code.length() == 6:
        error_label.text = "Code verifie !"
    else:
        error_label.text = "Code incomplet"

func _start_timer() -> void:
    time_left = 60
    resend_timer.start()

func _on_timer_tick() -> void:
    time_left -= 1
    timer_label.text = "Renvoyer le code (0:%02d)" % time_left
    if time_left <= 0:
        resend_timer.stop()
        timer_label.text = "Renvoyer le code"