import '../models.dart';
import 'api_service.dart';

/// Service for the Unit 360° aggregated view.
class Unit360Service {
  Unit360Service._();
  static final Unit360Service instance = Unit360Service._();

  /// GET /api/units/:id/360
  Future<Unit360Data> getUnit360(String unitId) async {
    final result = await ApiService.instance.get('/units/$unitId/360');
    return Unit360Data.fromJson(result['data'] as Map<String, dynamic>);
  }
}

/// Aggregated 360° view of a unit.
class Unit360Data {
  final UnitItem unit;
  final String buildingName;
  final String buildingAddress;
  final String buildingCity;
  final LeaseItem? activeLease;
  final List<MaintenanceTaskItem> maintenanceTickets;
  final List<CommunicationItem> communications;
  final Map<String, dynamic>? renovation;
  final Map<String, dynamic>? readiness;

  const Unit360Data({
    required this.unit,
    required this.buildingName,
    required this.buildingAddress,
    required this.buildingCity,
    this.activeLease,
    required this.maintenanceTickets,
    required this.communications,
    this.renovation,
    this.readiness,
  });

  factory Unit360Data.fromJson(Map<String, dynamic> json) {
    final unitJson = json['unit'] as Map<String, dynamic>? ?? {};
    return Unit360Data(
      unit: UnitItem.fromJson(unitJson),
      buildingName: unitJson['buildingName'] as String? ?? '',
      buildingAddress: unitJson['buildingAddress'] as String? ?? '',
      buildingCity: unitJson['buildingCity'] as String? ?? '',
      activeLease: json['activeLease'] != null
          ? LeaseItem.fromJson(json['activeLease'] as Map<String, dynamic>)
          : null,
      maintenanceTickets: (json['maintenanceTickets'] as List<dynamic>?)
              ?.map((e) => MaintenanceTaskItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      communications: (json['communications'] as List<dynamic>?)
              ?.map((e) => CommunicationItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      renovation: json['renovation'] as Map<String, dynamic>?,
      readiness: json['readiness'] as Map<String, dynamic>?,
    );
  }
}
