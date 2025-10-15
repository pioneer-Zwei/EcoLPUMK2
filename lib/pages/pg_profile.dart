import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../config/eco_styles.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final ImagePicker _wybieracz = ImagePicker();
  final _nickCtrl = TextEditingController();

  User? uzytkownik = FirebaseAuth.instance.currentUser;
  bool _edytuje = false;
  bool _laduje = false;
  String? _zdjecieB64;
  Uint8List? _wybraneZdjecieB;

  @override
  void initState() {
    super.initState();
    _weryfikujILaduj();
  }

  Future<void> _weryfikujILaduj() async {
    uzytkownik = FirebaseAuth.instance.currentUser;
    if (uzytkownik == null) {
      await _obsluzBrakUzytk();
    } else {
      await _ladujProfil();
    }
  }

  Future<void> _obsluzBrakUzytk() async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Session expired. Please log in again.')),
    );
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    }
  }

  Future<void> _ladujProfil() async {
    if (uzytkownik == null) return _obsluzBrakUzytk();
    if (mounted) setState(() => _laduje = true);

    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uzytkownik!.uid).get();
      if (!doc.exists && mounted) {
        await _obsluzBrakUzytk();
        return;
      }
      final data = doc.data() ?? {};
      _nickCtrl.text = data['nickname'] ?? '';
      _zdjecieB64 = data['photoBase64'];
    } catch (e) {
      debugPrint('Error loading profile: $e');
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not load profile.')),
        );
      }
    } finally {
      if (mounted) setState(() => _laduje = false);
    }
  }

  Future<void> _wybierzZdj() async {
    final picked = await _wybieracz.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      final rawBytes = await picked.readAsBytes();
      final compressed = await FlutterImageCompress.compressWithList(rawBytes, quality: 70);
      if (mounted) {
        setState(() => _wybraneZdjecieB = Uint8List.fromList(compressed));
      }
    }
  }

  Future<void> _zapiszProfil() async {
    if (uzytkownik == null) return _obsluzBrakUzytk();
    if (mounted) setState(() => _laduje = true);

    try {
      final nick = _nickCtrl.text.trim();
      final daneZdj = _wybraneZdjecieB != null
          ? base64Encode(_wybraneZdjecieB!)
          : _zdjecieB64 ?? '';

      await FirebaseFirestore.instance.collection('users').doc(uzytkownik!.uid).set({
        'nickname': nick,
        'photoBase64': daneZdj,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;

      setState(() {
        _zdjecieB64 = daneZdj;
        _wybraneZdjecieB = null;
        _edytuje = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully')),
      );
    } catch (e) {
      debugPrint('Error updating profile: $e');
       if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update profile.')),
        );
      }
    } finally {
      if (mounted) setState(() => _laduje = false);
    }
  }

  Future<void> _potwierdzWylog() async {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Log Out'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryRed),
            onPressed: () async {
              Navigator.pop(dialogContext);
              await FirebaseAuth.instance.signOut();
              if (mounted) {
                Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
              }
            },
            child: const Text('Log Out', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _ulepszKonto() async {
    final emailCtrl = TextEditingController();
    final hasloCtrl = TextEditingController();
    final nickCtrl = TextEditingController();

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Upgrade Account'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Convert your guest account into a registered one.'),
            const SizedBox(height: 8),
            TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Email')),
            TextField(controller: hasloCtrl, decoration: const InputDecoration(labelText: 'Password'), obscureText: true),
            TextField(controller: nickCtrl, decoration: const InputDecoration(labelText: 'Nickname')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (uzytkownik == null) return;
              try {
                final cred = EmailAuthProvider.credential(
                  email: emailCtrl.text.trim(),
                  password: hasloCtrl.text.trim(),
                );
                await uzytkownik!.linkWithCredential(cred);
                await FirebaseFirestore.instance.collection('users').doc(uzytkownik!.uid).set({
                  'email': emailCtrl.text.trim(),
                  'nickname': nickCtrl.text.trim(),
                  'isAnonymous': false,
                  'updatedAt': FieldValue.serverTimestamp(),
                }, SetOptions(merge: true));

                if (!mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Account upgraded successfully')),
                );
                _weryfikujILaduj();
              } on FirebaseAuthException catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(e.message ?? 'Error upgrading account')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryRed),
            child: const Text('Upgrade', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
  
  Uint8List? get _obrazWyswietlany {
    if (_wybraneZdjecieB != null) {
      return _wybraneZdjecieB;
    }
    if (_zdjecieB64?.isNotEmpty ?? false) {
      try {
        return base64Decode(_zdjecieB64!);
      } catch (e) {
        debugPrint('Error decoding base64 image: $e');
        return null;
      }
    }
    return null;
  }

  Widget _kartaStat(IconData icon, String label, String value) {
    return Container(
      width: 100,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 6, offset: const Offset(0, 3))
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: AppTheme.primaryRed, size: 28),
          const SizedBox(height: 8),
          Text(value, style: AppTheme.headline1.copyWith(fontSize: 18)),
          Text(label, style: AppTheme.bodyText.copyWith(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _sekcjaNagrod() {
    return Container(
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 6, offset: const Offset(0, 3))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Awards & Badges', style: AppTheme.headline1.copyWith(fontSize: 20)),
          const SizedBox(height: 12),
          const Text('Your achievements will appear here.', style: TextStyle(color: Colors.black54)),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 20,
            runSpacing: 20,
            children: List.generate(5, (i) {
              return Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  shape: BoxShape.circle,
                ),
                child: const Icon(LucideIcons.award, color: Colors.grey, size: 28),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _dolnyPasekNaw() {
    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      notchMargin: 8,
      color: AppTheme.cardBg,
      elevation: 10,
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
        _przyciskNaw(LucideIcons.house, 'Home', '/home'),
        _przyciskNaw(LucideIcons.scanLine, 'Classifier', '/scanner'),
        const SizedBox(width: 48),
        _przyciskNaw(LucideIcons.trendingUp, 'Tracker', '/trackImpact'),
        _przyciskNaw(LucideIcons.gamepad2, 'Games', '/games'),
      ]),
    );
  }

  Widget _przyciskNaw(IconData icon, String tooltip, String route) {
    return IconButton(
      icon: Icon(icon, color: AppTheme.lightText, size: 26),
      tooltip: tooltip,
      onPressed: () => Navigator.pushReplacementNamed(context, route),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (uzytkownik == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final anonimowy = uzytkownik?.isAnonymous ?? true;

    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      appBar: AppBar(
        backgroundColor: AppTheme.cardBg,
        elevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: 16,
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(color: AppTheme.primaryRed, shape: BoxShape.circle),
            child: const Icon(LucideIcons.leaf, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('My Profile', style: AppTheme.headline2),
            Text('Track. Recycle. Make an Impact.', style: AppTheme.subtitle),
          ]),
        ]),
      ),
      bottomNavigationBar: _dolnyPasekNaw(),
      floatingActionButton: FloatingActionButton(
        onPressed: _potwierdzWylog,
        backgroundColor: AppTheme.primaryRed,
        shape: const CircleBorder(),
        tooltip: 'Log Out',
        child: const Icon(LucideIcons.logOut, color: Colors.white),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      body: _laduje
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryRed))
          : StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(uzytkownik!.uid)
                  .collection('meta')
                  .doc('stats')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text('Error loading stats.'));
                }

                int skany = 0;
                double kgRecyklingu = 0;
                double wynikWplywu = 0;

                if (snapshot.hasData && snapshot.data!.exists) {
                  final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
                  final impact = data['impact'] ?? {};
                  skany = (data['totalScans'] ?? 0) as int;
                  kgRecyklingu = (impact['estimatedMassKg'] ?? 0).toDouble();
                  wynikWplywu = (impact['estimatedCo2AvoidedKg'] ?? 0).toDouble();
                }

                final txtRecykling = '${kgRecyklingu.toStringAsFixed(1)}kg';
                final txtWplyw = wynikWplywu.toStringAsFixed(1);

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 500),
                      child: Column(
                        children: [
                          const SizedBox(height: 20),
                          Stack(children: [
                            CircleAvatar(
                              radius: 60,
                              backgroundImage: _obrazWyswietlany != null ? MemoryImage(_obrazWyswietlany!) : null,
                              backgroundColor: Colors.grey.shade300,
                              child: _obrazWyswietlany == null
                                  ? const Icon(LucideIcons.user, size: 60, color: Colors.white)
                                  : null,
                            ),
                            if (_edytuje)
                              Positioned(
                                bottom: 0,
                                right: 4,
                                child: InkWell(
                                  onTap: _wybierzZdj,
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: const BoxDecoration(
                                        color: AppTheme.primaryRed, shape: BoxShape.circle),
                                    child: const Icon(Icons.camera_alt,
                                        color: Colors.white, size: 20),
                                  ),
                                ),
                              ),
                          ]),
                          const SizedBox(height: 12),
                          _edytuje
                              ? Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 40),
                                  child: TextField(
                                    controller: _nickCtrl,
                                    textAlign: TextAlign.center,
                                    style: AppTheme.headline1.copyWith(fontSize: 22),
                                    decoration: const InputDecoration(
                                      hintText: 'Enter your nickname',
                                      border: InputBorder.none,
                                    ),
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      _nickCtrl.text.isNotEmpty
                                          ? _nickCtrl.text
                                          : (anonimowy ? 'Guest User' : 'Eco Warrior'),
                                      style: AppTheme.headline1.copyWith(fontSize: 22),
                                    ),
                                    if (!anonimowy)
                                      IconButton(
                                        icon: const Icon(Icons.edit, color: AppTheme.primaryRed),
                                        onPressed: () => setState(() => _edytuje = true),
                                      ),
                                  ],
                                ),
                          const SizedBox(height: 4),
                          if (!anonimowy)
                            Text(uzytkownik!.email ?? '',
                                style: AppTheme.subtitle.copyWith(fontSize: 13)),
                          const SizedBox(height: 20),
                          if (!anonimowy && _edytuje)
                            ElevatedButton.icon(
                              onPressed: _zapiszProfil,
                              icon: const Icon(Icons.save, color: Colors.white),
                              label: const Text('Save Changes',
                                  style: TextStyle(color: Colors.white)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryRed,
                                minimumSize: const Size(double.infinity, 50),
                              ),
                            )
                          else if (anonimowy)
                            ElevatedButton.icon(
                              onPressed: _ulepszKonto,
                              icon: const Icon(LucideIcons.circleArrowUp, color: Colors.white),
                              label: const Text('Upgrade Account',
                                  style: TextStyle(color: Colors.white)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryRed,
                                minimumSize: const Size(double.infinity, 50),
                              ),
                            ),
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _kartaStat(LucideIcons.scanLine, 'Scans', skany.toString()),
                              _kartaStat(LucideIcons.recycle, 'Recycled', txtRecykling),
                              _kartaStat(LucideIcons.award, 'Impact', txtWplyw),
                            ],
                          ),
                          _sekcjaNagrod(),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}