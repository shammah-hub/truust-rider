import 'package:cloud_firestore/cloud_firestore.dart';

// ═══════════════════════════════════════════════════════════════
//  DELIVERY MODELS
// ═══════════════════════════════════════════════════════════════

// ── Enums ────────────────────────────────────────────────────

enum VehicleType { bike, car, pickup, truck }

enum WeightCategory { light, medium, heavy, bulk }

enum DeliveryJobStatus {
  open,
  bidding,
  agreed,
  pickupPending,
  pickedUp,
  inTransit,
  delivered,
  confirmed,
  cancelled,
  expired,
}

enum BidStatus { pending, accepted, rejected, countered, withdrawn }

// ── Helpers ──────────────────────────────────────────────────

extension VehicleTypeX on VehicleType {
  String get label {
    switch (this) {
      case VehicleType.bike: return 'Bike';
      case VehicleType.car: return 'Car';
      case VehicleType.pickup: return 'Pickup Truck';
      case VehicleType.truck: return 'Large Truck';
    }
  }

  String get emoji {
    switch (this) {
      case VehicleType.bike: return '🏍️';
      case VehicleType.car: return '🚗';
      case VehicleType.pickup: return '🛻';
      case VehicleType.truck: return '🚛';
    }
  }

  String get weightRange {
    switch (this) {
      case VehicleType.bike: return 'Up to 5kg';
      case VehicleType.car: return '5kg – 50kg';
      case VehicleType.pickup: return '50kg – 300kg';
      case VehicleType.truck: return '300kg and above';
    }
  }

  // Which weight categories this vehicle can handle
  List<WeightCategory> get canHandle {
    switch (this) {
      case VehicleType.bike: return [WeightCategory.light];
      case VehicleType.car: return [WeightCategory.light, WeightCategory.medium];
      case VehicleType.pickup: return [WeightCategory.light, WeightCategory.medium, WeightCategory.heavy];
      case VehicleType.truck: return WeightCategory.values.toList();
    }
  }
}

extension WeightCategoryX on WeightCategory {
  String get label {
    switch (this) {
      case WeightCategory.light: return 'Light (under 5kg)';
      case WeightCategory.medium: return 'Medium (5–50kg)';
      case WeightCategory.heavy: return 'Heavy (50–300kg)';
      case WeightCategory.bulk: return 'Bulk (300kg+)';
    }
  }

  String get emoji {
    switch (this) {
      case WeightCategory.light: return '📦';
      case WeightCategory.medium: return '🗃️';
      case WeightCategory.heavy: return '🏗️';
      case WeightCategory.bulk: return '🚛';
    }
  }
}

extension DeliveryJobStatusX on DeliveryJobStatus {
  String get label {
    switch (this) {
      case DeliveryJobStatus.open: return 'Open';
      case DeliveryJobStatus.bidding: return 'Receiving Bids';
      case DeliveryJobStatus.agreed: return 'Agent Assigned';
      case DeliveryJobStatus.pickupPending: return 'Awaiting Pickup';
      case DeliveryJobStatus.pickedUp: return 'Picked Up';
      case DeliveryJobStatus.inTransit: return 'In Transit';
      case DeliveryJobStatus.delivered: return 'Delivered';
      case DeliveryJobStatus.confirmed: return 'Completed';
      case DeliveryJobStatus.cancelled: return 'Cancelled';
      case DeliveryJobStatus.expired: return 'Expired';
    }
  }
}

// ── Vehicle Model ────────────────────────────────────────────

class DeliveryVehicle {
  final String id;
  final VehicleType type;
  final String plate;
  final String description;
  final bool isVerified;
  final DateTime addedAt;

  const DeliveryVehicle({
    required this.id,
    required this.type,
    required this.plate,
    required this.description,
    required this.isVerified,
    required this.addedAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'type': type.name,
    'plate': plate.toUpperCase(),
    'description': description,
    'isVerified': isVerified,
    'addedAt': Timestamp.fromDate(addedAt),
  };

  factory DeliveryVehicle.fromMap(Map<String, dynamic> m) => DeliveryVehicle(
    id: m['id'] ?? '',
    type: VehicleType.values.firstWhere(
          (e) => e.name == m['type'],
      orElse: () => VehicleType.bike,
    ),
    plate: m['plate'] ?? '',
    description: m['description'] ?? '',
    isVerified: m['isVerified'] ?? false,
    addedAt: m['addedAt'] != null
        ? (m['addedAt'] as Timestamp).toDate()
        : DateTime.now(),
  );
}

// ── Guarantor Model ──────────────────────────────────────────
// Information on file only — no automated verification. Your
// team calls these numbers manually only if something serious
// comes up (dispute, missing rider, fraud concern).

class Guarantor {
  final String name;
  final String phone;
  final String relationship;

  const Guarantor({
    required this.name,
    required this.phone,
    required this.relationship,
  });

  Map<String, dynamic> toMap() => {
    'name': name,
    'phone': phone,
    'relationship': relationship,
  };

  factory Guarantor.fromMap(Map<String, dynamic> m) => Guarantor(
    name: m['name'] ?? '',
    phone: m['phone'] ?? '',
    relationship: m['relationship'] ?? '',
  );
}

// ── Agent Model ──────────────────────────────────────────────

class DeliveryAgent {
  final String userId;
  final String name;
  final String phone;
  final String email;
  final String homeAddress;
  final bool isVerified;
  final bool isAvailable;
  final String city;
  final double rating;
  final int totalDeliveries;
  final double totalEarnings;
  final List<DeliveryVehicle> vehicles;
  final List<Guarantor> guarantors;
  final DateTime createdAt;
  final String tier;

  // Manual-review KYC fields. verificationStatus mirrors isVerified
  // today (admin flips both together) but is kept as its own field
  // so a future automated provider (Smile ID) can eventually set it
  // to more granular states ('pending' | 'approved' | 'rejected')
  // without a schema change.
  final String idType; // 'drivers_license' | 'voters_card'
  final String? idDocumentUrl;
  final String? selfieUrl;
  final String verificationStatus; // 'pending' | 'approved' | 'rejected'
  final String? rejectionReason;

  // Additional local-compliance documents (Abuja/AMAC operating
  // requirements) — same manual-review model as idDocumentUrl/selfieUrl.
  final String? riderPermitUrl;
  final String? amacRegistrationUrl;
  final String? bikeWithPlateUrl;

  // Fleet SaaS linkage. agencyId is only ever set by the admin
  // (approveRiderVerification) once the code the rider entered is
  // confirmed against a real agency — never trusted from client input
  // directly. agencyCodeEntered is what the rider actually typed,
  // kept for the admin to cross-check at review time.
  final String? agencyId;
  final String? agencyCodeEntered;

  // Rider's own profile picture — cosmetic only, shown on the
  // rider's own app UI. Never shown to customers; selfieUrl (the
  // verification capture) is the only customer-facing identity
  // photo and this field never overrides it.
  final String? profilePhotoUrl;

  const DeliveryAgent({
    required this.userId,
    required this.name,
    required this.phone,
    this.email = '',
    this.homeAddress = '',
    required this.isVerified,
    required this.isAvailable,
    required this.city,
    required this.rating,
    required this.totalDeliveries,
    required this.totalEarnings,
    required this.vehicles,
    this.guarantors = const [],
    required this.createdAt,
    this.tier = 'bronze',
    this.idType = '',
    this.idDocumentUrl,
    this.selfieUrl,
    this.verificationStatus = 'pending',
    this.rejectionReason,
    this.riderPermitUrl,
    this.amacRegistrationUrl,
    this.bikeWithPlateUrl,
    this.agencyId,
    this.agencyCodeEntered,
    this.profilePhotoUrl,
  });

  // Agent is pending if registered but not yet verified
  bool get isPending => !isVerified;

  // All vehicle types this agent can handle
  List<WeightCategory> get handleableCategories {
    final categories = <WeightCategory>{};
    for (final v in vehicles) {
      categories.addAll(v.type.canHandle);
    }
    return categories.toList();
  }

  factory DeliveryAgent.fromMap(String userId, Map<String, dynamic> m) =>
      DeliveryAgent(
        userId: userId,
        name: m['name'] ?? '',
        phone: m['phone'] ?? '',
        email: m['email'] ?? '',
        homeAddress: m['homeAddress'] ?? '',
        isVerified: m['isVerified'] ?? false,
        isAvailable: m['isAvailable'] ?? true,
        city: m['city'] ?? '',
        // Tier progression (rewards.js) reads 'avgRating', not
        // 'rating' — fall back to 'rating' for older docs that
        // were only ever written with the old field name.
        rating: (m['avgRating'] as num?)?.toDouble() ??
            (m['rating'] as num?)?.toDouble() ??
            5.0,
        totalDeliveries: (m['totalDeliveries'] as num?)?.toInt() ?? 0,
        totalEarnings: (m['totalEarnings'] as num?)?.toDouble() ?? 0,
        vehicles: (m['vehicles'] as List<dynamic>?)
            ?.map((v) => DeliveryVehicle.fromMap(Map<String, dynamic>.from(v)))
            .toList() ??
            [],
        guarantors: (m['guarantors'] as List<dynamic>?)
            ?.map((g) => Guarantor.fromMap(Map<String, dynamic>.from(g)))
            .toList() ??
            [],
        createdAt: m['createdAt'] != null
            ? (m['createdAt'] as Timestamp).toDate()
            : DateTime.now(),
        // Written by the backend's rewards.js (updateRiderTier /
        // onRiderRegistered) — defaults to 'bronze' for any agent
        // doc that predates the tier system.
        tier: m['tier'] as String? ?? 'bronze',
        idType: m['idType'] as String? ?? '',
        idDocumentUrl: m['idDocumentUrl'] as String?,
        selfieUrl: m['selfieUrl'] as String?,
        verificationStatus: m['verificationStatus'] as String? ?? 'pending',
        rejectionReason: m['rejectionReason'] as String?,
        riderPermitUrl: m['riderPermitUrl'] as String?,
        amacRegistrationUrl: m['amacRegistrationUrl'] as String?,
        bikeWithPlateUrl: m['bikeWithPlateUrl'] as String?,
        agencyId: m['agencyId'] as String?,
        agencyCodeEntered: m['agencyCodeEntered'] as String?,
        profilePhotoUrl: m['profilePhotoUrl'] as String?,
      );
}

// ── Job Model ────────────────────────────────────────────────
class DeliveryJob {
  final String id;
  final String orderId;
  final String sellerId;
  final String buyerId;
  final String sellerName;
  final String buyerName;
  final String pickupAddress;
  final String pickupArea;
  final String destination;
  final String destinationArea;
  final String city;
  final WeightCategory weightCategory;
  final double weightKg;
  final String itemDescription;
  final String? itemPhotoUrl;
  final DeliveryJobStatus status;
  final String? agentId;
  final String? agentName;
  final double? agreedAmount;
  final String? pickupPhotoUrl;
  final String? deliveryPhotoUrl;
  final DateTime? pickupTime;
  final DateTime? deliveryTime;
  final DateTime expiresAt;
  final DateTime createdAt;
  final int bidCount;

  const DeliveryJob({
    required this.id,
    required this.orderId,
    required this.sellerId,
    required this.buyerId,
    required this.sellerName,
    required this.buyerName,
    required this.pickupAddress,
    required this.pickupArea,
    required this.destination,
    required this.destinationArea,
    required this.city,
    required this.weightCategory,
    required this.weightKg,
    required this.itemDescription,
    this.itemPhotoUrl,
    required this.status,
    this.agentId,
    this.agentName,
    this.agreedAmount,
    this.pickupPhotoUrl,
    this.deliveryPhotoUrl,
    this.pickupTime,
    this.deliveryTime,
    required this.expiresAt,
    required this.createdAt,
    this.bidCount = 0,
  });

  factory DeliveryJob.fromMap(String id, Map<String, dynamic> m) =>
      DeliveryJob(
        id: id,
        orderId: m['orderId'] ?? '',
        sellerId: m['sellerId'] ?? '',
        buyerId: m['buyerId'] ?? '',
        sellerName: m['sellerName'] ?? '',
        buyerName: m['buyerName'] ?? '',
        pickupAddress: m['pickupAddress'] ?? '',
        pickupArea: m['pickupArea'] ?? '',
        destination: m['destination'] ?? '',
        destinationArea: m['destinationArea'] ?? '',
        city: m['city'] ?? '',
        weightCategory: WeightCategory.values.firstWhere(
              (e) => e.name == m['weightCategory'],
          orElse: () => WeightCategory.light,
        ),
        weightKg: (m['weightKg'] as num?)?.toDouble() ?? 0,
        itemDescription: m['itemDescription'] ?? '',
        itemPhotoUrl: m['itemPhotoUrl'],
        status: DeliveryJobStatus.values.firstWhere(
              (e) => e.name == m['status'],
          orElse: () => DeliveryJobStatus.open,
        ),
        agentId: m['agentId'],
        agentName: m['agentName'],
        agreedAmount: (m['agreedAmount'] as num?)?.toDouble(),
        pickupPhotoUrl: m['pickupPhotoUrl'],
        deliveryPhotoUrl: m['deliveryPhotoUrl'],
        pickupTime: m['pickupTime'] != null
            ? (m['pickupTime'] as Timestamp).toDate()
            : null,
        deliveryTime: m['deliveryTime'] != null
            ? (m['deliveryTime'] as Timestamp).toDate()
            : null,
        expiresAt: m['expiresAt'] != null
            ? (m['expiresAt'] as Timestamp).toDate()
            : DateTime.now().add(const Duration(hours: 24)),
        createdAt: m['createdAt'] != null
            ? (m['createdAt'] as Timestamp).toDate()
            : DateTime.now(),
        bidCount: (m['bidCount'] as num?)?.toInt() ?? 0,
      );
}

// ── Bid Model ────────────────────────────────────────────────

class DeliveryBid {
  final String id;
  final String jobId;
  final String agentId;
  final String agentName;
  final double agentRating;
  final String vehicleType;
  final double amount;
  final String? note;
  final BidStatus status;
  final double? counterAmount;
  final String buyerId;
  final DateTime createdAt;

  const DeliveryBid({
    required this.id,
    required this.jobId,
    required this.agentId,
    required this.agentName,
    required this.agentRating,
    required this.vehicleType,
    required this.amount,
    this.note,
    required this.status,
    this.counterAmount,
    required this.buyerId,
    required this.createdAt,
  });

  // The current price — counter if exists, otherwise original
  double get currentAmount => counterAmount ?? amount;

  factory DeliveryBid.fromMap(String id, Map<String, dynamic> m) =>
      DeliveryBid(
        id: id,
        jobId: m['jobId'] ?? '',
        agentId: m['agentId'] ?? '',
        agentName: m['agentName'] ?? '',
        agentRating: (m['agentRating'] as num?)?.toDouble() ?? 5.0,
        vehicleType: m['vehicleType'] ?? 'bike',
        amount: (m['amount'] as num?)?.toDouble() ?? 0,
        note: m['note'],
        status: BidStatus.values.firstWhere(
              (e) => e.name == m['status'],
          orElse: () => BidStatus.pending,
        ),
        counterAmount: (m['counterAmount'] as num?)?.toDouble(),
        buyerId: m['buyerId'] ?? '',
        createdAt: m['createdAt'] != null
            ? (m['createdAt'] as Timestamp).toDate()
            : DateTime.now(),
      );
}

// ── Delivery Message Model ───────────────────────────────────

class DeliveryMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String text;
  final String type; // text | offer | counter | accepted | system
  final double? amount;
  final DateTime createdAt;

  const DeliveryMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.type,
    this.amount,
    required this.createdAt,
  });

  factory DeliveryMessage.fromMap(String id, Map<String, dynamic> m) =>
      DeliveryMessage(
        id: id,
        senderId: m['senderId'] ?? '',
        senderName: m['senderName'] ?? '',
        text: m['text'] ?? '',
        type: m['type'] ?? 'text',
        amount: (m['amount'] as num?)?.toDouble(),
        createdAt: m['createdAt'] != null
            ? (m['createdAt'] as Timestamp).toDate()
            : DateTime.now(),
      );
}

// ── Tracking Model ───────────────────────────────────────────

class DeliveryTracking {
  final String agentId;
  final String area;
  final String status;
  final int? estimatedMinutes;
  final DateTime lastUpdated;

  const DeliveryTracking({
    required this.agentId,
    required this.area,
    required this.status,
    this.estimatedMinutes,
    required this.lastUpdated,
  });

  factory DeliveryTracking.fromMap(Map<String, dynamic> m) => DeliveryTracking(
    agentId: m['agentId'] ?? '',
    area: m['area'] ?? '',
    status: m['status'] ?? '',
    estimatedMinutes: m['estimatedMinutes'],
    lastUpdated: m['lastUpdated'] != null
        ? (m['lastUpdated'] as Timestamp).toDate()
        : DateTime.now(),
  );
}



// ── Fleet Order Model ────────────────────────────────────────
// An agency's own privately-dispatched delivery — completely
// separate from the Truust marketplace (DeliveryJob above). No
// bidding, no escrow, no OTP: the manager already decided who does
// this job, so it goes straight to Active with a simpler
// pickup → in transit → photo-proof-and-deliver flow.

class FleetOrderStop {
  final String address;
  final bool completed;
  const FleetOrderStop({required this.address, required this.completed});

  factory FleetOrderStop.fromMap(Map<String, dynamic> m) => FleetOrderStop(
    address: m['address'] ?? '',
    completed: m['completed'] ?? false,
  );
}

class FleetOrder {
  final String id;
  final String agencyId;
  final String customerName;
  final String customerPhone;
  final String pickupAddress;
  final String dropoffAddress;
  // Coordinates are optional — only present once the agency
  // dashboard's dispatch form captures them via address autocomplete.
  // Null until that's wired up; the tracking page falls back to
  // address-text navigation when these are absent.
  final double? pickupLat;
  final double? pickupLng;
  final double? dropoffLat;
  final double? dropoffLng;
  final List<FleetOrderStop> extraStops;
  final double fee;
  final String status; // pending | assigned | in_transit | delivered | cancelled
  final String? proofPhotoUrl;
  final DateTime? scheduledFor;
  final DateTime? createdAt;
  final DateTime? assignedAt;
  final DateTime? deliveredAt;

  const FleetOrder({
    required this.id,
    required this.agencyId,
    required this.customerName,
    required this.customerPhone,
    required this.pickupAddress,
    required this.dropoffAddress,
    this.pickupLat,
    this.pickupLng,
    this.dropoffLat,
    this.dropoffLng,
    required this.extraStops,
    required this.fee,
    required this.status,
    this.proofPhotoUrl,
    this.scheduledFor,
    this.createdAt,
    this.assignedAt,
    this.deliveredAt,
  });

  factory FleetOrder.fromMap(String id, Map<String, dynamic> m) => FleetOrder(
    id: id,
    agencyId: m['agencyId'] ?? '',
    customerName: m['customerName'] ?? 'Customer',
    customerPhone: m['customerPhone'] ?? '',
    pickupAddress: m['pickupAddress'] ?? '',
    dropoffAddress: m['dropoffAddress'] ?? '',
    pickupLat: (m['pickupLat'] as num?)?.toDouble(),
    pickupLng: (m['pickupLng'] as num?)?.toDouble(),
    dropoffLat: (m['dropoffLat'] as num?)?.toDouble(),
    dropoffLng: (m['dropoffLng'] as num?)?.toDouble(),
    extraStops: (m['extraStops'] as List<dynamic>?)
        ?.map((s) => FleetOrderStop.fromMap(Map<String, dynamic>.from(s)))
        .toList() ?? [],
    fee: (m['fee'] as num?)?.toDouble() ?? 0,
    status: m['status'] ?? 'assigned',
    proofPhotoUrl: m['proofPhotoUrl'] as String?,
    scheduledFor: m['scheduledFor'] != null ? (m['scheduledFor'] as Timestamp).toDate() : null,
    createdAt: m['createdAt'] != null ? (m['createdAt'] as Timestamp).toDate() : null,
    assignedAt: m['assignedAt'] != null ? (m['assignedAt'] as Timestamp).toDate() : null,
    deliveredAt: m['deliveredAt'] != null ? (m['deliveredAt'] as Timestamp).toDate() : null,
  );
}
