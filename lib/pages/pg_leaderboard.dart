import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'dart:convert';
import '../config/eco_styles.dart';

class LeaderboardPage extends StatefulWidget {
  const LeaderboardPage({super.key});

  @override
  State<LeaderboardPage> createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends State<LeaderboardPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppTheme.cardBg,
        automaticallyImplyLeading: false,
        titleSpacing: 16,
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: AppTheme.primaryRed,
              shape: BoxShape.circle,
            ),
            child: const Icon(LucideIcons.trophy, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text("Leaderboard", style: AppTheme.headline2),
            Text("Top Contributors", style: AppTheme.subtitle),
          ]),
        ]),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.pushNamed(context, '/profile'),
        backgroundColor: AppTheme.primaryRed,
        shape: const CircleBorder(),
        tooltip: 'Profile',
        child: const Icon(LucideIcons.user, color: Colors.white),
      ),
      bottomNavigationBar: _dolnyPasek(),
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .orderBy('totalScans', descending: true)
              .limit(100)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: AppTheme.primaryRed));
            }

            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Center(child: Text("No users found."));
            }

            final users = snapshot.data!.docs;

            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(0, 8, 0, 80),
              itemCount: users.length,
              itemBuilder: (context, index) {
                final user = users[index].data();
                final rank = index + 1;
                final photoBase64 = user['photoBase64'];
                Uint8List? profileImage;
                if (photoBase64 != null && photoBase64.isNotEmpty) {
                  try {
                    profileImage = base64Decode(photoBase64);
                  } catch (_) {}
                }

                return _kartaRankingu(
                  rank: rank,
                  user: user,
                  profileImage: profileImage,
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _kartaRankingu({
    required int rank,
    required Map<String, dynamic> user,
    Uint8List? profileImage,
  }) {
    final userName = user['displayName'] ?? 'Eco Pirate';
    final totalScans = user['totalScans'] ?? 0;
    final totalWaste = user['totalWaste'] ?? 0;

    Color? cardColor;
    Widget? rankIcon;

    if (rank == 1) {
      cardColor = Colors.amber.withValues(alpha: 0.15);
      rankIcon = const Icon(LucideIcons.crown, color: Colors.amber, size: 18);
    } else if (rank == 2) {
      cardColor = Colors.grey.withValues(alpha: 0.2);
    } else if (rank == 3) {
      cardColor = const Color(0xFFCD7F32).withValues(alpha: 0.15);
    }

    return Card(
      color: cardColor ?? AppTheme.cardBg,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        child: Row(
          children: [
            SizedBox(
              width: 40,
              child: Column(
                children: [
                  if (rankIcon != null) ...[
                    rankIcon,
                    const SizedBox(height: 2),
                  ],
                  Text(
                    '#$rank',
                    style: AppTheme.headline1.copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.darkText,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 24,
              backgroundColor: profileImage != null ? Colors.transparent : Colors.grey.shade300,
              backgroundImage: profileImage != null ? MemoryImage(profileImage) : null,
              child: profileImage == null
                  ? Text(
                      userName.isNotEmpty ? userName[0].toUpperCase() : '?',
                      style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    userName,
                    style: AppTheme.headline2.copyWith(
                        fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.darkText),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 14.0,
                    runSpacing: 4.0,
                    children: [
                      _statystykaElement(LucideIcons.scanLine, '$totalScans Scans'),
                      _statystykaElement(LucideIcons.trash2, '$totalWaste Waste Items'),
                    ],
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statystykaElement(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppTheme.lightText),
        const SizedBox(width: 4),
        Text(
          text,
          style: AppTheme.bodyText.copyWith(fontSize: 12, color: AppTheme.lightText),
        ),
      ],
    );
  }

  Widget _dolnyPasek() {
    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      notchMargin: 8.0,
      color: AppTheme.cardBg,
      elevation: 10,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
        _przyciskNawigacji(LucideIcons.house, "Home", () => Navigator.pushReplacementNamed(context, '/home')),
        _przyciskNawigacji(LucideIcons.scanLine, "Classifier", () => Navigator.pushReplacementNamed(context, '/scanner')),
        const SizedBox(width: 48),
        _przyciskNawigacji(LucideIcons.map, "Map", () => Navigator.pushReplacementNamed(context, '/map')),
        _przyciskNawigacji(LucideIcons.trendingUp, "Impact", () => Navigator.pushReplacementNamed(context, '/trackimpact')),
      ]),
    );
  }

  Widget _przyciskNawigacji(IconData icon, String tooltip, VoidCallback onPressed) {
    return IconButton(
      icon: Icon(icon, color: AppTheme.lightText, size: 26),
      tooltip: tooltip,
      onPressed: onPressed,
    );
  }
}