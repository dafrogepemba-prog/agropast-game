import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/game_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoginTab = true;
  bool _loading = false;
  String? _error;
  String _indicatif = '+242';

  static const _indicatifs = [
    {'code': '+242', 'flag': '🇨🇬', 'nom': 'Congo-Brazzaville'},
    {'code': '+243', 'flag': '🇨🇩', 'nom': 'RD Congo'},
    {'code': '+221', 'flag': '🇸🇳', 'nom': 'Sénégal'},
    {'code': '+225', 'flag': '🇨🇮', 'nom': "Côte d'Ivoire"},
    {'code': '+237', 'flag': '🇨🇲', 'nom': 'Cameroun'},
    {'code': '+241', 'flag': '🇬🇦', 'nom': 'Gabon'},
    {'code': '+229', 'flag': '🇧🇯', 'nom': 'Bénin'},
    {'code': '+226', 'flag': '🇧🇫', 'nom': 'Burkina Faso'},
  ];

  // Connexion
  final _identifierCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();

  // Inscription
  final _whatsappCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _nomCtrl = TextEditingController();

  // Résultat d'inscription (PIN généré par le serveur, à afficher une fois)
  Map<String, dynamic>? _registerResult;

  @override
  void dispose() {
    _identifierCtrl.dispose();
    _pinCtrl.dispose();
    _whatsappCtrl.dispose();
    _emailCtrl.dispose();
    _nomCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitLogin() async {
    if (_identifierCtrl.text.trim().length < 4 || _pinCtrl.text.trim().length < 4) {
      setState(() => _error = 'Remplis ton identifiant et ton PIN.');
      return;
    }
    setState(() { _loading = true; _error = null; });

    final result = await ApiService.login(
      identifier: _identifierCtrl.text.trim(),
      pin: _pinCtrl.text.trim(),
    );

    if (!mounted) return;
    if (result['success'] == true) {
      await context.read<GameProvider>().setSession(
        token: result['token'] ?? '',
        nom: result['nom'] ?? 'Fermier',
        whatsapp: result['whatsapp'] ?? '',
      );
      if (mounted) Navigator.of(context).pop(true);
    } else {
      setState(() {
        _loading = false;
        _error = result['error'] ?? 'Connexion impossible.';
      });
    }
  }

  Future<void> _submitRegister() async {
    if (_whatsappCtrl.text.trim().length < 8) {
      setState(() => _error = 'Numéro WhatsApp invalide.');
      return;
    }
    if (_emailCtrl.text.trim().isEmpty || !_emailCtrl.text.contains('@')) {
      setState(() => _error = 'Email valide requis.');
      return;
    }
    setState(() { _loading = true; _error = null; });

    final result = await ApiService.register(
      whatsapp: '$_indicatif ${_whatsappCtrl.text.trim()}',
      email: _emailCtrl.text.trim(),
      nom: _nomCtrl.text.trim().isEmpty ? 'Fermier' : _nomCtrl.text.trim(),
    );

    if (!mounted) return;
    if (result['success'] == true) {
      setState(() {
        _loading = false;
        _registerResult = result; // affiche le PIN généré avant de continuer
      });
      await context.read<GameProvider>().setSession(
        token: result['token'] ?? '',
        nom: result['nom'] ?? 'Fermier',
        whatsapp: result['whatsapp'] ?? '',
      );
    } else {
      setState(() {
        _loading = false;
        _error = result['error'] ?? 'Inscription impossible.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_registerResult != null) {
      return _buildRegisterSuccess();
    }

    return Scaffold(
      backgroundColor: const Color(0xFF1b2a1b),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('AgroPast-Game'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              const Text('🍉', style: TextStyle(fontSize: 48), textAlign: TextAlign.center),
              const SizedBox(height: 12),
              Text(
                _isLoginTab ? 'Connexion' : 'Inscription',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 24),

              // Onglets
              Row(
                children: [
                  Expanded(child: _tabButton('Connexion', true)),
                  const SizedBox(width: 8),
                  Expanded(child: _tabButton('Inscription', false)),
                ],
              ),
              const SizedBox(height: 24),

              if (_isLoginTab) ..._buildLoginFields() else ..._buildRegisterFields(),

              if (_error != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(_error!, style: const TextStyle(color: Colors.redAccent)),
                ),
              ],

              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loading ? null : (_isLoginTab ? _submitLogin : _submitRegister),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2e7d32),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _loading
                    ? const SizedBox(
                        height: 20, width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(_isLoginTab ? 'Se connecter' : "S'inscrire",
                        style: const TextStyle(color: Colors.white, fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tabButton(String label, bool isLoginTab) {
    final selected = _isLoginTab == isLoginTab;
    return OutlinedButton(
      onPressed: () => setState(() { _isLoginTab = isLoginTab; _error = null; }),
      style: OutlinedButton.styleFrom(
        backgroundColor: selected ? const Color(0xFF2e7d32) : Colors.transparent,
        side: const BorderSide(color: Color(0xFF2e7d32)),
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
      child: Text(label, style: TextStyle(color: selected ? Colors.white : const Color(0xFF4caf50))),
    );
  }

  List<Widget> _buildLoginFields() {
    return [
      _field(_identifierCtrl, 'Numéro WhatsApp ou email'),
      const SizedBox(height: 12),
      _field(_pinCtrl, 'PIN (6 chiffres)', obscure: true, numeric: true),
    ];
  }

  List<Widget> _buildRegisterFields() {
    return [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(8),
            ),
            height: 56,
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _indicatif,
                dropdownColor: const Color(0xFF1b2a1b),
                style: const TextStyle(color: Colors.white),
                items: _indicatifs.map((c) {
                  return DropdownMenuItem(
                    value: c['code'],
                    child: Text('${c['flag']} ${c['code']}'),
                  );
                }).toList(),
                onChanged: (v) => setState(() => _indicatif = v ?? _indicatif),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: _field(_whatsappCtrl, 'Numéro WhatsApp')),
        ],
      ),
      const SizedBox(height: 12),
      _field(_emailCtrl, 'Email'),
      const SizedBox(height: 12),
      _field(_nomCtrl, 'Pseudo (optionnel)'),
      const SizedBox(height: 8),
      const Text(
        'Ton PIN de connexion sera généré automatiquement et envoyé par email.',
        style: TextStyle(color: Colors.white54, fontSize: 12),
      ),
    ];
  }

  Widget _field(TextEditingController ctrl, String label, {bool obscure = false, bool numeric = false}) {
    return TextField(
      controller: ctrl,
      obscureText: obscure,
      keyboardType: numeric ? TextInputType.number : TextInputType.text,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54),
        filled: true,
        fillColor: Colors.white.withOpacity(0.06),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
      ),
    );
  }

  Widget _buildRegisterSuccess() {
    final pin = _registerResult?['pin'] ?? '';
    return Scaffold(
      backgroundColor: const Color(0xFF1b2a1b),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle, color: Color(0xFF4caf50), size: 64),
              const SizedBox(height: 16),
              const Text('Inscription réussie !',
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              const Text('Ton PIN de connexion (garde-le précieusement) :',
                  style: TextStyle(color: Colors.white70), textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                decoration: BoxDecoration(
                  color: const Color(0xFF2e7d32),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(pin,
                    style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 4)),
              ),
              const SizedBox(height: 8),
              const Text('Il t\'a aussi été envoyé par email.',
                  style: TextStyle(color: Colors.white38, fontSize: 12)),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2e7d32)),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                  child: Text("C'est noté, continuer", style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
