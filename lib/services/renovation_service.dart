import 'api_service.dart';

class RenovationOrder {
  const RenovationOrder({
    required this.id,
    required this.renovationRecordId,
    required this.vendorName,
    required this.itemName,
    required this.quantityOrdered,
    required this.quantityReceived,
    required this.status,
    required this.notes,
    required this.expectedAt,
    required this.createdAt,
  });

  final String id;
  final String renovationRecordId;
  final String vendorName;
  final String itemName;
  final int quantityOrdered;
  final int quantityReceived;
  final String status;
  final String notes;
  final DateTime? expectedAt;
  final DateTime? createdAt;

  factory RenovationOrder.fromJson(Map<String, dynamic> json) {
    return RenovationOrder(
      id: json['id'] as String? ?? '',
      renovationRecordId: json['renovationRecordId'] as String? ?? '',
      vendorName: json['vendorName'] as String? ?? '',
      itemName: json['itemName'] as String? ?? '',
      quantityOrdered: (json['quantityOrdered'] as num?)?.toInt() ?? 0,
      quantityReceived: (json['quantityReceived'] as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? 'draft',
      notes: json['notes'] as String? ?? '',
      expectedAt: json['expectedAt'] != null
          ? DateTime.tryParse(json['expectedAt'] as String)
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
    );
  }

  String get statusLabel {
    switch (status) {
      case 'ordered':
        return 'Commandée';
      case 'partially_received':
        return 'Partiellement reçue';
      case 'received':
        return 'Reçue';
      case 'cancelled':
        return 'Annulée';
      default:
        return 'Brouillon';
    }
  }
}

/// API client for renovation records, tasks, and material orders.
class RenovationService {
  RenovationService._();
  static final RenovationService instance = RenovationService._();

  /// GET /renovations
  Future<List<Map<String, dynamic>>> getRenovations() async {
    final result = await ApiService.instance.get('/renovations');
    final data = result['data'] as List<dynamic>? ?? const [];
    return data.map((e) => e as Map<String, dynamic>).toList();
  }

  /// GET /renovations/:id
  Future<Map<String, dynamic>> getRenovation(String id) async {
    final result = await ApiService.instance.get('/renovations/$id');
    return (result['data'] as Map<String, dynamic>?) ?? const {};
  }

  /// GET /renovations/:id/orders — material orders for a renovation.
  Future<List<RenovationOrder>> getOrders(String renovationId) async {
    final result =
        await ApiService.instance.get('/renovations/$renovationId/orders');
    final data = result['data'] as List<dynamic>? ?? const [];
    return data
        .map((e) => RenovationOrder.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// POST /renovations/:id/orders — create a material order.
  ///
  /// The backend validates `renovationRecordId` from the body, so it is always
  /// included.
  Future<RenovationOrder> createOrder(
    String renovationId, {
    required String vendorName,
    required String itemName,
    required int quantityOrdered,
    String? notes,
  }) async {
    final result =
        await ApiService.instance.post('/renovations/$renovationId/orders', {
      'renovationRecordId': renovationId,
      'vendorName': vendorName,
      'itemName': itemName,
      'quantityOrdered': quantityOrdered,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    });
    return RenovationOrder.fromJson(result['data'] as Map<String, dynamic>);
  }

  /// PATCH /renovations/orders/:id — update a material order.
  Future<RenovationOrder> updateOrder(
    String orderId,
    Map<String, dynamic> data,
  ) async {
    final result =
        await ApiService.instance.patch('/renovations/orders/$orderId', data);
    return RenovationOrder.fromJson(result['data'] as Map<String, dynamic>);
  }

  /// Helper that records received quantity and advances the order status.
  Future<RenovationOrder> markReceived(
    String orderId,
    int quantityReceived,
    int quantityOrdered,
  ) async {
    final status =
        quantityReceived >= quantityOrdered ? 'received' : 'partially_received';
    return updateOrder(orderId, {
      'quantityReceived': quantityReceived,
      'status': status,
    });
  }
}
