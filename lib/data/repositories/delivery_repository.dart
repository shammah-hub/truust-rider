import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';
import '../models/delivery_models.dart';

abstract class DeliveryRepository {
  // Agent
  Future<void> registerAgent({
    required String userId,
    required String name,
    required String phone,
    required String email,
    required String homeAddress,
    required String city,
    required List<DeliveryVehicle> vehicles,
    required List<Guarantor> guarantors,
    required String idType,
    // Optional: riders joining through an agency invite code skip the
    // Truust document checks (their agency vouches for them).
    File? idDocument,
    File? selfie,
    File? riderPermit,
    File? amacRegistration,
    File? bikeWithPlate,
    String? agencyCode,
  });
  Future<DeliveryAgent?> getAgent(String userId);
  Future<String> validateAgencyCode(String code);
  Future<void> updateAvailability(String userId, bool isAvailable);
  Future<void> addVehicle(String userId, DeliveryVehicle vehicle);
  Future<void> removeVehicle(String userId, String vehicleId);
  Future<void> updateProfilePhoto(String userId, File photo);
  Stream<DeliveryAgent?> watchAgent(String userId);

  // Jobs (Truust marketplace)
  Stream<List<DeliveryJob>> watchAvailableJobs(String agentId);
  Stream<DeliveryJob?> watchJob(String jobId);
  Future<DeliveryJob?> getJob(String jobId);
  Stream<List<DeliveryJob>> watchActiveJobsForAgent(String agentId);

  // Fleet orders (agency's own private dispatch — no bidding, no escrow)
  Stream<List<FleetOrder>> watchActiveFleetOrdersForAgent(String agentId);
  Future<void> markFleetOrderInTransit({
    required String orderId,
    required String agentId,
  });
  Future<void> markFleetOrderDelivered({
    required String orderId,
    required String agentId,
    required File photo,
  });

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
  Future<void> counterBid({
    required String jobId,
    required String bidId,
    required String buyerId,
    required double counterAmount,
  });
  Future<void> respondToCounter({
    required String bidId,
    required String agentId,
    required bool accept,
  });
  Future<void> cancelCounter({
    required String bidId,
    required String buyerId,
  });
  Stream<List<DeliveryBid>> watchBidsForJob(String jobId);
  Future<DeliveryBid?> getMyBidForJob(String jobId, String agentId);

  // Delivery actions (Truust marketplace)
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
    required String email,
    required String homeAddress,
    required String city,
    required List<DeliveryVehicle> vehicles,
    required List<Guarantor> guarantors,
    required String idType,
    // Optional: riders joining through an agency invite code skip the
    // Truust document checks (their agency vouches for them).
    File? idDocument,
    File? selfie,
    File? riderPermit,
    File? amacRegistration,
    File? bikeWithPlate,
    String? agencyCode,
  }) async {
    Future<String?> upload(String path, File? file) async {
      if (file == null) return null;
      final ref = _storage.ref(path);
      await ref.putFile(file);
      return ref.getDownloadURL();
    }

    final idDocumentUrl = await upload('deliveryAgents/$userId/id_document.jpg', idDocument);
    final selfieUrl = await upload('deliveryAgents/$userId/selfie.jpg', selfie);
    final riderPermitUrl = await upload('deliveryAgents/$userId/riders_permit.jpg', riderPermit);
    final amacRegistrationUrl = await upload('deliveryAgents/$userId/amac_registration.jpg', amacRegistration);
    final bikeWithPlateUrl = await upload('deliveryAgents/$userId/bike_with_plate.jpg', bikeWithPlate);

    await _db.collection('deliveryAgents').doc(userId).set({
      'name': name,
      // The setup page passes '' — fall back to the number they signed in with.
      'phone': phone.isNotEmpty ? phone : (FirebaseAuth.instance.currentUser?.phoneNumber ?? ''),
      'email': email,
      'homeAddress': homeAddress,
      'city': city,
      // Explicit null so an agency's "riders who entered your code" query
      // (agencyId == null) can find this rider. A missing field wouldn't match.
      'agencyId': null,
      'isVerified': false,
      'isAvailable': false,
      'rating': 5.0,
      'avgRating': 5.0,
      'totalDeliveries': 0,
      'totalEarnings': 0.0,
      'vehicles': vehicles.map((v) => v.toMap()).toList(),
      'guarantors': guarantors.map((g) => g.toMap()).toList(),
      'idType': idType,
      'idDocumentUrl': idDocumentUrl,
      'selfieUrl': selfieUrl,
      'riderPermitUrl': riderPermitUrl,
      'amacRegistrationUrl': amacRegistrationUrl,
      'bikeWithPlateUrl': bikeWithPlateUrl,
      // Agency-vouched riders skip Truust's document review, so they're kept
      // out of the pending-documents queue.
      'verificationStatus': (agencyCode != null && agencyCode.trim().isNotEmpty) ? 'agency_vouched' : 'pending',
      if (agencyCode != null && agencyCode.trim().isNotEmpty) ...{
        'agencyCodeEntered': agencyCode.trim(),
        'registeredViaAgency': true,
      },
      'createdAt': FieldValue.serverTimestamp(),
    });

    await _db.collection('users').doc(userId).set({
      'isDeliveryAgent': true,
      'agentCity': city,
    }, SetOptions(merge: true));
  }

  /// Checks an agency invite code with the backend. Returns the agency's
  /// name, or throws an Exception whose message is safe to show the rider.
  @override
  Future<String> validateAgencyCode(String code) async {
    try {
      final res = await _fn.httpsCallable('validateAgencyCode').call({'code': code});
      final data = Map<String, dynamic>.from(res.data as Map);
      return (data['agencyName'] as String?) ?? 'your agency';
    } on FirebaseFunctionsException catch (e) {
      throw Exception(e.message ?? 'Could not check that code. Try again.');
    }
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

  @override
  Future<void> updateProfilePhoto(String userId, File photo) async {
    final ref = _storage.ref('deliveryAgents/$userId/profile_photo.jpg');
    await ref.putFile(photo);
    final url = await ref.getDownloadURL();

    await _db.collection('deliveryAgents').doc(userId).update({
      'profilePhotoUrl': url,
    });
  }

  // ── Jobs (Truust marketplace) ─────────────────────────────

  @override
  Stream<List<DeliveryJob>> watchAvailableJobs(String agentId) async* {
    final agentDoc =
    await _db.collection('deliveryAgents').doc(agentId).get();
    if (!agentDoc.exists) {
      yield [];
      return;
    }

    final agent = DeliveryAgent.fromMap(agentId, agentDoc.data()!);

    if (!agent.isVerified) {
      yield [];
      return;
    }

    final categorySet =
    agent.handleableCategories.map((c) => c.name).toSet();
    final cityKey = agent.city.trim().toLowerCase();

    yield* _db
        .collection('deliveryJobs')
        .where('cityKey', isEqualTo: cityKey)
        .where('status', whereIn: ['open', 'bidding'])
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
        .map((doc) => DeliveryJob.fromMap(doc.id, doc.data()))
        .where((job) => categorySet.contains(job.weightCategory.name))
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

  // ── Fleet orders (agency's own private dispatch) ──────────



  @override
  Stream<List<FleetOrder>> watchActiveFleetOrdersForAgent(String agentId) {
    return _db
        .collection('fleetOrders')
        .where('assignedAgentId', isEqualTo: agentId)
        .where('status', whereIn: ['assigned', 'in_transit'])
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
        .map((doc) => FleetOrder.fromMap(doc.id, doc.data()))
        .toList());
  }

  @override
  Future<void> markFleetOrderInTransit({
    required String orderId,
    required String agentId,
  }) async {
    await _db.collection('fleetOrders').doc(orderId).update({
      'status': 'in_transit',
    });
  }

  @override
  Future<void> markFleetOrderDelivered({
    required String orderId,
    required String agentId,
    required File photo,
  }) async {
    final ref = _storage.ref('fleetOrders/$orderId/proof.jpg');
    await ref.putFile(photo);
    final photoUrl = await ref.getDownloadURL();

    await _db.collection('fleetOrders').doc(orderId).update({
      'status': 'delivered',
      'proofPhotoUrl': photoUrl,
      'proofPhotoUploadedAt': FieldValue.serverTimestamp(),
      'deliveredAt': FieldValue.serverTimestamp(),
    });
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

    batch.update(_db.collection('deliveryJobs').doc(jobId), {
      'status': DeliveryJobStatus.bidding.name,
      'bidCount': FieldValue.increment(1),
    });

    await batch.commit();

    try {
      await _fn.httpsCallable('onNewDeliveryBid').call({
        'jobId': jobId,
        'agentName': agentName,
        'amount': amount,
        'buyerId': buyerId,
      });
    } catch (_) {}
  }

  @override
  Future<void> withdrawBid(String bidId) async {
    await _db.collection('deliveryBids').doc(bidId).update({
      'status': BidStatus.withdrawn.name,
    });
  }

  @override
  Future<void> counterBid({
    required String jobId,
    required String bidId,
    required String buyerId,
    required double counterAmount,
  }) async {
    await _fn.httpsCallable('counterDeliveryBid').call({
      'jobId': jobId,
      'bidId': bidId,
      'buyerId': buyerId,
      'counterAmount': counterAmount,
    });
  }





  @override
  Future<void> respondToCounter({
    required String bidId,
    required String agentId,
    required bool accept,
  }) async {
    await _fn.httpsCallable('respondToCounter').call({
      'bidId': bidId,
      'agentId': agentId,
      'accept': accept,
    });
  }

  @override
  Future<void> cancelCounter({
    required String bidId,
    required String buyerId,
  }) async {
    await _fn.httpsCallable('cancelDeliveryCounter').call({
      'bidId': bidId,
      'buyerId': buyerId,
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

  // ── Delivery Actions (Truust marketplace) ─────────────────

  @override
  Future<void> markPickedUp({
    required String jobId,
    required String agentId,
    required File photo,
  }) async {
    final ref = _storage.ref('delivery/$jobId/pickup.jpg');
    await ref.putFile(photo);
    final photoUrl = await ref.getDownloadURL();

    await _db.collection('deliveryJobs').doc(jobId).update({
      'status': DeliveryJobStatus.pickedUp.name,
      'pickupPhotoUrl': photoUrl,
      'pickupTime': FieldValue.serverTimestamp(),
    });

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
    thisMonth *= 0.9;

    return {
      'totalEarnings': agent.totalEarnings,
      'thisMonth': thisMonth,
      'totalDeliveries': agent.totalDeliveries,
      'rating': agent.rating,
    };
  }
}
