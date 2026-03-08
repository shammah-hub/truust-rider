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

// ── Agent Model ──────────────────────────────────────────────

class DeliveryAgent {
  final String userId;
  final String name;
  final String phone;
  final bool isVerified;
  final bool isAvailable;
  final String city;
  final double rating;
  final int totalDeliveries;
  final double totalEarnings;
  final List<DeliveryVehicle> vehicles;
  final DateTime createdAt;

  const DeliveryAgent({
    required this.userId,
    required this.name,
    required this.phone,
    required this.isVerified,
    required this.isAvailable,
    required this.city,
    required this.rating,
    required this.totalDeliveries,
    required this.totalEarnings,
    required this.vehicles,
    required this.createdAt,
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
        isVerified: m['isVerified'] ?? false,
        isAvailable: m['isAvailable'] ?? true,
        city: m['city'] ?? '',
        rating: (m['rating'] as num?)?.toDouble() ?? 5.0,
        totalDeliveries: (m['totalDeliveries'] as num?)?.toInt() ?? 0,
        totalEarnings: (m['totalEarnings'] as num?)?.toDouble() ?? 0,
        vehicles: (m['vehicles'] as List<dynamic>?)
            ?.map((v) => DeliveryVehicle.fromMap(Map<String, dynamic>.from(v)))
            .toList() ??
            [],
        createdAt: m['createdAt'] != null
            ? (m['createdAt'] as Timestamp).toDate()
            : DateTime.now(),
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
