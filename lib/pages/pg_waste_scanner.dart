import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../config/eco_tracker_service.dart';
import '../config/eco_analyzer_service.dart';
import '../config/eco_waste_detection.dart';
import '../config/eco_styles.dart';

class _WasteTypeInfo {
  final String symbol;
  final String name;
  final String category;
  final Color color;
  final IconData icon;

  const _WasteTypeInfo({
    required this.symbol,
    required this.name,
    required this.category,
    required this.color,
    required this.icon,
  });
}

class ClassifierPage extends StatefulWidget {
  const ClassifierPage({super.key});

  @override
  State<ClassifierPage> createState() => _ClassifierPageState();
}

class _ClassifierPageState extends State<ClassifierPage>
    with TickerProviderStateMixin {
  static const List<_WasteTypeInfo> _wasteInfoList = [
    _WasteTypeInfo(symbol: "Pl", name: "Plastic", category: "PLASTIC", color: AppTheme.plasticColor, icon: LucideIcons.box),
    _WasteTypeInfo(symbol: "Sl", name: "Glass", category: "GLASS", color: AppTheme.glassColor, icon: LucideIcons.glassWater),
    _WasteTypeInfo(symbol: "Ch", name: "Organic", category: "ORGANIC", color: AppTheme.organicColor, icon: LucideIcons.leaf),
    _WasteTypeInfo(symbol: "Pa", name: "Paper", category: "PAPER", color: AppTheme.paperColor, icon: LucideIcons.fileText),
    _WasteTypeInfo(symbol: "Cu", name: "Electronic", category: "ELECTRONIC", color: AppTheme.electronicColor, icon: LucideIcons.cpu),
    _WasteTypeInfo(symbol: "Fe", name: "Metal", category: "METAL", color: AppTheme.metalColor, icon: LucideIcons.wrench),
  ];

  static final Map<String, Color> _categoryColors = {
    for (var type in _wasteInfoList) type.category: type.color,
    "NOT WASTE": AppTheme.notWasteColor,
  };

  static final Map<String, String> _wasteSymbols = {
    for (var type in _wasteInfoList) type.category: type.symbol,
  };

  final ImagePicker _picker = ImagePicker();
  final AnalyzerService _analyzerService = AnalyzerService();
  final StatTrackerService _statTracker = StatTrackerService();

  Uint8List? _selectedImageBytes;
  String _analyzerStatus = "";
  List<String> _highlightedTypes = [];
  bool _isModelReady = false;
  List<WasteDetection> _detections = [];
  int? _selectedDetectionIndex;
  final Map<int, String> _userActions = {};
  bool _scanHasBeenSaved = false;
  bool _isFirstLoad = true;

  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    inicjujModel();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isFirstLoad) {
      _isFirstLoad = false;
      final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args != null) {
        final imageBytes = args['imageBytes'] as Uint8List?;
        final detections = args['detections'] as List<WasteDetection>?;
        if (imageBytes != null && detections != null) {
          _selectedImageBytes = imageBytes;
          aktualizujStan(detections, source: "From Home Page");
        }
      }
    }
  }

  @override
  void dispose() {
    zapiszWynik();
    _pulseController.dispose();
    super.dispose();
  }

  String skrotStatusu() {
    final s = _analyzerStatus.trim();
    if (s.isEmpty) return "Ready to Scan!";
    final lower = s.toLowerCase();
    if (lower.contains("error")) return "Error Occurred";
    if (s.startsWith("Detected") || s.startsWith("From Home")) return "Analysis Complete!";
    if (s.startsWith("Re-classifying")) return "Re-classifying...";
    return s.length <= 18 ? s : "${s.substring(0, 18)}…";
  }

  Future<void> inicjujModel() async {
    setState(() => _analyzerStatus = "Loading model...");
    try {
      await _analyzerService.initializeModel();
      if (!mounted) return;
      setState(() {
        _isModelReady = _analyzerService.isModelReady;
        _analyzerStatus = "Classifier Ready";
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _analyzerStatus = "Model Error: $e");
    }
  }

  Future<void> wybierzObraz() async {
    await zapiszWynik();

    try {
      final picked = await _picker.pickImage(
        source: kIsWeb ? ImageSource.gallery : ImageSource.camera,
        imageQuality: 85,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();

      setState(() {
        _selectedImageBytes = bytes;
        _analyzerStatus = "Analyzing image...";
        _detections.clear();
        _highlightedTypes.clear();
        _selectedDetectionIndex = null;
        _userActions.clear();
        _scanHasBeenSaved = false;
      });

      await analizujObraz();
    } catch (e) {
      if (!mounted) return;
      setState(() => _analyzerStatus = "Image error: $e");
    }
  }

  Future<void> analizujObraz() async {
    if (!_isModelReady || _selectedImageBytes == null) {
      if (!_isModelReady) setState(() => _analyzerStatus = "Model not ready");
      return;
    }
    try {
      final parsedDetections = await _analyzerService.analyzeImageDetailed(_selectedImageBytes!);
      if (!mounted) return;
      if (parsedDetections.isEmpty) {
        setState(() {
          _analyzerStatus = "No items detected";
          _detections = [];
          _highlightedTypes = [];
        });
        return;
      }
      aktualizujStan(parsedDetections);
    } catch (e) {
      if (!mounted) return;
      setState(() => _analyzerStatus = "Analysis Error: $e");
    }
  }

  void aktualizujStan(List<WasteDetection> newDetections, {String? source}) {
    final activeSymbols = newDetections
        .where((d) => d.isWaste)
        .map((d) => _wasteSymbols[d.category] ?? "?")
        .toSet()
        .toList();

    String status;
    if (source != null) {
      status = source;
    } else {
      final wasteCount = newDetections.where((d) => d.isWaste).length;
      final notWasteCount = newDetections.length - wasteCount;
      status = "Detected: $wasteCount waste, $notWasteCount not waste";
    }

    setState(() {
      _detections = newDetections;
      _highlightedTypes = activeSymbols;
      _analyzerStatus = status;
      _selectedDetectionIndex = null;
    });
  }

  Future<void> reklasyfikujOdpad(WasteDetection item) async {
    final bool? shouldReclassify = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("Re-classify Item?", style: AppTheme.headline2),
        content: Text("Would you like to get waste classification and tips for '${item.name}'?", style: AppTheme.bodyText),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text("Cancel", style: AppTheme.button.copyWith(color: AppTheme.lightText)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.primaryRed),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text("Re-classify", style: AppTheme.button),
          ),
        ],
      ),
    );

    if (shouldReclassify != true) return;

    setState(() => _analyzerStatus = "Re-classifying...");

    try {
      final newDetection = await _analyzerService.reclassifyItem(item);
      if (!mounted) return;
      final updatedDetections = List<WasteDetection>.from(_detections);
      final index = updatedDetections.indexOf(item);
      if (index != -1) {
        updatedDetections[index] = newDetection;
        aktualizujStan(updatedDetections);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _analyzerStatus = "Re-classify Error: $e");
    }
  }

  void wybierzAkcjeOdpadu(int index, String action) {
    setState(() => _userActions[index] = action);
  }

  Future<void> zapiszWynik() async {
    if (_detections.isEmpty || _scanHasBeenSaved) return;

    try {
      final finalUserActions = <String, String>{};
      for (int i = 0; i < _detections.length; i++) {
        final detection = _detections[i];
        finalUserActions[detection.name] = _userActions[i] ?? (detection.isWaste ? 'other' : 'not_waste');
      }

      await _statTracker.recordScan(
        detections: _detections,
        userActions: finalUserActions,
      );
      _scanHasBeenSaved = true;

      if (kDebugMode) {
        print("Scan implicitly saved with actions: $finalUserActions");
      }
    } catch (e) {
      if (kDebugMode) {
        print("Error during implicit save: $e");
      }
    }
  }

  Widget elementTypu(String symbol, String name, Color color, {required IconData icon}) {
    final isActive = _highlightedTypes.contains(symbol);
    final glow = Tween(begin: 0.0, end: 6.0).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeOut));

    return Tooltip(
      message: name,
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          return AnimatedScale(
            scale: isActive ? 1.1 : 1.0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutBack,
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isActive ? [color, color.withValues(alpha: 0.7)] : [Colors.grey.shade200, Colors.grey.shade100],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: isActive
                    ? [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: glow.value + 4, spreadRadius: 1)]
                    : [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(2, 2))],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: isActive ? Colors.white : AppTheme.darkText, size: 28),
                  const SizedBox(height: 4),
                  Text(
                    symbol,
                    style: AppTheme.bodyText.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isActive ? Colors.white : AppTheme.darkText,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget naglowek() {
    return Container(
      padding: const EdgeInsets.only(top: 16, bottom: 24),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 20, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: _wasteInfoList.sublist(0, 3).map((type) => elementTypu(type.symbol, type.name, type.color, icon: type.icon)).toList(),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: _wasteInfoList.sublist(3, 6).map((type) => elementTypu(type.symbol, type.name, type.color, icon: type.icon)).toList(),
            ),
          )
        ],
      ),
    );
  }

  Widget wierszStanu() {
    final label = skrotStatusu();
    final lower = _analyzerStatus.toLowerCase();
    final Color chipColor;
    final IconData chipIcon;

    if (lower.contains("error")) {
      chipColor = AppTheme.statusError;
      chipIcon = LucideIcons.triangleAlert;
    } else if (label.contains("Complete")) {
      chipColor = AppTheme.statusSuccess;
      chipIcon = LucideIcons.checkCheck;
    } else if (lower.contains("analyzing") || lower.contains("classifying")) {
      chipColor = AppTheme.statusInfo;
      chipIcon = LucideIcons.scanLine;
    } else {
      chipColor = AppTheme.notWasteColor;
      chipIcon = LucideIcons.info;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: chipColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(chipIcon, color: chipColor, size: 20),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              _analyzerStatus,
              style: AppTheme.bodyText.copyWith(fontWeight: FontWeight.w500, color: chipColor),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget dolnyPasekNaw() {
    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      notchMargin: 8,
      color: AppTheme.cardBg,
      elevation: 10,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          przyciskNaw(LucideIcons.house, "Home", () => Navigator.pushReplacementNamed(context, '/home')),
          przyciskNaw(LucideIcons.map, "Map", () => Navigator.pushReplacementNamed(context, '/map')),
          const SizedBox(width: 48),
          przyciskNaw(LucideIcons.trendingUp, "Tracker", () => Navigator.pushReplacementNamed(context, '/trackImpact')),
          przyciskNaw(LucideIcons.gamepad2, "Games", () {}),
        ],
      ),
    );
  }

  Widget przyciskNaw(IconData icon, String tooltip, VoidCallback onPressed) {
    return IconButton(
      icon: Icon(icon, color: AppTheme.lightText, size: 26),
      tooltip: tooltip,
      onPressed: onPressed,
    );
  }

  Widget podgladObrazu() {
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.cardBg,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.grey.shade200, width: 2),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: _selectedImageBytes != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: Image.memory(_selectedImageBytes!, fit: BoxFit.cover),
              )
            : Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(LucideIcons.imagePlus, size: 60, color: AppTheme.lightText),
                    const SizedBox(height: 16),
                    Text(
                      "Scan an item to begin!",
                      style: AppTheme.bodyText.copyWith(fontSize: 16, color: AppTheme.darkText),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget listaDetekcji() {
    if (_detections.isEmpty) {
      if (_analyzerStatus.contains("No items detected")) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text(
              "Couldn't find any items. Maybe try a different picture?",
              textAlign: TextAlign.center,
              style: AppTheme.bodyText.copyWith(fontSize: 16),
            ),
          ),
        );
      }
      return const SizedBox.shrink();
    }

    final List<WasteDetection> wasteItems = [];
    final List<WasteDetection> nonWasteItems = [];
    for (final detection in _detections) {
      if (detection.isWaste) {
        wasteItems.add(detection);
      } else {
        nonWasteItems.add(detection);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Text("Detection Results", style: AppTheme.headline1),
        ),
        const SizedBox(height: 16),
        ...wasteItems.map((item) {
          final originalIndex = _detections.indexOf(item);
          return kartaDetekcji(item, originalIndex);
        }),
        if (nonWasteItems.isNotEmpty) listaInnych(nonWasteItems),
      ],
    );
  }

  Widget listaInnych(List<WasteDetection> items) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ExpansionTile(
        title: Text(
          "${items.length} Non-Waste Item(s)",
          style: AppTheme.bodyText.copyWith(fontWeight: FontWeight.bold, color: AppTheme.darkText),
        ),
        subtitle: Text("Long-press to re-classify", style: AppTheme.bodyText),
        children: items.map((item) {
          final originalIndex = _detections.indexOf(item);
          return GestureDetector(
            onLongPress: () => reklasyfikujOdpad(item),
            child: kartaDetekcji(item, originalIndex),
          );
        }).toList(),
      ),
    );
  }

  Widget kartaDetekcji(WasteDetection detection, int index) {
    final color = _categoryColors[detection.category] ?? AppTheme.primaryRed;
    final isSelected = _selectedDetectionIndex == index;
    final userAction = _userActions[index];

    return GestureDetector(
      onTap: () => setState(() {
        _selectedDetectionIndex = isSelected ? null : index;
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: AppTheme.cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? color : Colors.transparent, width: 2.5),
          boxShadow: [
            BoxShadow(
              color: isSelected ? color.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.08),
              blurRadius: isSelected ? 12 : 6,
              spreadRadius: isSelected ? 2 : 0,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
                      child: Text(detection.category, style: AppTheme.button.copyWith(fontSize: 16)),
                    ),
                    const Spacer(),
                    Chip(
                      label: Text("${(detection.confidence * 100).toStringAsFixed(0)}% Certain"),
                      backgroundColor: color.withValues(alpha: 0.15),
                      labelStyle: AppTheme.bodyText.copyWith(color: color, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(detection.name, style: AppTheme.headline2),
                const SizedBox(height: 8),
                Text("Reasoning: ${detection.reasoning}", style: AppTheme.bodyText.copyWith(fontStyle: FontStyle.italic)),
                if (detection.isWaste) ...[
                  const Divider(height: 32, thickness: 1),
                  wierszPorady(LucideIcons.trash2, "Disposal", detection.disposalTip ?? "No tip available."),
                  const SizedBox(height: 16),
                  wierszPorady(LucideIcons.recycle, "Recycling", detection.recyclingTip ?? "No tip available."),
                  const SizedBox(height: 24),
                  przyciskiAkcji(detection, index, userAction),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget przyciskiAkcji(WasteDetection detection, int index, String? userAction) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        przyciskAkcji(
          icon: LucideIcons.recycle,
          label: 'Recycled',
          color: AppTheme.statusSuccess,
          isSelected: userAction == 'recycled',
          onPressed: () => wybierzAkcjeOdpadu(index, 'recycled'),
        ),
        przyciskAkcji(
          icon: LucideIcons.trash2,
          label: 'Disposed',
          color: AppTheme.statusError,
          isSelected: userAction == 'disposed',
          onPressed: () => wybierzAkcjeOdpadu(index, 'disposed'),
        ),
        przyciskAkcji(
          icon: LucideIcons.circleQuestionMark,
          label: 'Other',
          color: AppTheme.lightText,
          isSelected: userAction == 'other',
          onPressed: () => wybierzAkcjeOdpadu(index, 'other'),
        ),
      ],
    );
  }

  Widget przyciskAkcji({
    required IconData icon,
    required String label,
    required Color color,
    required bool isSelected,
    required VoidCallback onPressed,
  }) {
    final buttonStyle = isSelected
        ? FilledButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white)
        : FilledButton.styleFrom(backgroundColor: AppTheme.cardBg, foregroundColor: color, side: BorderSide(color: Colors.grey.shade300));

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
        child: FilledButton.icon(
            onPressed: onPressed,
            icon: Icon(icon, size: 16),
            label: Text(label),
            style: buttonStyle.copyWith(
              padding: WidgetStateProperty.all(const EdgeInsets.symmetric(vertical: 12)),
              shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            )),
      ),
    );
  }

  Widget wierszPorady(IconData icon, String title, String tip) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppTheme.primaryRed, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTheme.bodyText.copyWith(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.darkText)),
              const SizedBox(height: 4),
              Text(tip, style: AppTheme.bodyText.copyWith(height: 1.5)),
            ],
          ),
        ),
      ],
    );
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
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(color: AppTheme.primaryRed, shape: BoxShape.circle),
              child: const Icon(LucideIcons.leaf, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Waste Classifier", style: AppTheme.headline2),
                Text("Spot the Type, Do It Right!", style: AppTheme.subtitle),
              ],
            ),
          ],
        ),
      ),
      bottomNavigationBar: dolnyPasekNaw(),
      floatingActionButton: FloatingActionButton(
        onPressed: _isModelReady ? wybierzObraz : null,
        backgroundColor: _isModelReady ? AppTheme.primaryRed : Colors.grey.shade400,
        tooltip: 'Scan Waste',
        shape: const CircleBorder(),
        child: const Icon(LucideIcons.camera, color: Colors.white, size: 28),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWideScreen = constraints.maxWidth > 700;
            final content = listaDetekcji();

            if (isWideScreen) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.only(bottom: 80),
                      child: Column(
                        children: [
                          naglowek(),
                          Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              children: [
                                podgladObrazu(),
                                const SizedBox(height: 24),
                                wierszStanu(),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 80),
                      child: content,
                    ),
                  ),
                ],
              );
            } else {
              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    naglowek(),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 24, 16, 80),
                      child: Column(
                        children: [
                          podgladObrazu(),
                          const SizedBox(height: 24),
                          wierszStanu(),
                          const SizedBox(height: 24),
                          content,
                        ],
                      ),
                    )
                  ],
                ),
              );
            }
          },
        ),
      ),
    );
  }
}