import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:eco_lpu/config/eco_styles.dart';

enum GameObjectType { rock, paper, scissors }
enum GameState { betting, countdown, simulating, finished }

class RPSGamePage extends StatefulWidget {
  const RPSGamePage({super.key});

  @override
  State<RPSGamePage> createState() => _RPSGamePageState();
}

class _RPSGamePageState extends State<RPSGamePage> with TickerProviderStateMixin {
  GameState _stanGry = GameState.betting;
  GameObjectType? _zakladUzytkownika;
  int _odliczanie = 5;
  Timer? _czasomierz;
  late AnimationController _kontrolerAnimacji;
  final List<GameObject> _obiektyGry = [];
  final int _liczbaObiektow = 15;
  static const double _promienObiektu = 18.0;
  Size? _obszarGry;

  @override
  void initState() {
    super.initState();
    _kontrolerAnimacji = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..addListener(() {
        if (_stanGry == GameState.simulating && _obszarGry != null) {
          aktualizujGre(_obszarGry!);
        }
      });
  }

  @override
  void dispose() {
    _czasomierz?.cancel();
    _kontrolerAnimacji.dispose();
    super.dispose();
  }

  void startGry() {
    if (_zakladUzytkownika == null) return;
    setState(() => _stanGry = GameState.countdown);
    _czasomierz = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_odliczanie > 1) {
        setState(() => _odliczanie--);
      } else {
        timer.cancel();
        symulujGre();
      }
    });
  }

  void symulujGre() {
    if (!mounted || _obszarGry == null) return;
    setState(() {
      _stanGry = GameState.simulating;
      utworzObiekty(_obszarGry!);
    });
    _kontrolerAnimacji.repeat();
  }

  void utworzObiekty(Size size) {
    final random = Random();
    _obiektyGry.clear();
    final typy = GameObjectType.values;

    for (int i = 0; i < _liczbaObiektow * 3; i++) {
      final type = typy[i ~/ _liczbaObiektow];
      _obiektyGry.add(GameObject(
        type: type,
        x: _promienObiektu + random.nextDouble() * (size.width - _promienObiektu * 2),
        y: _promienObiektu + random.nextDouble() * (size.height - _promienObiektu * 2),
        dx: (random.nextDouble() - 0.5) * 1.5,
        dy: (random.nextDouble() - 0.5) * 1.5,
        radius: _promienObiektu,
      ));
    }
  }

  void aktualizujGre(Size size) {
    if (!mounted) return;

    for (var obj in _obiektyGry) {
      obj.x += obj.dx;
      obj.y += obj.dy;

      if (obj.x <= obj.radius && obj.dx < 0) obj.dx *= -1;
      if (obj.x >= size.width - obj.radius && obj.dx > 0) obj.dx *= -1;
      if (obj.y <= obj.radius && obj.dy < 0) obj.dy *= -1;
      if (obj.y >= size.height - obj.radius && obj.dy > 0) obj.dy *= -1;
    }

    for (int i = 0; i < _obiektyGry.length; i++) {
      for (int j = i + 1; j < _obiektyGry.length; j++) {
        final obj1 = _obiektyGry[i];
        final obj2 = _obiektyGry[j];
        final dx = obj2.x - obj1.x;
        final dy = obj2.y - obj1.y;
        final distanceSq = dx * dx + dy * dy;
        final minDistance = obj1.radius + obj2.radius;

        if (distanceSq < minDistance * minDistance) {
          final distance = sqrt(distanceSq);
          zmienTyp(obj1, obj2);
          obsluzZderzenie(obj1, obj2, dx, dy, distance, minDistance);
        }
      }
    }

    if (czyKoniecGry()) {
      _kontrolerAnimacji.stop();
      if (mounted) setState(() => _stanGry = GameState.finished);
    }
  }

  void obsluzZderzenie(GameObject obj1, GameObject obj2, double dx, double dy, double distance, double minDistance) {
    final overlap = (minDistance - distance) * 0.5;
    final nx = dx / distance;
    final ny = dy / distance;

    obj1.x -= overlap * nx;
    obj1.y -= overlap * ny;
    obj2.x += overlap * nx;
    obj2.y += overlap * ny;

    final k1 = obj1.dx * nx + obj1.dy * ny;
    final k2 = obj2.dx * nx + obj2.dy * ny;

    obj1.dx += (k2 - k1) * nx;
    obj1.dy += (k2 - k1) * ny;
    obj2.dx += (k1 - k2) * nx;
    obj2.dy += (k1 - k2) * ny;
  }

  void zmienTyp(GameObject obj1, GameObject obj2) {
    if (obj1.type == obj2.type) return;
    if (czyWygrywa(obj1.type, obj2.type)) {
      obj2.type = obj1.type;
    } else if (czyWygrywa(obj2.type, obj1.type)) {
      obj1.type = obj2.type;
    }
  }

  bool czyWygrywa(GameObjectType a, GameObjectType b) {
    return (a == GameObjectType.rock && b == GameObjectType.scissors) ||
           (a == GameObjectType.paper && b == GameObjectType.rock) ||
           (a == GameObjectType.scissors && b == GameObjectType.paper);
  }

  bool czyKoniecGry() {
    if (_obiektyGry.isEmpty) return false;
    final firstType = _obiektyGry.first.type;
    return _obiektyGry.every((obj) => obj.type == firstType);
  }

  void resetujGre() {
    setState(() {
      _stanGry = GameState.betting;
      _zakladUzytkownika = null;
      _odliczanie = 5;
      _obiektyGry.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
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
            child: const Icon(LucideIcons.gamepad2, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('RPS Battle', style: AppTheme.headline2),
            Text('Place your bet and watch the chaos.', style: AppTheme.subtitle),
          ]),
        ]),
      ),
      bottomNavigationBar: dolnyPasek(),
      body: LayoutBuilder(
        builder: (context, constraints) {
          _obszarGry = constraints.biggest;
          return Center(child: glownyWidok());
        },
      ),
    );
  }

  Widget dolnyPasek() {
    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      notchMargin: 8,
      color: AppTheme.cardBg,
      elevation: 10,
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
        guzikNawigacji(LucideIcons.house, 'Home', '/home'),
        guzikNawigacji(LucideIcons.scanLine, 'Classifier', '/scanner'),
        const SizedBox(width: 48),
        guzikNawigacji(LucideIcons.trendingUp, 'Tracker', '/trackImpact'),
        guzikNawigacji(LucideIcons.gamepad2, 'Games', '/games'),
      ]),
    );
  }

  Widget guzikNawigacji(IconData icon, String tooltip, String route) {
    return IconButton(
      icon: Icon(icon, color: AppTheme.lightText, size: 26),
      tooltip: tooltip,
      onPressed: () => Navigator.pushReplacementNamed(context, route),
    );
  }

  Widget glownyWidok() {
    switch (_stanGry) {
      case GameState.betting:
        return widokZakladu();
      case GameState.countdown:
        return widokOdliczania();
      case GameState.simulating:
        return widokSymulacji();
      case GameState.finished:
        return widokKoncowy();
    }
  }

  Widget widokZakladu() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Who will be the last one standing?', style: AppTheme.headline1),
          const SizedBox(height: 8),
          Text('Place your bet below.', style: AppTheme.bodyText),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              guzikZakladu(GameObjectType.rock, '🪨'),
              guzikZakladu(GameObjectType.paper, '📄'),
              guzikZakladu(GameObjectType.scissors, '✂️'),
            ],
          ),
          const SizedBox(height: 40),
          if (_zakladUzytkownika != null)
            ElevatedButton.icon(
              onPressed: startGry,
              icon: const Icon(LucideIcons.play, color: Colors.white),
              label: Text('Start Game', style: AppTheme.button),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryRed,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
        ],
      ),
    );
  }

  Widget guzikZakladu(GameObjectType type, String emoji) {
    final isSelected = _zakladUzytkownika == type;
    return GestureDetector(
      onTap: () => setState(() => _zakladUzytkownika = type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 90,
        height: 90,
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryRed.withValues(alpha: 0.1) : AppTheme.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppTheme.primaryRed : Colors.grey.shade300,
            width: isSelected ? 3 : 1,
          ),
          boxShadow: isSelected ? [
            BoxShadow(
              color: AppTheme.primaryRed.withValues(alpha: 0.2),
              blurRadius: 8,
              spreadRadius: 2,
            )
          ] : [],
        ),
        child: Center(child: Text(emoji, style: const TextStyle(fontSize: 40))),
      ),
    );
  }

  Widget widokOdliczania() {
    return Text(
      '$_odliczanie',
      style: AppTheme.headline1.copyWith(fontSize: 120, color: AppTheme.darkText.withValues(alpha: 0.8)),
    );
  }

  Widget widokSymulacji() {
    return CustomPaint(
      painter: _GamePainter(_obiektyGry),
      size: _obszarGry ?? Size.zero,
    );
  }

  Widget widokKoncowy() {
    if (_obiektyGry.isEmpty) return const SizedBox.shrink();
    final winner = _obiektyGry.first.type;
    final didUserWin = _zakladUzytkownika == winner;

    return Container(
      padding: const EdgeInsets.all(24),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: AppTheme.cardBg,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 10)]),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            didUserWin ? 'Congratulations!' : 'Better Luck Next Time!',
            style: AppTheme.headline1.copyWith(
              color: didUserWin ? AppTheme.statusSuccess : AppTheme.statusError,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'The final winner is ${winner.name.toUpperCase()}!',
            style: AppTheme.bodyText.copyWith(color: AppTheme.darkText, fontSize: 16),
          ),
          Text(
            GameObject.emojiDlaTypu(winner),
            style: const TextStyle(fontSize: 60, height: 1.5),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: resetujGre,
            icon: const Icon(LucideIcons.refreshCw, color: Colors.white),
            label: Text('Play Again', style: AppTheme.button),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryRed,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
}

class _GamePainter extends CustomPainter {
  final List<GameObject> gameObjects;
  static final Map<GameObjectType, TextPainter> _painters = {
    for (var type in GameObjectType.values)
      type: TextPainter(
        text: TextSpan(text: GameObject.emojiDlaTypu(type), style: const TextStyle(fontSize: 30)),
        textDirection: TextDirection.ltr,
      )..layout()
  };

  _GamePainter(this.gameObjects);

  @override
  void paint(Canvas canvas, Size size) {
    for (final obj in gameObjects) {
      final painter = _painters[obj.type];
      painter?.paint(canvas, Offset(obj.x - obj.radius, obj.y - obj.radius));
    }
  }

  @override
  bool shouldRepaint(covariant _GamePainter oldDelegate) => true;
}

class GameObject {
  GameObjectType type;
  double x, y, dx, dy, radius;

  GameObject({
    required this.type,
    required this.x,
    required this.y,
    required this.dx,
    required this.dy,
    required this.radius,
  });

  String get emoji => emojiDlaTypu(type);

  static final Map<GameObjectType, String> _emojiMap = {
    GameObjectType.rock: '🪨',
    GameObjectType.paper: '📄',
    GameObjectType.scissors: '✂️',
  };

  static String emojiDlaTypu(GameObjectType type) {
    return _emojiMap[type] ?? '';
  }
}