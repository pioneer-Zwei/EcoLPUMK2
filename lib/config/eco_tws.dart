import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlong;

class RadarUserData {
  final String uid;
  final latlong.LatLng point;

  RadarUserData({
    required this.uid,
    required this.point,
  });
}

class PingedUserData {
  final DateTime pingTime;
  final int totalDurationMs;

  PingedUserData({required this.pingTime, required this.totalDurationMs});
}

class RadarSweep extends StatefulWidget {
  final bool isPinging;
  final MapController mapController;
  final latlong.LatLng userLocation;
  final double mapRotation;
  final List<RadarUserData> nearbyUsers;
  final Function(Map<String, PingedUserData>) onPingedUsersUpdate;
  final VoidCallback onPingCompleted;

  const RadarSweep({
    super.key,
    required this.isPinging,
    required this.mapController,
    required this.userLocation,
    required this.mapRotation,
    required this.nearbyUsers,
    required this.onPingedUsersUpdate,
    required this.onPingCompleted,
  });

  @override
  State<RadarSweep> createState() => _RadarSweepState();
}

class _RadarSweepState extends State<RadarSweep> with TickerProviderStateMixin {
  AnimationController? _radarController;
  AnimationController? _radarFadeController;
  Animation<double>? _radarStartupAnimation;
  Animation<double>? _radarSweepAnimation;
  Animation<double>? _radarFadeAnimation;

  final Map<String, PingedUserData> _pingedUsers = {};
  double _previousSweepAngle = 0.0;
  final Set<String> _refreshedThisSweep = {};
  final _random = math.Random();

  @override
  void initState() {
    super.initState();
    _inicjujAnimacje();
  }

  @override
  void dispose() {
    _radarController?.dispose();
    _radarFadeController?.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(RadarSweep oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPinging && !oldWidget.isPinging) {
      _uruchomPing();
    }
  }

  void _inicjujAnimacje() {
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    );

    _radarFadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _radarStartupAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _radarController!,
        curve: const Interval(0.0, 0.2, curve: Curves.easeOut),
      ),
    );

    _radarSweepAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _radarController!,
        curve: const Interval(0.2, 1.0, curve: Curves.linear),
      ),
    )..addListener(_aktualizujPingi);

    _radarFadeAnimation =
        Tween<double>(begin: 0.0, end: 1.0).animate(_radarFadeController!);

    _radarController!.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _radarFadeController!.forward(from: 0.0);
      }
    });

    _radarFadeController!.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onPingCompleted();
      }
    });
  }

  void _uruchomPing() {
    if (!mounted) return;
    _refreshedThisSweep.clear();
    _previousSweepAngle = 0.0;
    _radarFadeController?.reset();
    _radarController?.forward(from: 0.0);
  }

  void _aktualizujPingi() {
    if (!widget.isPinging || _radarSweepAnimation?.value == 0) return;

    final currentSweepAngle = (_radarSweepAnimation!.value * 360);

    for (final user in widget.nearbyUsers) {
      final bearing =
          const latlong.Distance().bearing(widget.userLocation, user.point);
      final normalizedBearing = (bearing + 360) % 360;

      bool detectedThisFrame = false;
      if (currentSweepAngle < _previousSweepAngle) {
        if (normalizedBearing > _previousSweepAngle ||
            normalizedBearing <= currentSweepAngle) {
          detectedThisFrame = true;
        }
      } else {
        if (normalizedBearing > _previousSweepAngle &&
            normalizedBearing <= currentSweepAngle) {
          detectedThisFrame = true;
        }
      }

      if (detectedThisFrame && !_refreshedThisSweep.contains(user.uid)) {
        final duration = _random.nextInt(30000) + 30000;
        _pingedUsers[user.uid] = PingedUserData(
          pingTime: DateTime.now(),
          totalDurationMs: duration,
        );
        _refreshedThisSweep.add(user.uid);

        widget.onPingedUsersUpdate(Map.of(_pingedUsers));
      }
    }
    _previousSweepAngle = currentSweepAngle;
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isPinging) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(builder: (context, constraints) {
      Offset centerOffset;
      double radiusInPixels;

      try {
        centerOffset =
            widget.mapController.camera.latLngToScreenOffset(widget.userLocation);

        const distance = latlong.Distance();
        final pointAt15km = distance.offset(widget.userLocation, 15000, 0);
        final screenPointAt15km =
            widget.mapController.camera.latLngToScreenOffset(pointAt15km);

        radiusInPixels = (screenPointAt15km - centerOffset).distance;

        if (centerOffset.dx.isNaN ||
            centerOffset.dy.isNaN ||
            radiusInPixels.isNaN) {
          centerOffset =
              Offset(constraints.maxWidth / 2, constraints.maxHeight / 2);
          radiusInPixels =
              math.min(constraints.maxWidth, constraints.maxHeight) / 2;
        }
      } catch (e) {
        centerOffset =
            Offset(constraints.maxWidth / 2, constraints.maxHeight / 2);
        radiusInPixels =
            math.min(constraints.maxWidth, constraints.maxHeight) / 2;
      }

      return CustomPaint(
        painter: _RadarSweepPainter(
          startupAnimation: _radarStartupAnimation!,
          sweepAnimation: _radarSweepAnimation!,
          fadeAnimation: _radarFadeAnimation!,
          center: centerOffset,
          radius: radiusInPixels,
          mapRotation: widget.mapRotation,
        ),
        child: const SizedBox.expand(),
      );
    });
  }
}

class _RadarSweepPainter extends CustomPainter {
  final Animation<double> startupAnimation;
  final Animation<double> sweepAnimation;
  final Animation<double> fadeAnimation;
  final Offset center;
  final double radius;
  final double mapRotation;

  _RadarSweepPainter({
    required this.startupAnimation,
    required this.sweepAnimation,
    required this.fadeAnimation,
    required this.center,
    required this.radius,
    required this.mapRotation,
  }) : super(
            repaint: Listenable.merge(
                [startupAnimation, sweepAnimation, fadeAnimation]));

  @override
  void paint(Canvas canvas, Size size) {
    if (radius <= 0) return;

    final startupValue = startupAnimation.value;
    final sweepValue = sweepAnimation.value;
    final fadeOutOpacity = 1.0 - fadeAnimation.value;

    if (startupValue > 0 && startupValue < 1.0) {
      final startupRadius = radius * startupValue;
      final startupPaint = Paint()
        ..color =
            Colors.green.withValues(alpha: 0.5 * (1 - startupValue) * fadeOutOpacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      canvas.drawCircle(center, startupRadius, startupPaint);
    }

    final gridOpacity = (startupValue > 0.5) ? (startupValue - 0.5) * 2 : 0.0;
    if (gridOpacity <= 0 && sweepValue <= 0) return;

    if (gridOpacity > 0.0) {
      final backgroundPaint = Paint()
        ..shader = ui.Gradient.radial(
          center,
          radius,
          [
            Colors.green.withValues(alpha: 0.05 * gridOpacity * fadeOutOpacity),
            Colors.green.withValues(alpha: 0.25 * gridOpacity * fadeOutOpacity),
          ],
          [0.0, 1.0],
        );
      canvas.drawCircle(center, radius, backgroundPaint);
    }

    final gridPaint = Paint()
      ..color = Colors.green.withValues(alpha: 
          0.5 * (sweepValue > 0 ? 1.0 : gridOpacity) * fadeOutOpacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final ringDistances = [3.0, 6.0, 9.0, 12.0, 15.0];
    for (var i = 0; i < ringDistances.length; i++) {
      final ringRadius = radius * (ringDistances[i] / 15.0);
      canvas.drawCircle(center, ringRadius, gridPaint);

      _malujTekst(
        canvas,
        '${ringDistances[i]} km',
        center + Offset(5, -ringRadius - 12),
        fontSize: 10,
        color: Colors.green
            .withValues(alpha: (sweepValue > 0 ? 1.0 : gridOpacity) * fadeOutOpacity),
      );
    }

    final bearingPaint = Paint()
      ..color = Colors.green.withValues(alpha: 
          0.3 * (sweepValue > 0 ? 1.0 : gridOpacity) * fadeOutOpacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    final bearingLabels = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-mapRotation * (math.pi / 180));

    for (var i = 0; i < 8; i++) {
      final bearingAngle = i * (math.pi / 4);
      final startPoint =
          Offset.fromDirection(bearingAngle - math.pi / 2, radius * 0.2);
      final endPoint =
          Offset.fromDirection(bearingAngle - math.pi / 2, radius);
      canvas.drawLine(startPoint, endPoint, bearingPaint);

      _malujTekst(
        canvas,
        bearingLabels[i],
        Offset.fromDirection(bearingAngle - math.pi / 2, radius + 15),
        fontSize: 12,
        color: Colors.green
            .withValues(alpha: (sweepValue > 0 ? 1.0 : gridOpacity) * fadeOutOpacity),
        isCentered: true,
      );
    }
    canvas.restore();

    if (sweepValue > 0) {
      final angle = (2 * math.pi * sweepValue);
      final sweepPaint = Paint()
        ..shader = ui.Gradient.sweep(
          center,
          [
            Colors.transparent,
            Colors.green.withValues(alpha: 0.05 * fadeOutOpacity),
            Colors.green.withValues(alpha: 0.4 * fadeOutOpacity),
            Colors.green.withValues(alpha: 0.05 * fadeOutOpacity),
            Colors.transparent,
          ],
          [0.0, 0.4, 0.5, 0.6, 1.0],
          TileMode.clamp,
          -math.pi / 2,
          math.pi * 2,
        );

      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(angle);
      canvas.translate(-center.dx, -center.dy);
      canvas.drawCircle(center, radius, sweepPaint);
      canvas.restore();

      final linePaint = Paint()
        ..color = Colors.lightGreenAccent.withValues(alpha: fadeOutOpacity)
        ..strokeWidth = 2.0
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);
      final lineEnd = Offset(
        center.dx + radius * math.cos(angle - math.pi / 2),
        center.dy + radius * math.sin(angle - math.pi / 2),
      );
      canvas.drawLine(center, lineEnd, linePaint);
    }
  }

  void _malujTekst(
    Canvas canvas,
    String text,
    Offset position, {
    double fontSize = 12.0,
    Color color = Colors.white,
    bool isCentered = false,
  }) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          shadows: [
            Shadow(
                color: Colors.black.withValues(alpha: color.r),
                blurRadius: 2),
          ],
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    var finalPosition = position;
    if (isCentered) {
      finalPosition = Offset(
        position.dx - textPainter.width / 2,
        position.dy - textPainter.height / 2,
      );
    }
    textPainter.paint(canvas, finalPosition);
  }

  @override
  bool shouldRepaint(covariant _RadarSweepPainter oldDelegate) {
    return radius != oldDelegate.radius ||
        center != oldDelegate.center ||
        mapRotation != oldDelegate.mapRotation;
  }
}