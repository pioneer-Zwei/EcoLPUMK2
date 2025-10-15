import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:eco_lpu/config/eco_styles.dart';
import 'package:eco_lpu/config/eco_tracker_service.dart';
import 'package:eco_lpu/config/eco_tws.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart' as latlong;
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';



class _PoiData {
  final latlong.LatLng point;
  final Map<String, dynamic> tags;
  _PoiData({required this.point, required this.tags});
}

class _UserData {
  final String uid;
  final String displayName;
  final latlong.LatLng point;
  final Timestamp lastSeen;
  final String? avatarUrl;
  final bool isActive;

  _UserData({
    required this.uid,
    required this.displayName,
    required this.point,
    required this.lastSeen,
    this.avatarUrl,
    required this.isActive,
  });
}

class MapPage extends StatefulWidget {
  const MapPage({super.key});
  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> with TickerProviderStateMixin {

  final MapController _mapController = MapController();
  final StatTrackerService _trackerService = StatTrackerService();

  latlong.LatLng _userLocation = const latlong.LatLng(14.290915, 120.915341);
  latlong.LatLng? _lastKnownRealLocation;
  latlong.LatLng? _lastPoiFetchLocation;

  String _currentUserDisplayName = 'You';
  String? _currentUserAvatarUrl;

  List<_PoiData> _poiData = [];
  List<_UserData> _nearbyUsers = [];
  List<latlong.LatLng> _routePoints = [];
  bool _isLoadingMap = true;
  bool _isRouting = false;

  List<Marker> _poiMarkers = [];
  List<Marker> _userMarkers = [];

  double? _routeDistance;
  double? _routeDuration;

  bool _isLegendExpanded = false;

  double _heading = 0.0;
  bool _followUser = true;
  StreamSubscription<Position>? _positionSub;
  StreamSubscription<CompassEvent>? _compassSub;
  StreamSubscription? _usersSub;
  DateTime _lastPositionUpdate = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastHeadingUpdate = DateTime.fromMillisecondsSinceEpoch(0);
  double _gpsAccuracy = 0.0;

  double _mapRotation = 0.0;
  bool _isAtMaxZoom = false;
  static const double _maxZoomLevel = 17.0;
  static const double _minZoomLevel = 3.0;

  bool _isPinging = false;

  bool _isDebugMode = false;
  final List<_UserData> _dummyUsers = [];
  String? _ghostUserId;
  final Map<String, PingedUserData> _pingedUsers = {};
  String? _highlightedUserId;
  Timer? _fadeTimer;

  final Map<String, Map<String, dynamic>> _userProfileCache = {};

  Timer? _debounce;
  final _random = math.Random();

  @override
  void initState() {
    super.initState();
    _inicjujMape();
    _uruchomKompas();
    _czyscStareDuchy();
    _pobierzInfoUzytkownika();

    _fadeTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (_pingedUsers.isNotEmpty && mounted) {
        _aktualizujZnacznikiUzytkownikow();
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _compassSub?.cancel();
    _usersSub?.cancel();
    _debounce?.cancel();
    _fadeTimer?.cancel();
    _mapController.dispose();
    if (_ghostUserId != null) {
      _trackerService.deleteUserLocation(_ghostUserId!);
    }
    super.dispose();
  }

  Future<void> _pobierzInfoUzytkownika() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      String? photoBase64;

      if (userDoc.exists && userDoc.data()!.containsKey('photoBase64')) {
        final rawBase64 = userDoc.data()!['photoBase64'] as String?;
        if (rawBase64 != null && rawBase64.isNotEmpty) {
          photoBase64 = 'data:image/jpeg;base64,$rawBase64';
        }
      }

      if (!mounted) return;
      setState(() {
        _currentUserDisplayName = userDoc.data()?['nickname'] ??
            userDoc.data()?['displayName'] ??
            user.displayName ??
            'You';
        _currentUserAvatarUrl = photoBase64;
      });
    }
  }

  Future<void> _czyscStareDuchy() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      final potentialGhostId = 'ghost_${currentUser.uid}';
      await _trackerService.deleteUserLocation(potentialGhostId);
    }
  }

  Future<void> _przelaczDebug() async {
    final newDebugState = !_isDebugMode;
    setState(() {
      _isDebugMode = newDebugState;
    });

    if (!newDebugState) {
      setState(() {
        _dummyUsers.clear();
        _aktualizujZnacznikiUzytkownikow();
      });
      if (_ghostUserId != null) {
        await _trackerService.deleteUserLocation(_ghostUserId!);
        _ghostUserId = null;
        if (!mounted) return;
        _pokazPowiadomienie(
            'Ghost signal removed. Returning to normal operations.');
      } else {
        _pokazPowiadomienie('Debug Mode Disabled!', isError: true);
      }
    } else {
      _pokazPowiadomienie('Debug Mode Enabled!');
    }
  }

  void _dodajManekiny() {
    if (!_isDebugMode) return;
    const distance = latlong.Distance();
    final newDummies = List.generate(5, (index) {
      final randomDistance = _random.nextDouble() * 14000 + 500;
      final randomBearing = _random.nextDouble() * 360;
      final point =
          distance.offset(_userLocation, randomDistance, randomBearing);
      return _UserData(
        uid: 'dummy_${_random.nextInt(99999)}',
        displayName: 'Dummy ${index + 1}',
        point: point,
        lastSeen: Timestamp.now(),
        isActive: true,
        avatarUrl: null,
      );
    });
    setState(() {
      _dummyUsers.addAll(newDummies);
      _aktualizujZnacznikiUzytkownikow();
    });
    _pokazPowiadomienie('${newDummies.length} dummy targets deployed, Admiral!');
  }

  Future<void> _udawajIZostawDucha() async {
    if (!_isDebugMode) return;

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      _pokazPowiadomienie('Cannot create ghost, no user logged in!',
          isError: true);
      return;
    }

    final realLocation = _lastKnownRealLocation ?? _userLocation;
    _ghostUserId = 'ghost_${currentUser.uid}';

    await _trackerService.updateUserLocation(
      uid: _ghostUserId,
      latitude: realLocation.latitude,
      longitude: realLocation.longitude,
      avatarUrl: _currentUserAvatarUrl,
      displayName: _currentUserDisplayName,
    );
    if (!mounted) return;
    _pokazPowiadomienie('Ghost signal deployed at previous coordinates!');

    const distance = latlong.Distance();
    final randomDistance = _random.nextDouble() * 14000 + 1000;
    final randomBearing = _random.nextDouble() * 360;
    final newLoc =
        distance.offset(realLocation, randomDistance, randomBearing);

    setState(() {
      _userLocation = newLoc;
    });
    _animujRuchMapy(newLoc, 14.0);
    _pokazPowiadomienie('Relocating to new coordinates! Full speed ahead!');
  }

  Future<void> _inicjujMape() async {
    setState(() => _isLoadingMap = true);
    try {
      await _ustalPozycje();
    } catch (e) {
      debugPrint('Error initializing map: $e');
    } finally {
      _lastPoiFetchLocation = _userLocation;
      await _pobierzWysypiska();
      if (mounted) setState(() => _isLoadingMap = false);
    }
  }

  Future<void> _ustalPozycje() async {
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      timeLimit: Duration(seconds: 10),
    );

    try {
      if (kIsWeb) {
        final pos = await Geolocator.getCurrentPosition(
            locationSettings: locationSettings);
        _userLocation = latlong.LatLng(pos.latitude, pos.longitude);
        _gpsAccuracy = pos.accuracy;
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (!mounted) return;

      if (permission == LocationPermission.deniedForever) {
        await _pokazDialogPozwolen();
        return;
      }

      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        final serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!mounted) return;
        if (!serviceEnabled) {
          await _pokazDialogLokalizacji();
        }

        final pos = await Geolocator.getCurrentPosition(
            locationSettings: locationSettings);
        _userLocation = latlong.LatLng(pos.latitude, pos.longitude);
        _gpsAccuracy = pos.accuracy;
      }
    } on TimeoutException {
      debugPrint(
          "Location request timed out. Trying to get last known position.");
      final lastPos = await Geolocator.getLastKnownPosition();
      if (lastPos != null) {
        _userLocation = latlong.LatLng(lastPos.latitude, lastPos.longitude);
        _gpsAccuracy = lastPos.accuracy;
      }
    } catch (e) {
      debugPrint("An error occurred while getting location: $e");
      final lastPos = await Geolocator.getLastKnownPosition();
      if (lastPos != null) {
        _userLocation = latlong.LatLng(lastPos.latitude, lastPos.longitude);
        _gpsAccuracy = lastPos.accuracy;
      }
    }
  }

  Future<void> _pobierzWysypiska() async {
    try {
      final double lat = _userLocation.latitude;
      final double lon = _userLocation.longitude;
      const double distanceInKm = 15.0;
      final double latRadius = distanceInKm / 111.1;
      final double lonRadius =
          distanceInKm / (111.32 * math.cos(lat * math.pi / 180));
      final String bbox =
          "${lat - latRadius},${lon - lonRadius},${lat + latRadius},${lon + lonRadius}";

      final String query = """[out:json];(
        node["amenity"~"waste_disposal|recycling"]($bbox);
        way["amenity"~"waste_disposal|recycling"]($bbox);
        relation["amenity"~"waste_disposal|recycling"]($bbox);
        node["landuse"="landfill"]($bbox);way["landuse"="landfill"]($bbox);
        relation["landuse"="landfill"]($bbox);
        node["shop"~"junk|scrap"]($bbox);way["shop"~"junk|scrap"]($bbox);
        relation["shop"~"junk|scrap"]($bbox);
        node["waste"="hazardous"]($bbox);way["waste"="hazardous"]($bbox);
        relation["waste"="hazardous"]($bbox);
        );out center;""";

      final response = await http.post(
        Uri.parse('https://overpass-api.de/api/interpreter'),
        body: {'data': query},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<_PoiData> pois = (data['elements'] as List).map((element) {
          double? lat, lon;
          if (element['type'] == 'node') {
            lat = element['lat'];
            lon = element['lon'];
          } else if (element.containsKey('center')) {
            lat = element['center']['lat'];
            lon = element['center']['lon'];
          }
          if (lat != null && lon != null) {
            return _PoiData(
              point: latlong.LatLng(lat, lon),
              tags: Map<String, dynamic>.from(element['tags'] ?? {}),
            );
          }
          return null;
        }).whereType<_PoiData>().toList();

        if (mounted) {
          setState(() {
            _poiData = pois;
            _budujZnacznikiPoi();
          });
        }
      } else {
        debugPrint('Overpass responded ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching disposal centers: $e');
    }
  }

  Future<void> _utworzTrase(latlong.LatLng destination) async {
    setState(() {
      _isRouting = true;
      _routePoints.clear();
      _routeDistance = null;
      _routeDuration = null;
    });

    const String profile = 'driving';
    final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/$profile/'
        '${_userLocation.longitude},${_userLocation.latitude};'
        '${destination.longitude},${destination.latitude}'
        '?overview=full&geometries=geojson');

    try {
      final response = await http.get(url);
      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['routes'] == null || (data['routes'] as List).isEmpty) {
          _pokazPowiadomienie('No route found.', isError: true);
          return;
        }
        final route = data['routes'][0];
        final geometry = route['geometry']['coordinates'] as List<dynamic>;
        final distance = (route['distance'] as num).toDouble();
        final duration = (route['duration'] as num).toDouble();

        if (mounted) {
          setState(() {
            _routePoints = geometry
                .map((c) => latlong.LatLng(
                    (c[1] as num).toDouble(), (c[0] as num).toDouble()))
                .toList();
            _routeDistance = distance;
            _routeDuration = duration;
          });
          _mapController.fitCamera(
            CameraFit.bounds(
              bounds: LatLngBounds.fromPoints([_userLocation, destination]),
              padding: const EdgeInsets.all(80),
            ),
          );
        }
      } else {
        _pokazPowiadomienie('Failed to create route.', isError: true);
      }
    } catch (e) {
      debugPrint('Route creation error: $e');
      _pokazPowiadomienie('Error creating route.', isError: true);
    } finally {
      if (mounted) setState(() => _isRouting = false);
    }
  }

  void _wyczyscTrase() {
    setState(() {
      _routePoints.clear();
      _routeDistance = null;
      _routeDuration = null;
    });
  }

  void _uruchomStrumienGps() {
    _positionSub?.cancel();
    const settings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 3,
    );
    _positionSub = Geolocator.getPositionStream(locationSettings: settings)
        .listen((pos) async {
      final now = DateTime.now();
      if (now.difference(_lastPositionUpdate).inMilliseconds < 300) return;
      _lastPositionUpdate = now;

      final newLoc = latlong.LatLng(pos.latitude, pos.longitude);
      if (mounted) {
        if (_ghostUserId == null) {
          setState(() {
            _userLocation = newLoc;
            _lastKnownRealLocation = newLoc;
          });
        }
        setState(() {
          _gpsAccuracy = pos.accuracy;
        });

        _trackerService.updateUserLocation(
          latitude: newLoc.latitude,
          longitude: newLoc.longitude,
          displayName: _currentUserDisplayName,
          avatarUrl: _currentUserAvatarUrl,
        );

        if (_followUser) {
          _animujRuchMapy(newLoc, _mapController.camera.zoom);
        }

        if (_lastPoiFetchLocation != null) {
          final distance = Geolocator.distanceBetween(
            _lastPoiFetchLocation!.latitude,
            _lastPoiFetchLocation!.longitude,
            newLoc.latitude,
            newLoc.longitude,
          );
          if (distance > 1500) {
            _lastPoiFetchLocation = newLoc;
            await _pobierzWysypiska();
          }
        }
      }
    }, onError: (e) {
      debugPrint('Position stream error: $e');
    });
  }

  void _strumienUzytkownikow() {
    _usersSub?.cancel();
    _usersSub =
        _trackerService.getUsersLocationStream().listen((snapshot) async {
      if (!mounted) return;
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      final thirtyMinutesAgo =
          DateTime.now().subtract(const Duration(minutes: 30));

      final userFutures = snapshot.docs
          .where((doc) => doc.id != currentUserId)
          .map((doc) async {
        final data = doc.data();
        final location = data['location'] as GeoPoint?;
        final lastSeen = data['lastSeen'] as Timestamp?;

        if (location == null || lastSeen == null) return null;

        final distance = Geolocator.distanceBetween(
          _userLocation.latitude,
          _userLocation.longitude,
          location.latitude,
          location.longitude,
        );
        if (distance > 15000) return null;

        String? finalAvatarUrl = data['avatarUrl'];
        String finalDisplayName = data['displayName'] ?? 'Eco User';

        
        bool needsProfileFetch = finalDisplayName == 'Eco User' ||
            finalAvatarUrl == null ||
            !finalAvatarUrl.startsWith('data:image');

        if (needsProfileFetch) {
          if (_userProfileCache.containsKey(doc.id)) {
            final profileData = _userProfileCache[doc.id]!;
            finalDisplayName = profileData['nickname'] ??
                profileData['displayName'] ??
                'Eco User';
            if (profileData.containsKey('photoBase64')) {
              final rawBase64 = profileData['photoBase64'] as String?;
              if (rawBase64 != null && rawBase64.isNotEmpty) {
                finalAvatarUrl = 'data:image/jpeg;base64,$rawBase64';
              }
            }
          } else {
            try {
              final userProfileDoc = await FirebaseFirestore.instance
                  .collection('users')
                  .doc(doc.id)
                  .get();

              if (userProfileDoc.exists) {
                final profileData = userProfileDoc.data()!;
                _userProfileCache[doc.id] = profileData; 

                finalDisplayName = profileData['nickname'] ??
                    profileData['displayName'] ??
                    'Eco User';

                if (profileData.containsKey('photoBase64')) {
                  final rawBase64 = profileData['photoBase64'] as String?;
                  if (rawBase64 != null && rawBase64.isNotEmpty) {
                    finalAvatarUrl = 'data:image/jpeg;base64,$rawBase64';
                  }
                }
              }
            } catch (e) {
              debugPrint('Could not fetch user profile for ${doc.id}: $e');
            }
          }
        }

        return _UserData(
          uid: doc.id,
          displayName: finalDisplayName,
          point: latlong.LatLng(location.latitude, location.longitude),
          lastSeen: lastSeen,
          avatarUrl: finalAvatarUrl,
          isActive: lastSeen.toDate().isAfter(thirtyMinutesAgo),
        );
      });

      final users =
          (await Future.wait(userFutures)).whereType<_UserData>().toList();

      if (mounted) {
        setState(() {
          _nearbyUsers = users;
          _aktualizujZnacznikiUzytkownikow();
        });
      }
    });
  }

  void _uruchomKompas() {
    if (kIsWeb) return;
    _compassSub?.cancel();
    FlutterCompass.events?.listen((event) {
      final newHeading = event.heading ?? 0.0;
      final now = DateTime.now();
      if (now.difference(_lastHeadingUpdate).inMilliseconds < 120) return;
      _lastHeadingUpdate = now;

      const alpha = 0.4;
      final smoothedHeading = alpha * newHeading + (1.0 - alpha) * _heading;

      if ((smoothedHeading - _heading).abs() < 1.0) return;
      if (mounted) {
        setState(() => _heading = smoothedHeading);
      }
    }, onError: (e) {
      debugPrint('Compass stream error: $e');
    });
  }

  Future<void> _pingujRadar() async {
    if (_isPinging) return;

    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final hasConsented =
        prefs.getBool('hasConsentedToLocationSharing') ?? false;

    if (!hasConsented) {
      final consentGiven = await _pokazZgodePrywatnosci();
      if (!mounted) return;
      if (consentGiven == null || !consentGiven) {
        return;
      }
    }

    await _trackerService.updateUserLocation(
      latitude: _userLocation.latitude,
      longitude: _userLocation.longitude,
      displayName: _currentUserDisplayName,
      avatarUrl: _currentUserAvatarUrl,
    );

    if (!mounted) return;
    setState(() => _followUser = true);

    const distance = latlong.Distance();
    const fifteenKm = 15000.0;
    final northEast = distance.offset(_userLocation, fifteenKm, 45);
    final southWest = distance.offset(_userLocation, fifteenKm, 225);

    final bounds = LatLngBounds(
      latlong.LatLng(northEast.latitude, northEast.longitude),
      latlong.LatLng(southWest.latitude, southWest.longitude),
    );

    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.all(80.0),
      ),
    );

    setState(() {
      _isPinging = true;
    });
  }

  void _animujRuchMapy(latlong.LatLng destLocation, double destZoom) {
    final controller = AnimationController(
        duration: const Duration(milliseconds: 500), vsync: this);
    final animation =
        CurvedAnimation(parent: controller, curve: Curves.fastOutSlowIn);

    final latTween = Tween<double>(
        begin: _mapController.camera.center.latitude,
        end: destLocation.latitude);
    final lngTween = Tween<double>(
        begin: _mapController.camera.center.longitude,
        end: destLocation.longitude);
    final zoomTween =
        Tween<double>(begin: _mapController.camera.zoom, end: destZoom);

    controller.addListener(() {
      _mapController.move(
        latlong.LatLng(
            latTween.evaluate(animation), lngTween.evaluate(animation)),
        zoomTween.evaluate(animation),
      );
    });

    animation.addStatusListener((status) {
      if (status == AnimationStatus.completed ||
          status == AnimationStatus.dismissed) {
        controller.dispose();
      }
    });

    controller.forward();
  }

  void _animujObrotMapy(double destRotation) {
    final controller = AnimationController(
        duration: const Duration(milliseconds: 500), vsync: this);
    final animation =
        CurvedAnimation(parent: controller, curve: Curves.fastOutSlowIn);

    final rotationTween =
        Tween<double>(begin: _mapController.camera.rotation, end: destRotation);

    controller.addListener(() {
      _mapController.rotate(rotationTween.evaluate(animation));
    });

    animation.addStatusListener((status) {
      if (status == AnimationStatus.completed ||
          status == AnimationStatus.dismissed) {
        controller.dispose();
      }
    });

    controller.forward();
  }

  Future<bool?> _pokazZgodePrywatnosci() async {
    bool dontAskAgain = false;

    final currentContext = context;
    if (!currentContext.mounted) return null;

    return showDialog<bool>(
      context: currentContext,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppTheme.cardBg,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              title: Text('Location Sharing Notice', style: AppTheme.headline2),
              content: SingleChildScrollView(
                child: ListBody(
                  children: <Widget>[
                    Text(
                      'To find other users, pressing the "Ping" button will share your approximate location and avatar with other nearby users for up to 30 minutes.',
                      style: AppTheme.bodyText,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'This feature is subject to the Data Privacy Act of the Philippines (RA 10173). By proceeding, you consent to this temporary sharing of data.',
                      style: AppTheme.bodyText,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Disclaimer: This is for informational purposes and is not legal advice. Please consult a legal professional for details on privacy laws.',
                      style: AppTheme.subtitle
                          .copyWith(fontStyle: FontStyle.italic),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Checkbox(
                          value: dontAskAgain,
                          activeColor: AppTheme.primaryRed,
                          onChanged: (bool? value) {
                            setDialogState(() {
                              dontAskAgain = value ?? false;
                            });
                          },
                        ),
                        Text('Don\'t ask me again', style: AppTheme.bodyText),
                      ],
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  style: TextButton.styleFrom(
                      foregroundColor: AppTheme.lightText),
                  child: const Text('Cancel'),
                  onPressed: () {
                    Navigator.of(context).pop(false);
                  },
                ),
                TextButton(
                  style: TextButton.styleFrom(
                      foregroundColor: AppTheme.primaryRed),
                  child: const Text('Agree & Ping'),
                  onPressed: () async {
                    if (dontAskAgain) {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setBool(
                          'hasConsentedToLocationSharing', true);
                    }

                    if (context.mounted) {
                      Navigator.of(context).pop(true);
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _odbierzPingi(Map<String, PingedUserData> updatedPings) {
    if (!mounted) return;
    setState(() {
      _pingedUsers.clear();
      _pingedUsers.addAll(updatedPings);
    });
  }

  void _zakonczPing() {
    if (!mounted) return;
    setState(() {
      _isPinging = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      appBar: _budujAppBar(),
      bottomNavigationBar: _budujDolnyPasek(),
      floatingActionButton: _budujPrzyciskGlowny(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      body: SafeArea(
        child: Stack(
          children: [
            _isLoadingMap ? _wskaznikLadowania() : _budujMape(),
            RadarSweep(
              isPinging: _isPinging,
              mapController: _mapController,
              userLocation: _userLocation,
              mapRotation: _mapRotation,
              nearbyUsers: [..._nearbyUsers, ..._dummyUsers]
                  .map((user) =>
                      RadarUserData(uid: user.uid, point: user.point))
                  .toList(),
              onPingedUsersUpdate: _odbierzPingi,
              onPingCompleted: _zakonczPing,
            ),
            _budujInfoTrasy(),
            _budujNakladkeUI(),
            if (_isDebugMode) _budujPanelDebug(),
            if (_isRouting) _nakladkaTrasowania(),
          ],
        ),
      ),
    );
  }

  AppBar _budujAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: AppTheme.cardBg,
      systemOverlayStyle: SystemUiOverlayStyle.dark,
      titleSpacing: 0,
      title: Row(children: [
        Container(
          margin: const EdgeInsets.only(left: 16),
          padding: const EdgeInsets.all(8),
          decoration: const BoxDecoration(
              color: AppTheme.primaryRed, shape: BoxShape.circle),
          child: const Icon(LucideIcons.map, color: Colors.white, size: 22),
        ),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Disposal Map', style: AppTheme.headline2),
          Text('Locate, Navigate, Waste Abate.', style: AppTheme.subtitle),
        ]),
      ]),
    );
  }

  Widget _budujMape() {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _userLocation,
        initialZoom: 13,
        minZoom: _minZoomLevel,
        maxZoom: _maxZoomLevel,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all,
        ),
        onTap: (_, _) {
          setState(() => _followUser = false);
        },
        onMapReady: () {
          _uruchomStrumienGps();
          _strumienUzytkownikow();
          if (mounted) {
            setState(() {
              _isAtMaxZoom = _mapController.camera.zoom >= _maxZoomLevel;
            });
          }
        },
        onMapEvent: (event) {
          if (_debounce?.isActive ?? false) _debounce!.cancel();
          _debounce = Timer(const Duration(milliseconds: 150), () {
            if (!mounted) return;

            if (event.camera.rotation != _mapRotation) {
              setState(() => _mapRotation = event.camera.rotation);
            }
            final atMax = event.camera.zoom >= _maxZoomLevel;
            if (atMax != _isAtMaxZoom) {
              setState(() => _isAtMaxZoom = atMax);
            }
            if (event.source != MapEventSource.mapController) {
              setState(() => _followUser = false);
            }
          });
        },
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.ecolpu.wasteapp',
        ),
        if (_routePoints.isNotEmpty)
          PolylineLayer(
            polylines: [
              Polyline(
                points: _routePoints,
                strokeWidth: 5,
                color: AppTheme.accentBlue,
              ),
            ],
          ),
        if (_isAtMaxZoom) CircleLayer(circles: [_koloDokladnosciGps()]),
        MarkerClusterLayerWidget(
          options: _opcjeKlastra(),
        ),
        MarkerLayer(markers: _userMarkers),
        if (!kIsWeb) MarkerLayer(markers: [_budujZnacznikUzytkownika()]),
        if (kIsWeb) MarkerLayer(markers: [_budujZnacznikWeb()]),
      ],
    );
  }

  Widget _budujDolnyPasek() {
    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      notchMargin: 8,
      color: AppTheme.cardBg,
      elevation: 10,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      child:
          Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
        _elementPaskaNaw(LucideIcons.house, 'Home',
            () => Navigator.pushReplacementNamed(context, '/home')),
        _elementPaskaNaw(LucideIcons.scanLine, 'Classifier',
            () => Navigator.pushReplacementNamed(context, '/scanner')),
        const SizedBox(width: 48),
        _elementPaskaNaw(LucideIcons.trendingUp, 'Tracker',
            () => Navigator.pushReplacementNamed(context, '/trackImpact')),
        _elementPaskaNaw(LucideIcons.gamepad2, 'Games', () {}),
      ]),
    );
  }

  Widget _budujPrzyciskGlowny() {
    return FloatingActionButton(
      heroTag: "main_fab",
      onPressed: _pingujRadar,
      backgroundColor: AppTheme.primaryRed,
      tooltip: 'Ping Radar',
      shape: const CircleBorder(),
      child: const Icon(LucideIcons.radar, color: Colors.white),
    );
  }

  Widget _budujNakladkeUI() {
    return Positioned(
      top: 20,
      right: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _budujLegende(),
          const SizedBox(height: 8),
          if (!_isLegendExpanded) _budujKompas(),
        ],
      ),
    );
  }

  Widget _budujPanelDebug() {
    return Positioned(
      bottom: 80,
      right: 16,
      child: Card(
        color: AppTheme.cardBg.withValues(alpha: 0.9),
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: [
              Text('Debug Menu',
                  style:
                      AppTheme.bodyText.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              ElevatedButton(
                onPressed: _dodajManekiny,
                child: const Text('Add Targets'),
              ),
              ElevatedButton(
                onPressed: _udawajIZostawDucha,
                child: const Text('Spoof & Ghost'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _budujLegende() {
    return Card(
      elevation: 4,
      color: AppTheme.cardBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: () =>
                  setState(() => _isLegendExpanded = !_isLegendExpanded),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Legend',
                      style: AppTheme.bodyText.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.darkText)),
                  const SizedBox(width: 4),
                  Icon(
                    _isLegendExpanded
                        ? LucideIcons.chevronUp
                        : LucideIcons.chevronDown,
                    size: 16,
                    color: AppTheme.lightText,
                  ),
                ],
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              child: Visibility(
                visible: _isLegendExpanded,
                child: Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _elementLegendy(LucideIcons.recycle, 'Recycling',
                          AppTheme.organicColor),
                      _elementLegendy(LucideIcons.trash2,
                          'Disposal/Landfill', AppTheme.metalColor),
                      _elementLegendy(
                          LucideIcons.store, 'Junk Shop', AppTheme.paperColor),
                      _elementLegendy(LucideIcons.biohazard, 'Hazardous',
                          AppTheme.statusError),
                      const Divider(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Debug Mode', style: AppTheme.bodyText),
                          Switch(
                            value: _isDebugMode,
                            onChanged: (value) => _przelaczDebug(),
                            activeThumbColor: AppTheme.primaryRed,
                          ),
                        ],
                      ),
                      const Divider(height: 16),
                      _budujKompas(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _budujKompas() {
    return AnimatedOpacity(
      opacity: _mapRotation.abs() > 0.1 ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 300),
      child: Visibility(
        visible: _mapRotation.abs() > 0.1,
        child: Card(
          elevation: 4,
          shape: const CircleBorder(),
          child: InkWell(
            onTap: () => _animujObrotMapy(0),
            customBorder: const CircleBorder(),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                  color: AppTheme.cardBg, shape: BoxShape.circle),
              child: Transform.rotate(
                angle: -_mapRotation * (math.pi / 180),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CustomPaint(painter: _CompassPainter()),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _budujInfoTrasy() {
    if (_routeDistance == null || _routeDuration == null) {
      return const SizedBox.shrink();
    }
    final km = (_routeDistance! / 1000).toStringAsFixed(2);
    final mins = (_routeDuration! / 60).toStringAsFixed(0);

    return Positioned(
      top: 20,
      left: 16,
      child: Card(
        elevation: 4,
        color: AppTheme.cardBg,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(LucideIcons.car,
                  color: AppTheme.accentBlue, size: 20),
              const SizedBox(width: 6),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("$km km",
                      style: AppTheme.bodyText.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: AppTheme.darkText)),
                  Text("$mins min",
                      style: AppTheme.bodyText.copyWith(
                          fontSize: 10, color: AppTheme.lightText)),
                ],
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: _wyczyscTrase,
                child: const Icon(LucideIcons.x,
                    color: AppTheme.lightText, size: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _wskaznikLadowania() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: AppTheme.primaryRed),
          SizedBox(height: 16),
          Text('Charting the area...',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
          Text('Please wait a moment!', style: TextStyle(fontSize: 14)),
        ],
      ),
    );
  }

  Widget _nakladkaTrasowania() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.3),
        child: const Center(
          child: CircularProgressIndicator(color: AppTheme.primaryRed),
        ),
      ),
    );
  }

  Widget _elementLegendy(IconData icon, String label, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 4),
          Text(label, style: AppTheme.bodyText.copyWith(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _elementPaskaNaw(
      IconData icon, String tooltip, VoidCallback onPressed) {
    return IconButton(
      icon: Icon(icon, color: AppTheme.lightText, size: 26),
      tooltip: tooltip,
      onPressed: onPressed,
    );
  }

  void _budujZnacznikiPoi() {
    _poiMarkers = _poiData.map((poi) {
      final key =
          ValueKey('poi_${poi.point.latitude}_${poi.point.longitude}');
      return Marker(
        key: key,
        point: poi.point,
        width: 54,
        height: 64,
        child: GestureDetector(
          onTap: () => _utworzTrase(poi.point),
          child: _budujZnacznikWysypiska(poi.tags),
        ),
      );
    }).toList();
  }

  MarkerClusterLayerOptions _opcjeKlastra() {
    return MarkerClusterLayerOptions(
      maxClusterRadius: 80,
      size: const Size(45, 45),
      markers: _poiMarkers,
      builder: (context, markers) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              AppTheme.primaryRed,
              AppTheme.primaryRed.withValues(alpha: 0.7),
            ]),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3), blurRadius: 5)
            ],
          ),
          child: Center(
            child: Text(markers.length.toString(),
                style: AppTheme.button.copyWith(fontSize: 16)),
          ),
        );
      },
    );
  }

  Widget _budujZnacznikWysypiska(Map<String, dynamic> tags) {
    final String name =
        tags['name'] ?? tags['shop'] ?? tags['amenity'] ?? 'Disposal site';
    final IconData iconData = _pobierzIkoneZnacznika(tags);
    final Color baseColor = _pobierzKolorIkony(iconData);
    return Tooltip(
      message: name,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Transform.rotate(
            angle: -_mapRotation * (math.pi / 180),
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: baseColor,
                shape: BoxShape.circle,
                gradient: LinearGradient(
                    colors: [baseColor, baseColor.withValues(alpha: 0.9)]),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 6,
                      offset: const Offset(0, 3))
                ],
              ),
              child: Center(
                  child: Icon(iconData, color: Colors.white, size: 20)),
            ),
          ),
          CustomPaint(
              size: const Size(14, 8),
              painter: _MarkerPointerPainter(baseColor)),
        ],
      ),
    );
  }

  Widget _budujAwatar(String? avatarUrl, {double size = 40}) {
    Widget child;
    if (avatarUrl == null || avatarUrl.isEmpty) {
      child = Icon(LucideIcons.user, color: Colors.white, size: size / 2);
    } else if (avatarUrl.startsWith('data:image')) {
      try {
        final UriData? data = Uri.tryParse(avatarUrl)?.data;
        if (data != null && data.isBase64) {
          child = Image.memory(
            data.contentAsBytes(),
            width: size,
            height: size,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.high,
            gaplessPlayback: true,
            errorBuilder: (_, _, _) =>
                Icon(LucideIcons.user, color: Colors.white, size: size / 2),
          );
        } else {
          child =
              Icon(LucideIcons.user, color: Colors.white, size: size / 2);
        }
      } catch (e) {
        child = Icon(LucideIcons.user, color: Colors.white, size: size / 2);
      }
    } else {
      child = Image.network(
        avatarUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.high,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) =>
            Icon(LucideIcons.user, color: Colors.white, size: size / 2),
      );
    }

    return ClipOval(
      child: Container(
        width: size,
        height: size,
        color: AppTheme.darkText.withValues(alpha: 0.5),
        child: child,
      ),
    );
  }

  Marker _budujZnacznikUzytkownika() {
    return Marker(
      point: _userLocation,
      width: 100,
      height: 100,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Transform.rotate(
            angle: (_heading - _mapRotation) * (math.pi / 180),
            child: CustomPaint(
              size: const Size(100, 100),
              painter: _VisionConePainter(),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _currentUserDisplayName,
                  style: const TextStyle(color: Colors.white, fontSize: 10),
                ),
              ),
              const SizedBox(height: 4),
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: _budujAwatar(_currentUserAvatarUrl),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _aktualizujZnacznikiUzytkownikow() {
    final allUsers = [..._nearbyUsers, ..._dummyUsers];
    final now = DateTime.now();

    _pingedUsers.removeWhere((key, value) {
      final elapsed = now.difference(value.pingTime).inMilliseconds;
      return elapsed > value.totalDurationMs;
    });

    _userMarkers = allUsers.map((user) {
      final pingData = _pingedUsers[user.uid];
      if (pingData == null) return null;

      final elapsedMs = now.difference(pingData.pingTime).inMilliseconds;
      double opacity = 1.0;

      const solidDurationMs = 30000;
      if (elapsedMs > solidDurationMs) {
        final fadeDuration = pingData.totalDurationMs - solidDurationMs;
        if (fadeDuration > 0) {
          final fadeProgress =
              (elapsedMs - solidDurationMs) / fadeDuration;
          opacity = 1.0 - fadeProgress;
        } else {
          opacity = 0.0;
        }
      }
      opacity = opacity.clamp(0.0, 1.0);
      if (opacity <= 0.0) return null;

      return Marker(
        key: ValueKey(user.uid),
        point: user.point,
        width: 100,
        height: 70,
        child: Opacity(
          opacity: opacity,
          child: GestureDetector(
            onLongPressStart: (_) =>
                setState(() => _highlightedUserId = user.uid),
            onLongPressEnd: (_) =>
                setState(() => _highlightedUserId = null),
            onTapUp: (_) => setState(() => _highlightedUserId = null),
            child: Column(
              children: [
                AnimatedOpacity(
                  opacity: _highlightedUserId == user.uid ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      user.displayName,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 10),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: user.isActive
                        ? Colors.green.withValues(alpha: 0.8)
                        : Colors.lightGreen.withValues(alpha: 0.7),
                    border: Border.all(color: Colors.white, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        blurRadius: 8,
                        color: Colors.green.withValues(alpha: 0.7),
                      )
                    ],
                  ),
                  child: _budujAwatar(user.avatarUrl),
                ),
              ],
            ),
          ),
        ),
      );
    }).whereType<Marker>().toList();
  }

  Marker _budujZnacznikWeb() {
    return Marker(
      point: _userLocation,
      width: 100,
      height: 70,
      child: Column(
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              _currentUserDisplayName,
              style: const TextStyle(color: Colors.white, fontSize: 10),
            ),
          ),
          const SizedBox(height: 4),
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.accentBlue,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                    blurRadius: 5, color: Colors.black.withValues(alpha: 0.3))
              ],
            ),
            child: _budujAwatar(_currentUserAvatarUrl),
          ),
        ],
      ),
    );
  }

  CircleMarker _koloDokladnosciGps() {
    return CircleMarker(
      point: _userLocation,
      radius: _gpsAccuracy,
      useRadiusInMeter: true,
      color: AppTheme.accentBlue.withValues(alpha: 0.1),
      borderColor: AppTheme.accentBlue.withValues(alpha: 0.5),
      borderStrokeWidth: 1.5,
    );
  }

  IconData _pobierzIkoneZnacznika(Map<String, dynamic> tags) {
    if (tags['waste'] == 'hazardous') return LucideIcons.biohazard;
    if (tags['amenity'] == 'recycling' || (tags['recycling'] != null)) {
      return LucideIcons.recycle;
    }
    if (tags['landuse'] == 'landfill') return LucideIcons.trash2;
    if (tags['shop'] != null &&
        (tags['shop'] == 'junk' || tags['shop'] == 'scrap')) {
      return LucideIcons.store;
    }
    final amen = tags['amenity']?.toString().toLowerCase() ?? '';
    if (amen.contains('waste') || amen.contains('disposal')) {
      return LucideIcons.trash2;
    }
    return LucideIcons.mapPin;
  }

  Color _pobierzKolorIkony(IconData icon) {
    if (icon == LucideIcons.recycle) return AppTheme.organicColor;
    if (icon == LucideIcons.trash2) return AppTheme.metalColor;
    if (icon == LucideIcons.store) return AppTheme.paperColor;
    if (icon == LucideIcons.biohazard) return AppTheme.statusError;
    return AppTheme.primaryRed;
  }

  void _pokazPowiadomienie(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            isError ? AppTheme.statusError : AppTheme.accentBlue,
      ),
    );
  }

  Future<void> _pokazDialogPozwolen() async {
    final currentContext = context;
    if (!currentContext.mounted) return;
    return showDialog<void>(
      context: currentContext,
      builder: (context) => AlertDialog(
        title: const Text('Location permission required'),
        content: const Text(
            'This app needs location access to show your position. Please enable it in app settings.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await Geolocator.openAppSettings();
              },
              child: const Text('Open settings')),
        ],
      ),
    );
  }

  Future<void> _pokazDialogLokalizacji() async {
    final currentContext = context;
    if (!currentContext.mounted) return;
    final open = await showDialog<bool>(
      context: currentContext,
      builder: (c) => AlertDialog(
        title: const Text('Enable location services'),
        content: const Text(
            'Location services are off. Would you like to open location settings?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(c).pop(false),
              child: const Text('No')),
          TextButton(
              onPressed: () => Navigator.of(c).pop(true),
              child: const Text('Open')),
        ],
      ),
    );

    if (open == true) await Geolocator.openLocationSettings();
  }
}

class _MarkerPointerPainter extends CustomPainter {
  final Color color;
  _MarkerPointerPainter(this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final path = ui.Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _VisionConePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final coneLength = size.height * 0.6;
    const angleSpread = math.pi / 5.5;
    const baseAngle = -math.pi / 2;
    final p1 = Offset(
        center.dx + coneLength * math.cos(baseAngle - angleSpread),
        center.dy + coneLength * math.sin(baseAngle - angleSpread));
    final p2 = Offset(
        center.dx + coneLength * math.cos(baseAngle + angleSpread),
        center.dy + coneLength * math.sin(baseAngle + angleSpread));
    const sideCurveFactor = 0.4;
    final c1 = Offset(
        center.dx +
            (coneLength * 0.5) *
                math.cos(
                    baseAngle - angleSpread * (1 + sideCurveFactor)),
        center.dy +
            (coneLength * 0.5) *
                math.sin(
                    baseAngle - angleSpread * (1 + sideCurveFactor)));
    final c2 = Offset(
        center.dx +
            (coneLength * 0.5) *
                math.cos(
                    baseAngle + angleSpread * (1 + sideCurveFactor)),
        center.dy +
            (coneLength * 0.5) *
                math.sin(
                    baseAngle + angleSpread * (1 + sideCurveFactor)));
    const endCurveFactor = 0.4;
    final midPoint = Offset((p1.dx + p2.dx) / 2, (p1.dy + p2.dy) / 2);
    final midVector = midPoint - center;
    final endEdgeDistance =
        math.sqrt(math.pow(p2.dx - p1.dx, 2) + math.pow(p2.dy - p1.dy, 2));
    final endControlPoint = midPoint +
        (midVector / midVector.distance) *
            (endEdgeDistance * endCurveFactor);
    final conePath = ui.Path()
      ..moveTo(center.dx, center.dy)
      ..quadraticBezierTo(c1.dx, c1.dy, p1.dx, p1.dy)
      ..quadraticBezierTo(
          endControlPoint.dx, endControlPoint.dy, p2.dx, p2.dy)
      ..quadraticBezierTo(c2.dx, c2.dy, center.dx, center.dy)
      ..close();
    final ambientGlowPaint = Paint()
      ..color = AppTheme.accentBlue.withValues(alpha: 0.1)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18.0);
    canvas.drawPath(conePath, ambientGlowPaint);
    final focusedGlowPaint = Paint()
      ..color = AppTheme.accentBlue.withValues(alpha: 0.15)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12.0);
    canvas.drawPath(conePath, focusedGlowPaint);
    final hotspotPaint = Paint()
      ..shader = ui.Gradient.radial(
        center,
        coneLength * 0.75,
        [
          AppTheme.accentBlue.withValues(alpha: 0.2),
          AppTheme.accentBlue.withValues(alpha: 0.0),
        ],
        [0.0, 1.0],
      );
    canvas.drawPath(conePath, hotspotPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CompassPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double width = size.width;
    final double height = size.height;
    final center = Offset(width / 2, height / 2);
    final topPoint = Offset(center.dx, 0);
    final bottomPoint = Offset(center.dx, height);
    final leftPoint = Offset(width * 0.25, center.dy);
    final rightPoint = Offset(width * 0.75, center.dy);
    final northPaint = Paint()
      ..color = AppTheme.primaryRed
      ..style = PaintingStyle.fill;
    final northPath = ui.Path()
      ..moveTo(leftPoint.dx, leftPoint.dy)
      ..lineTo(topPoint.dx, topPoint.dy)
      ..lineTo(rightPoint.dx, rightPoint.dy)
      ..close();
    canvas.drawPath(northPath, northPaint);
    final southPaint = Paint()
      ..color = Colors.grey[600]!
      ..style = PaintingStyle.fill;
    final southPath = ui.Path()
      ..moveTo(leftPoint.dx, leftPoint.dy)
      ..lineTo(bottomPoint.dx, bottomPoint.dy)
      ..lineTo(rightPoint.dx, rightPoint.dy)
      ..close();
    canvas.drawPath(southPath, southPaint);
    final textPainter = TextPainter(
      text: const TextSpan(
        text: 'N',
        style: TextStyle(
          color: Colors.white,
          fontSize: 8,
          fontWeight: FontWeight.bold,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    final textOffset = Offset(
      center.dx - (textPainter.width / 2),
      center.dy / 2.5 - (textPainter.height / 2),
    );
    textPainter.paint(canvas, textOffset);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}