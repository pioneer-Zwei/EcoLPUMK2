import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'dart:convert';
import '../config/eco_tracker_service.dart';
import '../config/eco_styles.dart';

class TrackImpactPage extends StatefulWidget {
  const TrackImpactPage({super.key});

  @override
  State<TrackImpactPage> createState() => _TrackImpactPageState();
}

class _TrackImpactPageState extends State<TrackImpactPage> {
  late final StatTrackerService _tracker;
  String? _userId;
  bool _isAnonymous = true;
  bool _usingGlobalFallback = false;
  bool _showGlobal = false;
  final Map<String, Future<DocumentSnapshot<Map<String, dynamic>>>> _userFutures = {};

  @override
  void initState() {
    super.initState();
    _tracker = StatTrackerService();
    final currentUser = FirebaseAuth.instance.currentUser;
    _userId = currentUser?.uid;
    _isAnonymous = currentUser?.isAnonymous ?? true;

    if (_isAnonymous) {
      _showGlobal = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppTheme.cardBg,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        automaticallyImplyLeading: false,
        titleSpacing: 16,
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: AppTheme.primaryRed,
              shape: BoxShape.circle,
            ),
            child: const Icon(LucideIcons.trendingUp, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text("Impact Tracker", style: AppTheme.headline2),
            Text("Spot, Plot, Do a Lot!", style: AppTheme.subtitle),
          ]),
        ]),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          setState(() {
            _showGlobal = !_showGlobal;
            if (!_showGlobal) _usingGlobalFallback = false;
          });
        },
        backgroundColor: AppTheme.primaryRed,
        tooltip: _showGlobal ? 'Show Personal Stats' : 'Show Global Stats',
        shape: const CircleBorder(),
        child: Icon(_showGlobal ? LucideIcons.user : LucideIcons.globe, color: Colors.white),
      ),
      bottomNavigationBar: _dolnyPasek(),
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: _tracker.statsStream(showGlobal: _showGlobal || _usingGlobalFallback, userId: _userId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _ladowanieWidok();
            }

            if (snapshot.hasError) {
              return _bladWidok(snapshot.error.toString());
            }

            final doc = snapshot.data;
            if ((doc == null || !doc.exists) && !_usingGlobalFallback && !_showGlobal) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) setState(() => _usingGlobalFallback = true);
              });
              return _ladowanieWidok();
            }

            if (doc == null || !doc.exists) {
              return _pustyWidok();
            }

            final data = doc.data() ?? {};
            final totalScans = (data['totalScans'] ?? 0) as int;
            final totalWaste = (data['totalWaste'] ?? 0) as int;
            final totalItems = (data['totalItems'] ?? 0) as int;

            final impactData = data['impact'];
            final impact = (impactData is Map)
                ? impactData.map<String, dynamic>((k, v) => MapEntry(k.toString(), v))
                : <String, dynamic>{};

            final byCategoryRaw = data['byCategory'];
            final byCategory = (byCategoryRaw is Map)
                ? byCategoryRaw.map<String, double>(
                    (k, v) => MapEntry(k.toString(), (v as num).toDouble()))
                : <String, double>{};

            final categories = byCategory.keys.toList();
            final values = byCategory.values.toList();

            final Timestamp? ts = data['lastUpdated'];
            final String lastUpdated = ts != null ? _formatujCzas(ts.toDate()) : 'N/A';

            final wasteRatio = totalItems > 0 ? (totalWaste / totalItems).clamp(0.0, 1.0) : 0.0;
            final nonWasteRatio = totalItems > 0 ? (1.0 - wasteRatio).clamp(0.0, 1.0) : 0.0;

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _kartaNaglowka(totalScans, totalWaste, totalItems, lastUpdated),
                  const SizedBox(height: 16),
                  _kartaWplywu(impact),
                  const SizedBox(height: 8),
                  _wykresyKlowe(wasteRatio, nonWasteRatio),
                  const SizedBox(height: 24),
                  _wykresSlupkowy(categories, values),
                  const SizedBox(height: 24),
                  _listaHistorii(),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _listaHistorii() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(LucideIcons.history, color: AppTheme.primaryRed),
            const SizedBox(width: 8),
            Text(
              _showGlobal ? "Global Contribution Feed" : "My Scan History",
              style: AppTheme.headline2.copyWith(fontSize: 18),
            ),
          ],
        ),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _tracker.historyStream(showGlobal: _showGlobal, userId: _userId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: AppTheme.primaryRed));
            }
            if (snapshot.hasError) {
              debugPrint(snapshot.error.toString());
              return Center(child: Text('Error loading history.', style: AppTheme.bodyText));
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              if (!_showGlobal && _isAnonymous) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24.0),
                    child: Text(
                      "Sign in to track your personal scan history.",
                      textAlign: TextAlign.center,
                      style: AppTheme.bodyText.copyWith(fontSize: 14),
                    ),
                  ),
                );
              }
              return Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24.0),
                  child: Text(
                    "No scan history yet.",
                    style: AppTheme.bodyText.copyWith(fontSize: 14),
                  ),
                ),
              );
            }

            final docs = snapshot.data!.docs;
            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final doc = docs[index];
                return _kartaHistorii(doc);
              },
            );
          },
        ),
      ],
    );
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> _pobierzUzytkownika(String userId) {
    if (!_userFutures.containsKey(userId)) {
      _userFutures[userId] = FirebaseFirestore.instance.collection('users').doc(userId).get();
    }
    return _userFutures[userId]!;
  }

  Widget _kartaHistorii(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final timestamp = (data['timestamp'] as Timestamp).toDate();
    final detections = (data['detections'] as List<dynamic>?)?.where((d) => d['isWaste'] == true).toList() ?? [];
    final wasteCount = detections.length;

    final String userName = data['userName'] ?? 'Anonymous User';
    final String? userId = data['userId'];
    final bool isAnonymous = userName == 'Anonymous User';

    if (userId == null || userId.isEmpty) {
      return _zawartoscKarty(userName, isAnonymous, timestamp, wasteCount, detections, null);
    }

    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: _pobierzUzytkownika(userId),
      builder: (context, snapshot) {
        Uint8List? profileImage;
        if (snapshot.hasData && snapshot.data!.exists) {
          final userData = snapshot.data!.data();
          final photoBase64 = userData?['photoBase64'];
          if (photoBase64 != null && photoBase64.isNotEmpty) {
            try {
              profileImage = base64Decode(photoBase64);
            } catch (_) {}
          }
        }
        return _zawartoscKarty(userName, isAnonymous, timestamp, wasteCount, detections, profileImage);
      },
    );
  }

  Widget _zawartoscKarty(
    String userName,
    bool isAnonymous,
    DateTime timestamp,
    int wasteCount,
    List<dynamic> detections,
    Uint8List? profileImage,
  ) {
    return Card(
      color: AppTheme.cardBg,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: profileImage != null ? Colors.transparent : Colors.grey.shade300,
                  backgroundImage: profileImage != null ? MemoryImage(profileImage) : null,
                  child: profileImage == null
                      ? (isAnonymous
                          ? const Icon(LucideIcons.user, color: Colors.white, size: 22)
                          : Text(
                              userName.isNotEmpty ? userName[0].toUpperCase() : '?',
                              style: const TextStyle(color: Colors.white, fontSize: 20),
                            ))
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userName,
                        style: AppTheme.headline2.copyWith(fontSize: 16),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        _formatujCzas(timestamp),
                        style: AppTheme.bodyText.copyWith(fontSize: 12, color: AppTheme.lightText),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text.rich(
              TextSpan(
                style: AppTheme.bodyText,
                children: [
                  const TextSpan(text: 'Contributed '),
                  TextSpan(
                    text: '$wasteCount waste item${wasteCount == 1 ? '' : 's'}',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryRed),
                  ),
                  const TextSpan(text: ' to the dataset.'),
                ],
              ),
            ),
            if (detections.isNotEmpty) ...[
              const Divider(height: 20),
              ...detections.take(2).map((detection) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2.0),
                  child: Row(
                    children: [
                      const Icon(LucideIcons.trash2, size: 14, color: AppTheme.lightText),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${detection['name']} (${detection['category']})',
                          style: AppTheme.bodyText.copyWith(fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                );
              }),
              if (detections.length > 2)
                Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text(
                    "+ ${detections.length - 2} more items...",
                    style: AppTheme.bodyText.copyWith(fontSize: 12, color: AppTheme.lightText),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _kartaWplywu(Map<String, dynamic> impact) {
    final weightKg = (impact['estimatedMassKg'] as num?)?.toDouble() ?? 0.0;
    final co2Avoided = (impact['estimatedCo2AvoidedKg'] as num?)?.toDouble() ?? 0.0;
    final co2Produced = (impact['estimatedCo2ProducedKg'] as num?)?.toDouble() ?? 0.0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: [
        Text(
          _showGlobal || _usingGlobalFallback ? "Global Impact" : "Your Personal Impact",
          style: AppTheme.headline1.copyWith(fontSize: 22),
        ),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          _kartaStatystyki(LucideIcons.recycle, "Waste Diverted", "${weightKg.toStringAsFixed(2)} kg"),
          _kartaStatystyki(LucideIcons.leaf, "CO₂ Avoided", "${co2Avoided.toStringAsFixed(2)} kg"),
          _kartaStatystyki(LucideIcons.factory, "CO₂ Produced", "${co2Produced.toStringAsFixed(2)} kg"),
        ]),
      ]),
    );
  }

  Widget _kartaNaglowka(int totalScans, int totalWaste, int totalItems, String lastUpdated) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            _showGlobal || _usingGlobalFallback ? "Global Statistics" : "Your Statistics",
            style: AppTheme.headline1.copyWith(fontSize: 22),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _kartaStatystyki(LucideIcons.scanLine, "Scans", totalScans.toString()),
              _kartaStatystyki(LucideIcons.trash2, "Waste Items", totalWaste.toString()),
              _kartaStatystyki(LucideIcons.box, "Total Items", totalItems.toString()),
            ],
          ),
          const SizedBox(height: 8),
          Text("Last updated: $lastUpdated", style: AppTheme.bodyText.copyWith(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _wykresyKlowe(double wasteRatio, double nonWasteRatio) {
    return Card(
      color: AppTheme.cardBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(LucideIcons.circleDot, color: AppTheme.primaryRed),
                const SizedBox(width: 8),
                Text("Waste vs Non-Waste Ratio", style: AppTheme.headline2.copyWith(fontSize: 18)),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _koloPostepu(label: "Waste", color: AppTheme.primaryRed, value: wasteRatio),
                _koloPostepu(label: "Not Waste", color: AppTheme.statusSuccess, value: nonWasteRatio),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _koloPostepu({required String label, required Color color, required double value}) {
    return Column(
      children: [
        SizedBox(
          width: 100,
          height: 100,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: value),
            duration: const Duration(seconds: 1),
            builder: (context, val, _) {
              return Stack(
                fit: StackFit.expand,
                children: [
                  CircularProgressIndicator(
                    value: val,
                    strokeWidth: 10,
                    color: color,
                    backgroundColor: Colors.grey.withValues(alpha: 0.2),
                  ),
                  Center(
                    child: Text(
                      "${(val * 100).toStringAsFixed(0)}%",
                      style: AppTheme.headline1.copyWith(fontSize: 18),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: AppTheme.bodyText),
      ],
    );
  }

  Widget _wykresSlupkowy(List<String> categories, List<double> values) {
    return Card(
      color: AppTheme.cardBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(LucideIcons.chartBar, color: AppTheme.primaryRed),
                const SizedBox(width: 8),
                Text(
                  "Waste Breakdown Category",
                  style: AppTheme.headline2.copyWith(fontSize: 18),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (categories.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  "No category data yet.",
                  style: AppTheme.bodyText.copyWith(fontSize: 14),
                ),
              )
            else
              SizedBox(
                height: 250,
                child: BarChart(
                  BarChartData(
                    gridData: const FlGridData(show: false),
                    titlesData: FlTitlesData(
                      show: true,
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 28,
                          interval: _interwalOsiY(values),
                          getTitlesWidget: (value, meta) {
                            return SideTitleWidget(
                              meta: meta,
                              child: Text(
                                value.toInt().toString(),
                                style: AppTheme.bodyText.copyWith(fontSize: 10),
                              ),
                            );
                          },
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 40,
                          getTitlesWidget: (double value, TitleMeta meta) {
                            final idx = value.toInt();
                            final label = (idx >= 0 && idx < categories.length) ? categories[idx] : '';
                            return SideTitleWidget(
                              meta: meta,
                              child: Text(
                                label,
                                style: AppTheme.bodyText.copyWith(fontSize: 10),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    barGroups: List.generate(categories.length, (i) {
                      return BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(
                            toY: values[i],
                            width: 18,
                            borderRadius: const BorderRadius.all(Radius.circular(6)),
                            color: AppTheme.primaryRed,
                          ),
                        ],
                      );
                    }),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  double _interwalOsiY(List<double> values) {
    if (values.isEmpty) return 1;
    final maxVal = values.reduce((a, b) => a > b ? a : b);
    return (maxVal / 5).ceilToDouble().clamp(1, double.infinity);
  }

  Widget _dolnyPasek() {
    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      notchMargin: 8.0,
      color: AppTheme.cardBg,
      elevation: 10,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
        _elementNav(LucideIcons.house, "Home", () => Navigator.pushReplacementNamed(context, '/home')),
        _elementNav(LucideIcons.scanLine, "Classifier", () => Navigator.pushReplacementNamed(context, '/scanner')),
        const SizedBox(width: 48),
        _elementNav(LucideIcons.map, "Map", () => Navigator.pushReplacementNamed(context, '/map')),
        _elementNav(LucideIcons.gamepad2, "Games", () {}),
      ]),
    );
  }

  Widget _elementNav(IconData icon, String tooltip, VoidCallback onPressed) {
    return IconButton(
      icon: Icon(icon, color: AppTheme.lightText, size: 26),
      tooltip: tooltip,
      onPressed: onPressed,
    );
  }

  Widget _ladowanieWidok() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: AppTheme.primaryRed),
            const SizedBox(height: 16),
            Text("Gathering impact data...", style: AppTheme.bodyText),
          ],
        ),
      );

  Widget _bladWidok(String msg) => Center(
        child: Text("Error loading stats:\n$msg", style: AppTheme.bodyText),
      );

  Widget _pustyWidok() => Center(
        child: Text("No stats available yet. Start scanning!", style: AppTheme.bodyText),
      );

  String _formatujCzas(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes} min ago';
    if (diff.inDays < 1) return '${diff.inHours} hr ago';
    return '${diff.inDays} day${diff.inDays > 1 ? 's' : ''} ago';
  }

  Widget _kartaStatystyki(IconData icon, String title, String value) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppTheme.primaryRed.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: AppTheme.primaryRed, size: 20),
        ),
        const SizedBox(height: 8),
        Text(value, style: AppTheme.headline1.copyWith(fontSize: 18)),
        Text(title, style: AppTheme.bodyText.copyWith(fontSize: 12)),
      ],
    );
  }
}