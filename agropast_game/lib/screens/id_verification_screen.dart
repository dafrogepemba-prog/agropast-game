import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';

class IdVerificationScreen extends StatefulWidget {
  final String token;
  const IdVerificationScreen({super.key, required this.token});

  @override
  State<IdVerificationScreen> createState() => _IdVerificationScreenState();
}

class _IdVerificationScreenState extends State<IdVerificationScreen> {
  File? _image;
  bool _uploading = false;
  bool _sent = false;
  String? _error;

  Future<void> _pick(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1600,
    );
    if (picked != null) {
      setState(() { _image = File(picked.path); _error = null; });
    }
  }

  Future<void> _submit() async {
    if (_image == null) return;
    setState(() { _uploading = true; _error = null; });

    final bytes = await _image!.readAsBytes();
    final b64 = base64Encode(bytes);
    final ext = _image!.path.split('.').last.toLowerCase();
    final mime = switch (ext) {
      'png'  => 'image/png',
      'webp' => 'image/webp',
      _      => 'image/jpeg',
    };

    final result = await ApiService.uploadId(
      token: widget.token,
      imageBase64: b64,
      mime: mime,
    );

    if (!mounted) return;
    if (result['success'] == true) {
      setState(() { _uploading = false; _sent = true; });
    } else {
      setState(() {
        _uploading = false;
        _error = result['error'] ?? "Échec de l'envoi.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_sent) return _buildSentScreen();

    return Scaffold(
      backgroundColor: const Color(0xFF1b2a1b),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Vérification d\'identité'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.badge_outlined, color: Color(0xFF4caf50), size: 56),
              const SizedBox(height: 12),
              const Text(
                'Une dernière étape avant ton premier retrait',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              const Text(
                "Pour verser de l'argent réel en toute sécurité, on vérifie l'identité "
                "de chaque joueur avant son premier retrait. Prends une photo claire "
                "de ta carte d'identité ou de ton passeport.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 13.5, height: 1.4),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  '🔒 Ta pièce est vérifiée puis supprimée définitivement — elle n\'est jamais conservée.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white54, fontSize: 11.5),
                ),
              ),
              const SizedBox(height: 24),

              if (_image != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(_image!, height: 220, fit: BoxFit.cover),
                )
              else
                Container(
                  height: 180,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white24, style: BorderStyle.solid),
                  ),
                  child: const Center(
                    child: Icon(Icons.image_outlined, color: Colors.white24, size: 48),
                  ),
                ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _uploading ? null : () => _pick(ImageSource.camera),
                      icon: const Icon(Icons.camera_alt, color: Colors.white70),
                      label: const Text('Prendre une photo', style: TextStyle(color: Colors.white70)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white24),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _uploading ? null : () => _pick(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library, color: Colors.white70),
                      label: const Text('Galerie', style: TextStyle(color: Colors.white70)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white24),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),

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

              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: (_image == null || _uploading) ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2e7d32),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _uploading
                    ? const SizedBox(
                        height: 20, width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Envoyer pour vérification',
                        style: TextStyle(color: Colors.white, fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSentScreen() {
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
              const Text('Pièce envoyée !',
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              const Text(
                'Un administrateur va la vérifier sous 24 à 48h. '
                'Reviens ensuite pour finaliser ton retrait.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2e7d32)),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                  child: Text('Retour', style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
