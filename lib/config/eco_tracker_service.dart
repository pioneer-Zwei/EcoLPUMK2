import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'eco_waste_detection.dart';

class StatTrackerService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> updateUserLocation({
    required double latitude,
    required double longitude,
    String? uid,
    String? avatarUrl,
    String? displayName,
  }) async {
    final currentUser = FirebaseAuth.instance.currentUser;

    final targetUid = uid ?? currentUser?.uid;
    if (targetUid == null) return;

    final userDocRef = _db.collection('users').doc(targetUid);

    final dataToSet = {
      'location': GeoPoint(latitude, longitude),
      'lastSeen': Timestamp.now(),
      if (avatarUrl != null) 'avatarUrl': avatarUrl,
      if (displayName != null) 'displayName': displayName,
    };

    await userDocRef.set(dataToSet, SetOptions(merge: true));
  }

  Future<void> deleteUserLocation(String uid) async {
    if (uid.isEmpty) return;
    try {
      await _db.collection('users').doc(uid).delete();
    } catch (e) {
      // BAU
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getUsersLocationStream() {
    final twentyFourHoursAgo =
        DateTime.now().subtract(const Duration(hours: 24));

    return _db
        .collection('users')
        .where('lastSeen', isGreaterThan: Timestamp.fromDate(twentyFourHoursAgo))
        .snapshots();
  }

  Future<void> recordScan({
    required List<WasteDetection> detections,
    Map<String, String>? userActions,
  }) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    final isSignedIn = currentUser != null && !currentUser.isAnonymous;
    final ts = DateTime.now();
    final counts = _liczOdpady(detections);
    final impact = _szacujWplyw(Map<String, int>.from(counts['byCategory'] ?? {}));
    final actions = <String, String>{};
    for (final d in detections) {
      actions[d.name] = userActions?[d.name] ?? 'other';
    }

    final userData = await _daneUzytkownika(isSignedIn, currentUser);

    final scanPayload = {
      'timestamp': Timestamp.fromDate(ts),
      'totalItems': detections.length,
      'wasteCount': counts['waste'],
      'notWasteCount': counts['notWaste'],
      'byCategory': counts['byCategory'],
      'impact': impact,
      'detections': detections.map(_mapujDetekcje).toList(),
      'userActions': actions,
      'userId': userData['id'],
      'userName': userData['name'],
      'userAvatarUrl': userData['avatarUrl'],
    };

    final scanCollectionRef = isSignedIn
        ? _db.collection('users').doc(userData['id']).collection('scans')
        : _db.collection('scans');

    await scanCollectionRef.doc().set(scanPayload);
    await _aktualizujGlobalne(counts, detections.length, ts, impact);

    if (isSignedIn) {
      await _aktualizujUzytkownika(
          userData['id'], userData, counts, detections.length, ts, impact);
    }
  }

  Future<Map<String, dynamic>> _daneUzytkownika(
    bool isSignedIn,
    User? currentUser,
  ) async {
    if (!isSignedIn || currentUser == null) {
      return {
        'id': 'anonymous',
        'name': 'Anonymous User',
        'avatarUrl': null,
      };
    }

    String userId = currentUser.uid;
    String userName = 'Eco Pirate';
    String? userAvatarUrl;

    try {
      final userSnap = await _db.collection('users').doc(userId).get();
      if (userSnap.exists) {
        final ud = userSnap.data();
        userName = ud?['displayName'] ?? currentUser.displayName ?? 'Eco Pirate';
        userAvatarUrl = ud?['avatarUrl'] ?? currentUser.photoURL;
      } else {
        userName = currentUser.displayName ?? 'Eco Pirate';
        userAvatarUrl = currentUser.photoURL;
      }
    } catch (_) {
      userName = currentUser.displayName ?? 'Eco Pirate';
      userAvatarUrl = currentUser.photoURL;
    }

    return {
      'id': userId,
      'name': userName,
      'avatarUrl': userAvatarUrl,
    };
  }

  Map<String, Object> _generujAktualizacje(
    Map<String, dynamic> counts,
    int itemCount,
    DateTime ts,
    Map<String, dynamic> impact,
  ) {
    final updates = <String, Object>{
      'totalScans': FieldValue.increment(1),
      'totalItems': FieldValue.increment(itemCount),
      'totalWaste': FieldValue.increment(counts['waste'] ?? 0),
      'lastUpdated': Timestamp.fromDate(ts),
      'impact.estimatedMassKg':
          FieldValue.increment((impact['estimatedMassKg'] ?? 0) as num),
      'impact.estimatedCo2AvoidedKg':
          FieldValue.increment((impact['estimatedCo2AvoidedKg'] ?? 0) as num),
      'impact.estimatedCo2ProducedKg':
          FieldValue.increment((impact['estimatedCo2ProducedKg'] ?? 0) as num),
    };

    final byCategory = Map<String, int>.from(counts['byCategory'] ?? {});
    byCategory.forEach((k, v) {
      updates['byCategory.$k'] = FieldValue.increment(v);
    });

    return updates;
  }

  Future<void> _aktualizujUzytkownika(
    String uid,
    Map<String, dynamic> userData,
    Map<String, dynamic> counts,
    int itemCount,
    DateTime ts,
    Map<String, dynamic> impact,
  ) async {
    final rootRef = _db.collection('users').doc(uid);
    final metaRef = rootRef.collection('meta').doc('stats');

    await _db.runTransaction((tx) async {
      final rootSnap = await tx.get(rootRef);
      if (!rootSnap.exists) {
        tx.set(rootRef, {
          'displayName': userData['name'],
          'avatarUrl': userData['avatarUrl'],
          'lastUpdated': Timestamp.fromDate(ts),
        }, SetOptions(merge: true));
      }

      final metaSnap = await tx.get(metaRef);
      if (!metaSnap.exists) {
        tx.set(metaRef, {
          'totalScans': 0,
          'totalItems': 0,
          'totalWaste': 0,
          'byCategory': {},
          'impact': {'estimatedMassKg': 0.0},
          'lastUpdated': Timestamp.fromDate(ts),
        });
      }

      final updates = _generujAktualizacje(counts, itemCount, ts, impact);
      tx.update(rootRef, updates);
      tx.update(metaRef, updates);
    });
  }

  Future<void> _aktualizujGlobalne(
    Map<String, dynamic> counts,
    int itemCount,
    DateTime ts,
    Map<String, dynamic> impact,
  ) async {
    final globalRef = _db.collection('meta').doc('globalStats');

    await _db.runTransaction((tx) async {
      final snap = await tx.get(globalRef);
      if (!snap.exists) {
        tx.set(globalRef, {
          'totalScans': 0,
          'totalItems': 0,
          'totalWaste': 0,
          'byCategory': {},
          'impact': {'estimatedMassKg': 0.0},
          'lastUpdated': Timestamp.fromDate(ts),
        });
      }

      final updates = _generujAktualizacje(counts, itemCount, ts, impact);
      tx.update(globalRef, updates);
    });
  }

  Map<String, dynamic> _mapujDetekcje(WasteDetection d) {
    return {
      'name': d.name,
      'category': d.category,
      'confidence': d.confidence,
      'isWaste': d.isWaste,
      'reasoning': d.reasoning,
      'recyclingTip': d.recyclingTip,
      'disposalTip': d.disposalTip,
    };
  }

  Map<String, dynamic> _liczOdpady(List<WasteDetection> detections) {
    final byCategory = <String, int>{};
    int waste = 0, notWaste = 0, recycled = 0, disposed = 0, other = 0;

    for (final d in detections) {
      if (d.isWaste) {
        waste++;
        byCategory[d.category] = (byCategory[d.category] ?? 0) + 1;
        if (d.recyclingTip != null) {
          recycled++;
        } else if (d.disposalTip != null) {
          disposed++;
        } else {
          other++;
        }
      } else {
        notWaste++;
      }
    }
    return {
      'waste': waste,
      'notWaste': notWaste,
      'recycled': recycled,
      'disposed': disposed,
      'other': other,
      'byCategory': byCategory,
    };
  }

  Map<String, dynamic> _szacujWplyw(Map<String, int> byCategory) {
    const weights = {
      'Plastic': 0.05, 'Paper': 0.10, 'Metal': 0.15, 'Glass': 0.20,
      'E-waste': 0.50, 'Other': 0.08,
    };
    const co2Avoided = {
      'Plastic': 1.5, 'Paper': 1.2, 'Metal': 4.0, 'Glass': 0.3,
      'E-waste': 6.0, 'Other': 0.5,
    };

    double totalMassKg = 0.0;
    double co2AvoidedKg = 0.0;
    double co2ProducedKg = 0.0;

    byCategory.forEach((cat, numItems) {
      final w = weights[cat] ?? weights['Other']!;
      final c = co2Avoided[cat] ?? co2Avoided['Other']!;
      totalMassKg += w * numItems;
      co2AvoidedKg += w * c * numItems;
      co2ProducedKg += (w * 0.3) * numItems;
    });

    return {
      'estimatedMassKg': double.parse(totalMassKg.toStringAsFixed(2)),
      'estimatedCo2AvoidedKg': double.parse(co2AvoidedKg.toStringAsFixed(2)),
      'estimatedCo2ProducedKg': double.parse(co2ProducedKg.toStringAsFixed(2)),
    };
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> statsStream({
    String? userId,
    bool showGlobal = false,
  }) {
    if (showGlobal) {
      return _db.collection('meta').doc('globalStats').snapshots();
    }
    final uid = userId ?? FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return _db.collection('meta').doc('globalStats').snapshots();
    }
    return _db.collection('users').doc(uid).snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> historyStream({
    String? userId,
    bool showGlobal = false,
  }) {
    if (showGlobal) {
      return _db
          .collectionGroup('scans')
          .where('wasteCount', isGreaterThan: 0)
          .orderBy('timestamp', descending: true)
          .limit(50)
          .snapshots();
    }
    final uid = userId ?? FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Stream.empty();
    }
    return _db
        .collection('users')
        .doc(uid)
        .collection('scans')
        .where('wasteCount', isGreaterThan: 0)
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots();
  }
}