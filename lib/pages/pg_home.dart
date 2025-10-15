import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../config/eco_styles.dart';
import '../config/eco_analyzer_service.dart';
import '../config/eco_waste_detection.dart';
import '../config/eco_tracker_service.dart';

  class HomePage extends StatefulWidget {
    const HomePage({super.key});
    @override
    State<HomePage> createState() => _HomePageState();
  }

  class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
    final ImagePicker _wybierak = ImagePicker();
    final AnalyzerService _analizator = AnalyzerService();
    Uint8List? _bityObrazu;
    String _statusAnalizy = "";
    List<String> _podswietloneTypy = [];
    bool _modelGotowy = false;
    List<WasteDetection> _detekcje = [];
    bool _pokazMonit = false;
    final StatTrackerService _sledzik = StatTrackerService();

    bool _skanZapisany = false;
    bool _przekazywanie = false;

    late AnimationController _kontrolerPulsu;
    late Animation<double> _animacjaPulsu;

    final Map<String, String> _symboleOdpadu = {
      "PLASTIC": "Pl",
      "GLASS": "Gl",
      "ORGANIC": "Or",
      "PAPER": "Pa",
      "ELECTRONIC": "El",
      "METAL": "Me",
    };

    final Map<String, Color> _koloryOdpadu = {
      "Pl": AppTheme.plasticColor,
      "Gl": AppTheme.glassColor,
      "Or": AppTheme.organicColor,
      "Pa": AppTheme.paperColor,
      "El": AppTheme.electronicColor,
      "Me": AppTheme.metalColor,
    };

    final List<Map<String, dynamic>> _daneWykresu = [
      {"color": AppTheme.plasticColor, "symbol": "Pl", "icon": LucideIcons.box},
      {"color": AppTheme.glassColor, "symbol": "Gl", "icon": LucideIcons.glassWater},
      {"color": AppTheme.organicColor, "symbol": "Or", "icon": LucideIcons.leaf},
      {"color": AppTheme.paperColor, "symbol": "Pa", "icon": LucideIcons.fileText},
      {"color": AppTheme.electronicColor, "symbol": "El", "icon": LucideIcons.cpu},
      {"color": AppTheme.metalColor, "symbol": "Me", "icon": LucideIcons.wrench},
    ];

    @override
    void initState() {
      super.initState();
      _inicjalizujModel();
      _kontrolerPulsu = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1500),
      )..repeat(reverse: true);
      _animacjaPulsu = CurvedAnimation(parent: _kontrolerPulsu, curve: Curves.easeInOut);
    }

    @override
    void dispose() {
      _zapiszSkan();
      _kontrolerPulsu.dispose();
      super.dispose();
    }

    Future<void> _inicjalizujModel() async {
      if (!mounted) return;
      setState(() => _statusAnalizy = "Loading model...");
      try {
        await _analizator.initializeModel();

        if (!mounted) return;
        setState(() {
          _modelGotowy = _analizator.isModelReady;
          _statusAnalizy = "Ready to Scan!";
        });
      } catch (e) {
        if (!mounted) return;
        setState(() => _statusAnalizy = "Model Error: $e");
      }
    }

    Future<void> _wybierzObraz() async {
      await _zapiszSkan();

      try {
        final picked = await _wybierak.pickImage(
          source: kIsWeb ? ImageSource.gallery : ImageSource.camera,
          imageQuality: 85,
        );
        if (picked == null) return;
        final bytes = await picked.readAsBytes();

        if (!mounted) return;
        setState(() {
          _bityObrazu = bytes;
          _statusAnalizy = "Analyzing image...";
          _detekcje.clear();
          _podswietloneTypy.clear();
          _pokazMonit = false;
          _skanZapisany = false;
          _przekazywanie = false;
        });

        await _analizujObraz();
      } catch (e) {
        if (!mounted) return;
        setState(() => _statusAnalizy = "Image error: $e");
      }
    }

    Future<void> _analizujObraz() async {
      if (!_modelGotowy || _bityObrazu == null) return;
      try {
        final parsedDetections = await _analizator.analyzeImageDetailed(_bityObrazu!);

        if (!mounted) return;
        if (parsedDetections.isEmpty) {
          setState(() {
            _statusAnalizy = "No items detected";
            _detekcje = [];
            _podswietloneTypy = [];
            _pokazMonit = true;
          });
          return;
        }

        final counts = parsedDetections.fold<Map<String, int>>(
          {'waste': 0, 'notWaste': 0},
          (map, d) => map..update(d.isWaste ? 'waste' : 'notWaste', (val) => val + 1),
        );
        final activeSymbols = parsedDetections
            .where((d) => d.isWaste)
            .map((d) => _symboleOdpadu[d.category] ?? "?")
            .toSet()
            .toList();

        if (!mounted) return;
        setState(() {
          _detekcje = parsedDetections;
          _podswietloneTypy = activeSymbols;
          _statusAnalizy = "Detected: ${counts['waste']} waste, ${counts['notWaste']} not waste";
          _pokazMonit = true;
        });

        if (!_przekazywanie) {
          await _zapiszSkan(force: true);
        } else {
          if (kDebugMode) print("Skipping automatic save because handoff is in progress.");
        }
      } catch (e, st) {
        if (kDebugMode) print('Analyze error: $e\n$st');
        if (!mounted) return;
        setState(() {
          _statusAnalizy = "Analysis Error: $e";
          _pokazMonit = false;
        });
      }
    }

    Future<void> _zapiszSkan({bool force = false}) async {
      if (_przekazywanie) {
        if (kDebugMode) print("Implicit save skipped: handing off to detailed scanner");
        return;
      }

      if (_detekcje.isEmpty) return;
      if (_skanZapisany && !force) return;

      try {
        final userActions = <String, String>{};
        for (final detection in _detekcje) {
          if (detection.isWaste) {
            userActions[detection.name] = 'other';
          }
        }

        if (userActions.isEmpty) return;

        await _sledzik.recordScan(
          detections: _detekcje,
          userActions: userActions,
        );

        _skanZapisany = true;

        if (kDebugMode) {
          print("HomePage quick-scan saved with actions: $userActions");
        }

        if (!mounted) return;

        ScaffoldMessenger.of(context).removeCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Quick scan saved"),
            duration: Duration(seconds: 2),
          ),
        );
      } catch (e) {
        if (kDebugMode) {
          print("Error during HomePage implicit save: $e");
        }
      }
    }

    Color _mieszajKolor() {
      if (_podswietloneTypy.isEmpty) {
        return AppTheme.statusSuccess.withValues(alpha: 0.2);
      }

      List<Color> colorsToBlend = _podswietloneTypy
          .map((type) => _koloryOdpadu[type] ?? Colors.transparent)
          .where((color) => color != Colors.transparent)
          .toList();

      if (colorsToBlend.isEmpty) {
        return AppTheme.statusSuccess.withValues(alpha: 0.2);
      }
      if (colorsToBlend.length == 1) {
        return colorsToBlend.first;
      }

      double r = 0, g = 0, b = 0;
      for (Color color in colorsToBlend) {
        r += color.r;
        g += color.g;
        b += color.b;
      }
      int count = colorsToBlend.length;
      return Color.from(
        red: r / count,
        green: g / count,
        blue: b / count,
        alpha: 1.0,
      );
    }

    Widget _budujWykres() {
      return LayoutBuilder(builder: (context, constraints) {
        final size = math.min(constraints.maxWidth, constraints.maxHeight) * 0.75;
        return AnimatedBuilder(
          animation: _kontrolerPulsu,
          builder: (context, child) {
            final pulse = 1 + 0.03 * _animacjaPulsu.value;
            return Center(
              child: SizedBox(
                width: size,
                height: size,
                child: Stack(alignment: Alignment.center, children: [
                  if (_podswietloneTypy.isNotEmpty)
                    Transform.scale(
                      scale: pulse,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: _mieszajKolor().withValues(alpha: 0.2),
                              blurRadius: 40,
                              spreadRadius: 10
                            ),
                          ],
                        ),
                      ),
                    ),
                  PieChart(
                    PieChartData(
                      borderData: FlBorderData(show: false),
                      sectionsSpace: 4,
                      centerSpaceRadius: size * 0.3,
                      sections: List.generate(_daneWykresu.length, (i) {
                        final s = _daneWykresu[i];
                        final isActive = _podswietloneTypy.contains(s["symbol"]);
                        return PieChartSectionData(
                          color: isActive ? s["color"] as Color : Colors.grey.shade300,
                          value: 1,
                          radius: isActive ? size * 0.30 : size * 0.27,
                          title: '',
                          badgeWidget: Icon(
                            s["icon"] as IconData,
                            size: isActive ? 28 : 22,
                            color: isActive ? Colors.white : Colors.grey.shade600,
                          ),
                          badgePositionPercentageOffset: 0.6,
                        );
                      }),
                    ),
                  ),
                  _budujSrodekWykresu(),
                ]),
              ),
            );
          },
        );
      });
    }

    Widget _budujSrodekWykresu() {
      return AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: ScaleTransition(scale: anim, child: child)),
        child: _detekcje.isNotEmpty
            ? Column(
                key: const ValueKey("results"),
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "${_detekcje.where((d) => d.isWaste).length}",
                    style: AppTheme.headline1.copyWith(fontSize: 32),
                  ),
                  Text("Waste Items", style: AppTheme.bodyText),
                ],
              )
            : const SizedBox(
                key: ValueKey("prompt"),
              ),
      );
    }

    Widget _budujKontrolki() {
      final statusLower = _statusAnalizy.toLowerCase();
      final Color statusColor;
      final IconData statusIcon;

      if (statusLower.contains("error")) {
        statusColor = AppTheme.statusError;
        statusIcon = LucideIcons.triangleAlert;
      } else if (statusLower.contains("detected")) {
        statusColor = AppTheme.statusSuccess;
        statusIcon = LucideIcons.checkCheck;
      } else if (statusLower.contains("analyzing")) {
        statusColor = AppTheme.accentBlue;
        statusIcon = LucideIcons.scanLine;
      } else {
        statusColor = AppTheme.notWasteColor;
        statusIcon = LucideIcons.info;
      }

      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(statusIcon, color: statusColor, size: 20),
              const SizedBox(width: 8),
              Text(_statusAnalizy, style: AppTheme.bodyText.copyWith(fontWeight: FontWeight.w500, color: statusColor)),
            ],
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _modelGotowy ? _wybierzObraz : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: _modelGotowy ? AppTheme.primaryRed : Colors.grey.shade400,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              elevation: 4,
              shadowColor: AppTheme.primaryRed.withValues(alpha: 0.4),
            ),
            icon: const Icon(LucideIcons.camera, size: 22),
            label: Text('Analyze New Image', style: AppTheme.button),
          ),
        ],
      );
    }

    Widget _budujOpcje(BuildContext context, IconData icon, String label, String routeName) {
      return InkWell(
        onTap: () => Navigator.pushNamed(context, routeName),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.cardBg,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.primaryRed.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: AppTheme.primaryRed, size: 32),
              ),
              const SizedBox(height: 12),
              Text(
                label,
                textAlign: TextAlign.center,
                style: AppTheme.bodyText.copyWith(fontWeight: FontWeight.w600, color: AppTheme.darkText),
              ),
            ],
          ),
        ),
      );
    }

    Widget _budujMonit() {
      if (!_pokazMonit) return const SizedBox.shrink();

      final hasWaste = _detekcje.any((d) => d.isWaste);
      final message = hasWaste
          ? "Get recycling tips and disposal info!"
          : "No waste found? Try the detailed scanner for a second look.";
      final iconColor = hasWaste ? AppTheme.accentBlue : AppTheme.statusWarning;

      return Container(
        margin: const EdgeInsets.only(top: 24.0, bottom: 8.0),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Icon(LucideIcons.scanLine, color: iconColor, size: 32),
            const SizedBox(width: 16),
            Expanded(child: Text(message, style: AppTheme.bodyText.copyWith(fontWeight: FontWeight.w500, color: AppTheme.darkText))),
            const SizedBox(width: 12),
            IconButton(
              style: IconButton.styleFrom(backgroundColor: AppTheme.primaryRed, foregroundColor: Colors.white),
              icon: const Icon(LucideIcons.arrowRight, size: 20),
              onPressed: _detekcje.isEmpty
                  ? null
                  : () async {
                      if (!mounted) return;
                      setState(() {
                        _przekazywanie = true;
                        _skanZapisany = true;
                      });

                      await Navigator.pushNamed(context, '/scanner', arguments: {
                        'imageBytes': _bityObrazu,
                        'detections': _detekcje,
                      });

                      if (!mounted) return;
                      setState(() {
                        _przekazywanie = false;
                      });
                    },
            ),
          ],
        ),
      );
    }

    @override
    Widget build(BuildContext context) {
      return Scaffold(
        backgroundColor: AppTheme.bgColor,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: AppTheme.bgColor,
          systemOverlayStyle: SystemUiOverlayStyle.dark,
          automaticallyImplyLeading: false,
          titleSpacing: 16,
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(color: AppTheme.primaryRed, shape: BoxShape.circle),
                child: const Icon(LucideIcons.leaf, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text("EcoLPU", style: AppTheme.headline1),
                Text("Track. Recycle. Make an Impact.", style: AppTheme.subtitle),
              ]),
            ],
          ),
        ),
        body: SafeArea(
          child: LayoutBuilder(builder: (context, constraints) {
            final isWide = constraints.maxWidth > 900;
            final analyzerSection = Container(
              decoration: BoxDecoration(
                color: AppTheme.cardBg,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, 5))],
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  isWide ? Expanded(child: _budujWykres()) : SizedBox(height: constraints.maxWidth * 0.7, child: _budujWykres()),
                  const SizedBox(height: 24),
                  _budujKontrolki(),
                ],
              ),
            );

            final appsAndResultsSection = Column(
              children: [
                if (isWide) _budujMonit(),
                const SizedBox(height: 24),
                GridView.count(
                  crossAxisCount: isWide ? 4 : 2,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 1.0,
                  children: [
                    _budujOpcje(context, LucideIcons.scan, 'Detailed Scanner', '/scanner'),
                    _budujOpcje(context, LucideIcons.map, 'Disposal Map', '/map'),
                    _budujOpcje(context, LucideIcons.trendingUp, 'Track Impact', '/trackImpact'),
                    _budujOpcje(context, LucideIcons.trophy, 'Leaderboard', '/leaderboard'),
                    _budujOpcje(context, LucideIcons.calendarDays, 'Join Events', '/events'),
                    _budujOpcje(context, LucideIcons.gamepad2, 'Minigames', '/game'),
                    _budujOpcje(context, LucideIcons.user, 'Profile', '/profile'),
                  ],
                ),
              ],
            );

            if (isWide) {
              return Padding(
                padding: const EdgeInsets.all(24.0),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(flex: 2, child: analyzerSection),
                  const SizedBox(width: 24),
                  Expanded(flex: 3, child: SingleChildScrollView(child: appsAndResultsSection)),
                ]),
              );
            } else {
              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  analyzerSection,
                  _budujMonit(),
                  appsAndResultsSection,
                ]),
              );
            }
          }),
        ),
      );
    }
  }