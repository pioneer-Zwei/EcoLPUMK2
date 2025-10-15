import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import '../eco_styles.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nicknameController = TextEditingController();
  final _picker = ImagePicker();

  Uint8List? _pickedImageBytes;
  bool _isRegisterMode = false;
  bool _isLoading = false;
  String? _error;

  void _zmienTryb(bool register) {
    setState(() {
      _isRegisterMode = register;
      _error = null;
    });
  }

  Future<void> _wybierzObraz() async {
    try {
      final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile == null) return;

      final rawBytes = await pickedFile.readAsBytes();
      final compressedBytes = await FlutterImageCompress.compressWithList(
        rawBytes,
        quality: 60,
      );
      
      if (!mounted) return;
      setState(() {
        _pickedImageBytes = compressedBytes;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = "Failed to pick or process image.";
      });
    }
  }

  Future<void> _przetworzAkcje({required bool register}) async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _error = 'Email and password cannot be empty.';
      });
      return;
    }
    
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      UserCredential userCredential;
      if (register) {
        userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );

        final user = userCredential.user;
        if (user == null) throw Exception("User creation failed.");

        final nickname = _nicknameController.text.trim().isNotEmpty
            ? _nicknameController.text.trim()
            : "Eco Warrior";
        final base64Image = _pickedImageBytes != null ? base64Encode(_pickedImageBytes!) : '';

        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'email': email,
          'nickname': nickname,
          'photoBase64': base64Image,
          'createdAt': FieldValue.serverTimestamp(),
        });

        await user.updateDisplayName(nickname);
      } else {
        userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      }
      
      if (mounted) Navigator.of(context).pushReplacementNamed('/home');

    } on FirebaseAuthException catch (e) {
      setState(() => _error = e.message ?? 'An authentication error occurred.');
    } catch (e) {
      setState(() => _error = 'An unexpected error occurred.');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 900;
    final actionLabel = _isRegisterMode ? 'Create Account' : 'Login';

    final formCard = Container(
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 20,
              offset: const Offset(0, 5)),
        ],
      ),
      padding: const EdgeInsets.all(32),
      width: isWide ? 420 : double.infinity,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.eco, color: AppTheme.primaryRed, size: 56),
          const SizedBox(height: 12),
          Text(
            "Welcome to EcoLPU",
            style: AppTheme.headline1.copyWith(fontSize: 26),
          ),
          const SizedBox(height: 8),
          Text(
            _isRegisterMode
                ? "Create your EcoLPU account"
                : "Login to continue your journey",
            style: AppTheme.subtitle,
          ),
          const SizedBox(height: 24),
          Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(30),
            ),
            child: Row(
              children: [
                _przyciskTrybu("Login", !_isRegisterMode, () => _zmienTryb(false)),
                _przyciskTrybu("Register", _isRegisterMode, () => _zmienTryb(true)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _emailController,
            decoration: const InputDecoration(
                labelText: "Email", border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passwordController,
            obscureText: true,
            decoration: const InputDecoration(
                labelText: "Password", border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          if (_isRegisterMode) ...[
            TextField(
              controller: _nicknameController,
              decoration: const InputDecoration(
                  labelText: "Nickname (optional)",
                  border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _wybierzObraz,
                  icon: const Icon(Icons.photo_camera),
                  label: Text(_pickedImageBytes == null
                      ? "Upload Picture"
                      : "Change Picture"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryRed,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30)),
                  ),
                ),
                const SizedBox(width: 12),
                if (_pickedImageBytes != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(_pickedImageBytes!,
                        width: 56, height: 56, fit: BoxFit.cover),
                  ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(_error!,
                  style: const TextStyle(
                      color: Colors.red, fontWeight: FontWeight.w500)),
            ),
          const SizedBox(height: 12),
          if (_isLoading)
            const CircularProgressIndicator()
          else
            ElevatedButton(
              onPressed: () => _przetworzAkcje(register: _isRegisterMode),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryRed,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30)),
                elevation: 5,
              ),
              child: Text(actionLabel, style: AppTheme.button),
            ),
        ],
      ),
    );

    final decorativeSide = isWide
        ? Expanded(
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.primaryRed, Colors.orangeAccent],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(
                  topRight: Radius.circular(32),
                  bottomRight: Radius.circular(32),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.recycling, color: Colors.white, size: 120),
                  const SizedBox(height: 20),
                  Text(
                    "Track. Recycle. Make an Impact.",
                    style:
                        AppTheme.subtitle.copyWith(color: Colors.white, fontSize: 20),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          )
        : const SizedBox.shrink();

    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: isWide
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      formCard,
                      const SizedBox(width: 24),
                      decorativeSide,
                    ],
                  )
                : SingleChildScrollView(child: formCard),
          ),
        ),
      ),
    );
  }

  Widget _przyciskTrybu(String label, bool active, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: active ? AppTheme.primaryRed : Colors.transparent,
            borderRadius: BorderRadius.circular(30),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: active ? Colors.white : Colors.grey.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nicknameController.dispose();
    super.dispose();
  }
}