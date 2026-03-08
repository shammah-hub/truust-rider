import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';
import '../models/delivery_models.dart';

abstract class DeliveryRepository {
  // Agent
  Future<void> registerAgent({
    required String userId,
    required String name,
    required String phone,
    required String city,
    required List<DeliveryVehicle> vehicles,
  });
  Future<DeliveryAgent?> getAgent(String userId);
  Future<void> updateAvailability(String userId, bool isAvailable);
  Future<void> addVehicle(String userId, DeliveryVehicle vehicle);
  Future<void> removeVehicle(String userId, String vehicleId);
  Stream<DeliveryAgent?> watchAgent(String userId);

  // Jobs
  Stream<List<DeliveryJob>> watchAvailableJobs(String agentId);
  Stream<DeliveryJob?> watchJob(String jobId);
  Future<DeliveryJob?> getJob(String jobId);
  Stream<List<DeliveryJob>> watchActiveJobsForAgent(String agentId);

  // Bidding
  Future<void> placeBid({
    required String jobId,
    required String agentId,
    required String agentName,
    required double agentRating,
    required String vehicleType,
    required double amount,
    required String buyerId,
    String? note,
  });
  Future<void> withdrawBid(String bidId);
  Stream<List<DeliveryBid>> watchBidsForJob(String jobId);
  Future<DeliveryBid?> getMyBidForJob(String jobId, String agentId);

  // Delivery actions
  Future<void> markPickedUp({
    required String jobId,
    required String agentId,
    required File photo,
  });
  Future<void> updateTrackingArea({
    required String jobId,
    required String agentId,
    required String area,
    int? estimatedMinutes,
  });
  Future<void> markDelivered({
    required String jobId,
    required String agentId,
    required File photo,
  });

  // Earnings
  Future<Map<String, dynamic>> getEarningsSummary(String agentId);
}

class DeliveryRepositoryImpl implements DeliveryRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseFunctions _fn = FirebaseFunctions.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final _uuid = const Uuid();

  // ── Agent ────────────────────────────────────────────────

  @override
  Future<void> registerAgent({
    required String userId,
    required String name,
    required String phone,
    required String city,
    required List<DeliveryVehicle> vehicles,
  }) async {
    await _db.collection('deliveryAgents').doc(userId).set({
      'name': name,
      'phone': phone,
      'city': city,
      'isVerified': false, // manually verified by admin
      'isAvailable': false, // available after verification
      'rating': 5.0,
      'totalDeliveries': 0,
      'totalEarnings': 0.0,
      'vehicles': vehicles.map((v) => v.toMap()).toList(),
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Mark user as delivery agent in users collection
    await _db.collection('users').doc(userId).update({
      'isDeliveryAgent': true,
      'agentCity': city,
    });
  }

  @override
  Future<DeliveryAgent?> getAgent(String userId) async {
    final doc = await _db.collection('deliveryAgents').doc(userId).get();
    if (!doc.exists) return null;
    return DeliveryAgent.fromMap(userId, doc.data()!);
  }

  @override
  Stream<DeliveryAgent?> watchAgent(String userId) {
    return _db
        .collection('deliveryAgents')
        .doc(userId)
        .snapshots()
        .map((doc) => doc.exists
        ? DeliveryAgent.fromMap(userId, doc.data()!)
        : null);
  }

  @override
  Future<void> updateAvailability(String userId, bool isAvailable) async {
    await _db.collection('deliveryAgents').doc(userId).update({
      'isAvailable': isAvailable,
    });
  }

  @override
  Future<void> addVehicle(String userId, DeliveryVehicle vehicle) async {
    await _db.collection('deliveryAgents').doc(userId).update({
      'vehicles': FieldValue.arrayUnion([vehicle.toMap()]),
    });
  }

  @override
  Future<void> removeVehicle(String userId, String vehicleId) async {
    final doc = await _db.collection('deliveryAgents').doc(userId).get();
    final vehicles = (doc.data()?['vehicles'] as List<dynamic>? ?? [])
        .where((v) => v['id'] != vehicleId)
        .toList();
    await _db.collection('deliveryAgents').doc(userId).update({
      'vehicles': vehicles,
    });
  }

  // ── Jobs ─────────────────────────────────────────────────

  @override
  Stream<List<DeliveryJob>> watchAvailableJobs(String agentId) async* {
    // Get agent to know what categories they can handle
    final agentDoc =
    await _db.collection('deliveryAgents').doc(agentId).get();
    if (!agentDoc.exists) {
      yield [];
      return;
    }

    final agent = DeliveryAgent.fromMap(agentId, agentDoc.data()!);
    final categories =
    agent.handleableCategories.map((c) => c.name).toList();
    final city = agent.city;

    yield* _db
        .collection('deliveryJobs')
        .where('city', isEqualTo: city)
        .where('status', whereIn: ['open', 'bidding'])
        .where('weightCategory', whereIn: categories)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
        .map((doc) => DeliveryJob.fromMap(doc.id, doc.data()))
        .toList());
  }

  @override
  Stream<DeliveryJob?> watchJob(String jobId) {
    return _db
        .collection('deliveryJobs')
        .doc(jobId)
        .snapshots()
        .map((doc) =>
    doc.exists ? DeliveryJob.fromMap(doc.id, doc.data()!) : null);
  }

  @override
  Future<DeliveryJob?> getJob(String jobId) async {
    final doc = await _db.collection('deliveryJobs').doc(jobId).get();
    if (!doc.exists) return null;
    return DeliveryJob.fromMap(doc.id, doc.data()!);
  }

  @override
  Stream<List<DeliveryJob>> watchActiveJobsForAgent(String agentId) {
    return _db
        .collection('deliveryJobs')
        .where('agentId', isEqualTo: agentId)
        .where('status', whereIn: [
      'agreed',
      'pickupPending',
      'pickedUp',
      'inTransit',
      'delivered',
    ])
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
        .map((doc) => DeliveryJob.fromMap(doc.id, doc.data()))
        .toList());
  }

  // ── Bidding ──────────────────────────────────────────────

  @override
  Future<void> placeBid({
    required String jobId,
    required String agentId,
    required String agentName,
    required double agentRating,
    required String vehicleType,
    required double amount,
    required String buyerId,
    String? note,
  }) async {
    final bidId = _uuid.v4();

    final batch = _db.batch();

    // Create bid
    batch.set(_db.collection('deliveryBids').doc(bidId), {
      'jobId': jobId,
      'agentId': agentId,
      'agentName': agentName,
      'agentRating': agentRating,
      'vehicleType': vehicleType,
      'amount': amount,
      'note': note,
      'status': BidStatus.pending.name,
      'buyerId': buyerId,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Update job status to bidding + increment bid count
    batch.update(_db.collection('deliveryJobs').doc(jobId), {
      'status': DeliveryJobStatus.bidding.name,
      'bidCount': FieldValue.increment(1),
    });

    await batch.commit();

    // Notify buyer via Cloud Function
    try {
      await _fn.httpsCallable('onNewDeliveryBid').call({
        'jobId': jobId,
        'agentName': agentName,
        'amount': amount,
        'buyerId': buyerId,
      });
    } catch (_) {
      // Notification failure shouldn't fail the bid
    }
  }

  @override
  Future<void> withdrawBid(String bidId) async {
    await _db.collection('deliveryBids').doc(bidId).update({
      'status': BidStatus.withdrawn.name,
    });
  }

  @override
  Stream<List<DeliveryBid>> watchBidsForJob(String jobId) {
    return _db
        .collection('deliveryBids')
        .where('jobId', isEqualTo: jobId)
        .where('status', whereIn: ['pending', 'countered'])
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snap) => snap.docs
        .map((doc) => DeliveryBid.fromMap(doc.id, doc.data()))
        .toList());
  }

  @override
  Future<DeliveryBid?> getMyBidForJob(String jobId, String agentId) async {
    final snap = await _db
        .collection('deliveryBids')
        .where('jobId', isEqualTo: jobId)
        .where('agentId', isEqualTo: agentId)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return DeliveryBid.fromMap(snap.docs.first.id, snap.docs.first.data());
  }

  // ── Delivery Actions ─────────────────────────────────────

  @override
  Future<void> markPickedUp({
    required String jobId,
    required String agentId,
    required File photo,
  }) async {
    // Upload pickup photo
    final ref = _storage.ref('delivery/$jobId/pickup.jpg');
    await ref.putFile(photo);
    final photoUrl = await ref.getDownloadURL();

    await _db.collection('deliveryJobs').doc(jobId).update({
      'status': DeliveryJobStatus.pickedUp.name,
      'pickupPhotoUrl': photoUrl,
      'pickupTime': FieldValue.serverTimestamp(),
    });

    // Update tracking
    await _db.collection('deliveryTracking').doc(jobId).set({
      'agentId': agentId,
      'area': 'En route to pickup',
      'status': 'picked_up',
      'lastUpdated': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> updateTrackingArea({
    required String jobId,
    required String agentId,
    required String area,
    int? estimatedMinutes,
  }) async {
    await _db.collection('deliveryTracking').doc(jobId).set({
      'agentId': agentId,
      'area': area,
      'status': DeliveryJobStatus.inTransit.name,
      'estimatedMinutes': estimatedMinutes,
      'lastUpdated': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await _db.collection('deliveryJobs').doc(jobId).update({
      'status': DeliveryJobStatus.inTransit.name,
    });
  }

  @override
  Future<void> markDelivered({
    required String jobId,
    required String agentId,
    required File photo,
  }) async {
    // Upload delivery photo
    final ref = _storage.ref('delivery/$jobId/delivery.jpg');
    await ref.putFile(photo);
    final photoUrl = await ref.getDownloadURL();

    await _db.collection('deliveryJobs').doc(jobId).update({
      'status': DeliveryJobStatus.delivered.name,
      'deliveryPhotoUrl': photoUrl,
      'deliveryTime': FieldValue.serverTimestamp(),
    });

    await _db.collection('deliveryTracking').doc(jobId).set({
      'agentId': agentId,
      'area': 'Delivered',
      'status': 'delivered',
      'estimatedMinutes': 0,
      'lastUpdated': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // Notify buyer to confirm receipt
    try {
      await _fn.httpsCallable('onDeliveryMarkedDelivered').call({
        'jobId': jobId,
        'agentId': agentId,
      });
    } catch (_) {}
  }

  // ── Earnings ─────────────────────────────────────────────

  @override
  Future<Map<String, dynamic>> getEarningsSummary(String agentId) async {
    final agent = await getAgent(agentId);
    if (agent == null) return {};

    // Get completed deliveries this month
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);

    final snap = await _db
        .collection('deliveryJobs')
        .where('agentId', isEqualTo: agentId)
        .where('status', isEqualTo: DeliveryJobStatus.confirmed.name)
        .where('deliveryTime',
        isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
        .get();

    double thisMonth = 0;
    for (final doc in snap.docs) {
      thisMonth += (doc.data()['agreedAmount'] as num?)?.toDouble() ?? 0;
    }
    // Deduct 10% commission
    thisMonth *= 0.9;

    return {
      'totalEarnings': agent.totalEarnings,
      'thisMonth': thisMonth,
      'totalDeliveries': agent.totalDeliveries,
      'rating': agent.rating,
    };
  }
}
