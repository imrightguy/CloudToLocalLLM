import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// =============================================================================
// Enums
// =============================================================================

/// Converts a snake_case string to camelCase.
/// e.g. "visite_planifiee" → "visitePlanifiee"
String _snakeToCamel(String s) {
  if (!s.contains('_')) return s;
  final parts = s.split('_');
  return parts[0] +
      parts
          .skip(1)
          .map((p) => p.isEmpty ? '' : p[0].toUpperCase() + p.substring(1))
          .join();
}

/// Converts a camelCase string to snake_case.
/// e.g. "visitePlanifiee" → "visite_planifiee"
String _camelToSnake(String s) {
  return s.replaceAllMapped(
    RegExp(r'[A-Z]'),
    (m) => '_${m[0]!.toLowerCase()}',
  );
}

enum LeadStage {
  nouveau,
  contacte,
  qualifie,
  visitePlanifiee,
  offreEnvoyee,
  negociation,
  bailSigne;

  /// Parse from an API string (e.g. "visitePlanifiee").
  static LeadStage fromString(String value) {
    return LeadStage.values.firstWhere(
      (e) => e.name == value,
      orElse: () => LeadStage.nouveau,
    );
  }

  /// Display label in French.
  String get label {
    switch (this) {
      case LeadStage.nouveau:
        return 'Nouveau';
      case LeadStage.contacte:
        return 'Contacté';
      case LeadStage.qualifie:
        return 'Qualifié';
      case LeadStage.visitePlanifiee:
        return 'Visite planifiée';
      case LeadStage.offreEnvoyee:
        return 'Offre envoyée';
      case LeadStage.negociation:
        return 'Négociation';
      case LeadStage.bailSigne:
        return 'Bail signé';
    }
  }
}

// =============================================================================
// StatCard – dashboard stat widget (UI-only, no API mapping)
// =============================================================================

class StatCard {
  const StatCard({
    required this.title,
    required this.value,
    required this.delta,
    required this.description,
  });

  final String title;
  final String value;
  final String delta;
  final String description;
}

// =============================================================================
// ActivityItem – recent activity feed (UI-only)
// =============================================================================

class ActivityItem {
  const ActivityItem({
    required this.title,
    required this.detail,
    required this.time,
    required this.color,
  });

  final String title;
  final String detail;
  final String time;
  final Color color;
}

// =============================================================================
// UserItem – authenticated user profile
// =============================================================================

class UserItem {
  const UserItem({
    this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    this.phone,
    this.role,
    this.company,
    this.language,
    this.createdAt,
  });

  final String? id;
  final String firstName;
  final String lastName;
  final String email;
  final String? phone;
  final String? role;
  final String? company;
  final String? language;
  final DateTime? createdAt;

  String get fullName {
    final trimmed = '$firstName $lastName'.trim();
    return trimmed.isEmpty ? 'Utilisateur' : trimmed;
  }

  factory UserItem.fromJson(Map<String, dynamic> json) {
    return UserItem(
      id: json['id'] as String?,
      firstName: json['firstName'] as String? ?? '',
      lastName: json['lastName'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String?,
      role: json['role'] as String?,
      company: json['company'] as String?,
      language: json['language'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'firstName': firstName,
        'lastName': lastName,
        'email': email,
        if (phone != null) 'phone': phone,
        if (role != null) 'role': role,
        if (company != null) 'company': company,
        if (language != null) 'language': language,
        if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      };
}

// =============================================================================
// AlertItem – notification alert (UI-only)
// =============================================================================

class AlertItem {
  const AlertItem({required this.label, required this.severity});

  final String label;
  final String severity;
}

// =============================================================================
// OfferItem
// =============================================================================

class OfferItem {
  const OfferItem({
    this.id,
    required this.amount,
    required this.status,
    required this.sentAt,
  });

  final String? id;
  final int amount;
  final String status;
  final String sentAt;

  factory OfferItem.fromJson(Map<String, dynamic> json) {
    return OfferItem(
      id: json['id'] as String?,
      amount: (json['amount'] as num).toInt(),
      status: json['status'] as String? ?? '',
      sentAt: json['sentAt'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'amount': amount,
        'status': status,
        'sentAt': sentAt,
      };
}

// =============================================================================
// VisitItem
// =============================================================================

class VisitItem {
  const VisitItem({
    this.id,
    this.dateTime,
    this.leadName,
    this.tenantConfirmed = false,
    this.employeeConfirmed = false,
    this.occupantNotified = false,
    this.occupantSMS,
    required this.unitLabel,
    required this.buildingName,
    required this.dateLabel,
    required this.status,
    required this.agent,
    required this.notes,
  });

  // API fields (optional)
  final String? id;
  final DateTime? dateTime;
  final String? leadName;
  final bool tenantConfirmed;
  final bool employeeConfirmed;
  final bool occupantNotified;
  final Map<String, dynamic>? occupantSMS;

  // Display fields (non-nullable, backward compat)
  final String unitLabel;
  final String buildingName;
  final String dateLabel;
  final String status;
  final String agent;
  final String notes;

  factory VisitItem.fromJson(Map<String, dynamic> json) {
    // Derive dateLabel from dateTime if available
    String? derivedDateLabel;
    if (json['dateTime'] != null) {
      try {
        final dt = DateTime.parse(json['dateTime'] as String);
        derivedDateLabel = DateFormat('dd MMM yyyy', 'fr').format(dt);
      } catch (_) {
        derivedDateLabel = null;
      }
    }

    return VisitItem(
      id: json['id'] as String?,
      unitLabel: (json['unit'] is Map<String, dynamic>)
          ? (json['unit'] as Map<String, dynamic>)['label'] as String? ?? ''
          : json['unitLabel'] as String? ?? '',
      buildingName: (json['building'] is Map<String, dynamic>)
          ? (json['building'] as Map<String, dynamic>)['name'] as String? ?? ''
          : json['buildingName'] as String? ?? '',
      dateLabel: derivedDateLabel ?? json['dateLabel'] as String? ?? '',
      dateTime: json['dateTime'] != null
          ? DateTime.parse(json['dateTime'] as String)
          : null,
      status: json['status'] as String? ?? '',
      agent: (json['employee'] is Map<String, dynamic>)
          ? '${(json['employee'] as Map<String, dynamic>)['firstName'] ?? ''} ${(json['employee'] as Map<String, dynamic>)['lastName'] ?? ''}'
              .trim()
          : json['agent'] as String? ?? '',
      notes: json['notes'] as String? ?? '',
      leadName: (json['lead'] is Map<String, dynamic>)
          ? (json['lead'] as Map<String, dynamic>)['fullName'] as String?
          : json['leadName'] as String?,
      tenantConfirmed: json['tenantConfirmed'] as bool? ?? false,
      employeeConfirmed: json['employeeConfirmed'] as bool? ?? false,
      occupantNotified: json['occupantNotified'] as bool? ?? false,
      occupantSMS: json['occupantSMS'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'unitLabel': unitLabel,
        'buildingName': buildingName,
        'dateLabel': dateLabel,
        if (dateTime != null) 'dateTime': dateTime!.toIso8601String(),
        'status': status,
        'agent': agent,
        'notes': notes,
        'leadName': leadName,
        'tenantConfirmed': tenantConfirmed,
        'employeeConfirmed': employeeConfirmed,
        'occupantNotified': occupantNotified,
        if (occupantSMS != null) 'occupantSMS': occupantSMS,
      };
}

// =============================================================================
// LeadItem
// =============================================================================

class LeadItem {
  const LeadItem({
    this.id,
    this.language,
    this.createdAt,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.desiredUnit,
    required this.budget,
    required this.source,
    required this.stage,
    required this.notes,
    required this.tags,
    required this.lastContact,
    required this.offers,
  });

  // API fields
  final String? id;
  final String? language;
  final DateTime? createdAt;

  // Display fields
  final String fullName;
  final String email;
  final String phone;
  final String desiredUnit;
  final int budget;
  final String source;
  final LeadStage stage;
  final String notes;
  final List<String> tags;
  final String lastContact;
  final List<OfferItem> offers;

  factory LeadItem.fromJson(Map<String, dynamic> json) {
    return LeadItem(
      id: json['id'] as String?,
      fullName: json['fullName'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      desiredUnit: json['desiredUnit'] as String? ?? '',
      budget: (json['budgetCents'] as num?)?.toInt() ?? 0,
      source: json['source'] as String? ?? '',
      stage: json['stage'] != null
          ? LeadStage.fromString(_snakeToCamel(json['stage'] as String))
          : LeadStage.nouveau,
      notes: json['notes'] as String? ?? '',
      tags:
          (json['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
              [],
      lastContact: json['lastContact'] as String? ?? '',
      offers: (json['offers'] as List<dynamic>?)
              ?.map((e) => OfferItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      language: json['language'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'fullName': fullName,
        'email': email,
        'phone': phone,
        'desiredUnit': desiredUnit,
        'budgetCents': budget,
        'source': source,
        'stage': _camelToSnake(stage.name),
        'notes': notes,
        'tags': tags,
        'lastContact': lastContact,
        'offers': offers.map((o) => o.toJson()).toList(),
        if (language != null) 'language': language,
        if (createdAt != null) 'createdAt': (createdAt!).toIso8601String(),
      };
}

// =============================================================================
// UnitItem
// =============================================================================

enum VacancyStatus {
  vacant,
  occupied,
  maintenance;

  static VacancyStatus fromString(String value) {
    final normalized = value.toLowerCase();
    if (normalized == 'occupied' || normalized == 'occupé') {
      return VacancyStatus.occupied;
    }
    if (normalized == 'maintenance') {
      return VacancyStatus.maintenance;
    }
    return VacancyStatus.vacant;
  }

  String get label {
    switch (this) {
      case VacancyStatus.vacant:
        return 'Libre';
      case VacancyStatus.occupied:
        return 'Occupé';
      case VacancyStatus.maintenance:
        return 'Maintenance';
    }
  }

  Color get color {
    switch (this) {
      case VacancyStatus.vacant:
        return const Color(0xFFF59E0B);
      case VacancyStatus.occupied:
        return const Color(0xFF10B981);
      case VacancyStatus.maintenance:
        return const Color(0xFFEF4444);
    }
  }
}

class UnitItem {
  const UnitItem({
    this.id,
    this.buildingId,
    this.amenities,
    this.squareFeet,
    required this.number,
    required this.type,
    required this.bedrooms,
    required this.bathrooms,
    required this.rent,
    required this.status,
    required this.leaseEnd,
    this.tenant,
    this.tenantName,
    this.tenantPhone,
    this.tenantLeaseEnd,
  });

  // API fields
  final String? id;
  final String? buildingId;
  final List<String>? amenities;
  final int? squareFeet;

  // Display fields
  final String number;
  final String type;
  final int bedrooms;
  final int bathrooms;
  final int rent;
  final String status;
  final String leaseEnd;
  final String? tenant;

  // Tenant occupant fields
  final String? tenantName;
  final String? tenantPhone;
  final DateTime? tenantLeaseEnd;

  VacancyStatus get vacancyStatus => VacancyStatus.fromString(status);

  factory UnitItem.fromJson(Map<String, dynamic> json) {
    // Convert amenities: Map → List of keys (API sends {key: true}), List → as-is, null → empty list
    List<String>? parsedAmenities;
    final rawAmenities = json['amenities'];
    if (rawAmenities is Map) {
      // API format: {"fridge": true, "stove": true}
      parsedAmenities = rawAmenities.keys.map((e) => e.toString()).toList();
    } else if (rawAmenities is List) {
      parsedAmenities = rawAmenities.map((e) => e.toString()).toList();
    } else {
      parsedAmenities = null;
    }

    // Parse tenantLeaseEnd
    DateTime? parsedTenantLeaseEnd;
    if (json['tenantLeaseEnd'] != null) {
      try {
        parsedTenantLeaseEnd = DateTime.parse(json['tenantLeaseEnd'] as String);
      } catch (_) {
        parsedTenantLeaseEnd = null;
      }
    }

    return UnitItem(
      id: json['id'] as String?,
      buildingId: json['buildingId'] as String?,
      number: json['label'] as String? ?? '',
      type: json['description'] as String? ?? '',
      bedrooms: (json['bedrooms'] as num?)?.toInt() ?? 0,
      bathrooms: (json['bathrooms'] as num?)?.toInt() ?? 0,
      rent: (json['rentCents'] as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? '',
      leaseEnd: json['leaseEnd'] as String? ?? '',
      tenant: json['tenant'] as String?,
      amenities: parsedAmenities,
      squareFeet: (json['squareFeet'] as num?)?.toInt(),
      tenantName: json['tenantName'] as String?,
      tenantPhone: json['tenantPhone'] as String?,
      tenantLeaseEnd: parsedTenantLeaseEnd,
    );
  }

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        if (buildingId != null) 'buildingId': buildingId,
        'label': number,
        'type': type,
        'bedrooms': bedrooms,
        'bathrooms': bathrooms,
        'rentCents': rent,
        'status': status,
        'leaseEnd': leaseEnd,
        'tenant': tenant,
        if (amenities != null)
          'amenities': {for (final a in amenities!) a: true},
        if (squareFeet != null) 'squareFeet': squareFeet,
        if (tenantName != null) 'tenantName': tenantName,
        if (tenantPhone != null) 'tenantPhone': tenantPhone,
        if (tenantLeaseEnd != null)
          'tenantLeaseEnd': tenantLeaseEnd!.toIso8601String().split('T').first,
      };
}

// =============================================================================
// EmployeeItem
// =============================================================================

class EmployeeItem {
  const EmployeeItem({
    this.id,
    this.createdAt,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
    required this.isActive,
    required this.buildingAssignments,
  });

  final String? id;
  final DateTime? createdAt;
  final String firstName;
  final String lastName;
  final String email;
  final String phone;
  final bool isActive;
  final List<BuildingAssignment> buildingAssignments;

  String get fullName {
    final trimmed = '$firstName $lastName'.trim();
    return trimmed.isEmpty ? 'Employé' : trimmed;
  }

  factory EmployeeItem.fromJson(Map<String, dynamic> json) {
    return EmployeeItem(
      id: json['id'] as String?,
      firstName: json['firstName'] as String? ?? '',
      lastName: json['lastName'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      isActive: json['isActive'] as bool? ?? true,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
      buildingAssignments: (json['buildingAssignments'] as List<dynamic>?)
              ?.map((e) =>
                  BuildingAssignment.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'firstName': firstName,
        'lastName': lastName,
        'email': email,
        'phone': phone,
        'isActive': isActive,
        if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
        'buildingAssignments':
            buildingAssignments.map((a) => a.toJson()).toList(),
      };
}

// =============================================================================
// BuildingAssignment
// =============================================================================

class BuildingAssignment {
  const BuildingAssignment({
    this.id,
    this.buildingId,
    this.buildingName,
    required this.role,
  });

  final String? id;
  final String? buildingId;
  final String? buildingName;
  final String role;

  String get roleLabel {
    switch (role.toLowerCase()) {
      case 'primary':
        return 'Principale';
      case 'backup':
        return 'Remplacement';
      default:
        return role;
    }
  }

  factory BuildingAssignment.fromJson(Map<String, dynamic> json) {
    return BuildingAssignment(
      id: json['id'] as String?,
      buildingId: json['buildingId'] as String?,
      buildingName: json['buildingName'] as String?,
      role: json['role'] as String? ?? 'primary',
    );
  }

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        if (buildingId != null) 'buildingId': buildingId,
        if (buildingName != null) 'buildingName': buildingName,
        'role': role,
      };
}

// =============================================================================
// ScheduleItem
// =============================================================================

class ScheduleItem {
  const ScheduleItem({
    this.id,
    this.employeeId,
    this.employeeName,
    this.buildingId,
    this.buildingName,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    this.createdAt,
  });

  final String? id;
  final String? employeeId;
  final String? employeeName;
  final String? buildingId;
  final String? buildingName;
  final int dayOfWeek;
  final String startTime;
  final String endTime;
  final DateTime? createdAt;

  String get dayLabel {
    const days = [
      'Dimanche',
      'Lundi',
      'Mardi',
      'Mercredi',
      'Jeudi',
      'Vendredi',
      'Samedi',
    ];
    if (dayOfWeek >= 0 && dayOfWeek < days.length) return days[dayOfWeek];
    return 'Jour $dayOfWeek';
  }

  factory ScheduleItem.fromJson(Map<String, dynamic> json) {
    return ScheduleItem(
      id: json['id'] as String?,
      employeeId: json['employeeId'] as String?,
      employeeName: json['employeeName'] as String?,
      buildingId: json['buildingId'] as String?,
      buildingName: json['buildingName'] as String?,
      dayOfWeek: (json['dayOfWeek'] as num?)?.toInt() ?? 0,
      startTime: json['startTime'] as String? ?? '09:00',
      endTime: json['endTime'] as String? ?? '17:00',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        if (employeeId != null) 'employeeId': employeeId,
        if (buildingId != null) 'buildingId': buildingId,
        'dayOfWeek': dayOfWeek,
        'startTime': startTime,
        'endTime': endTime,
      };

  bool overlaps(ScheduleItem other) {
    if (dayOfWeek != other.dayOfWeek) return false;
    if (buildingId != null && other.buildingId != null && buildingId != other.buildingId) return false;
    return startTime.compareTo(other.endTime) < 0 &&
        other.startTime.compareTo(endTime) < 0;
  }
}

// =============================================================================
// BuildingItem
// =============================================================================

class BuildingItem {
  const BuildingItem({
    this.id,
    this.description,
    this.properties,
    required this.name,
    required this.address,
    required this.city,
    required this.totalUnits,
    required this.occupiedUnits,
    required this.monthlyRevenue,
    required this.units,
  });

  // API fields
  final String? id;
  final String? description;
  final Map<String, dynamic>? properties;

  // Display fields
  final String name;
  final String address;
  final String city;
  final int totalUnits;
  final int occupiedUnits;
  final int monthlyRevenue;
  final List<UnitItem> units;

  double get occupancyRate =>
      totalUnits > 0 ? occupiedUnits / totalUnits.toDouble() : 0.0;

  factory BuildingItem.fromJson(Map<String, dynamic> json) {
    return BuildingItem(
      id: json['id'] as String?,
      description: json['description'] as String?,
      properties: json['properties'] as Map<String, dynamic>?,
      name: json['name'] as String? ?? '',
      address: json['address'] as String? ?? '',
      city: json['city'] as String? ?? '',
      totalUnits: (json['totalUnits'] as num?)?.toInt() ?? 0,
      occupiedUnits: (json['occupiedUnits'] as num?)?.toInt() ?? 0,
      monthlyRevenue: (json['monthlyRevenue'] as num?)?.toInt() ?? 0,
      units: (json['units'] as List<dynamic>?)
              ?.map((e) => UnitItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'name': name,
        'address': address,
        'city': city,
        'totalUnits': totalUnits,
        'occupiedUnits': occupiedUnits,
        'monthlyRevenue': monthlyRevenue,
        'units': units.map((u) => u.toJson()).toList(),
        if (description != null) 'description': description,
        if (properties != null) 'properties': properties,
      };
}

// =============================================================================
// DocumentType
// =============================================================================

enum DocumentType {
  lease,
  contract,
  insurance,
  other;

  static DocumentType fromString(String value) {
    final normalized = value.toLowerCase();
    if (normalized == 'lease' || normalized == 'bail') return DocumentType.lease;
    if (normalized == 'contract' || normalized == 'contrat') return DocumentType.contract;
    if (normalized == 'insurance' || normalized == 'assurance') return DocumentType.insurance;
    return DocumentType.other;
  }

  String get label {
    switch (this) {
      case DocumentType.lease:
        return 'Bail';
      case DocumentType.contract:
        return 'Contrat';
      case DocumentType.insurance:
        return 'Assurance';
      case DocumentType.other:
        return 'Autre';
    }
  }

  String get apiValue {
    switch (this) {
      case DocumentType.lease:
        return 'lease';
      case DocumentType.contract:
        return 'contract';
      case DocumentType.insurance:
        return 'insurance';
      case DocumentType.other:
        return 'other';
    }
  }

  IconData get icon {
    switch (this) {
      case DocumentType.lease:
        return Icons.description_outlined;
      case DocumentType.contract:
        return Icons.gavel_outlined;
      case DocumentType.insurance:
        return Icons.shield_outlined;
      case DocumentType.other:
        return Icons.insert_drive_file_outlined;
    }
  }

  Color get color {
    switch (this) {
      case DocumentType.lease:
        return const Color(0xFF6366F1);
      case DocumentType.contract:
        return const Color(0xFF0F766E);
      case DocumentType.insurance:
        return const Color(0xFFF59E0B);
      case DocumentType.other:
        return const Color(0xFF64748B);
    }
  }
}

// =============================================================================
// DocumentItem
// =============================================================================

class DocumentItem {
  const DocumentItem({
    this.id,
    required this.fileName,
    required this.fileSize,
    required this.fileType,
    required this.documentType,
    this.description,
    this.buildingId,
    this.buildingName,
    this.unitId,
    this.unitLabel,
    this.fileUrl,
    this.createdAt,
    this.updatedAt,
  });

  final String? id;
  final String fileName;
  final int fileSize;
  final String fileType;
  final DocumentType documentType;
  final String? description;
  final String? buildingId;
  final String? buildingName;
  final String? unitId;
  final String? unitLabel;
  final String? fileUrl;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get fileSizeLabel {
    if (fileSize < 1024) return '$fileSize o';
    if (fileSize < 1024 * 1024) return '${(fileSize / 1024).toStringAsFixed(1)} Ko';
    return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} Mo';
  }

  String get locationLabel {
    final parts = <String>[
      if (buildingName != null) buildingName!,
      if (unitLabel != null) unitLabel!,
    ];
    return parts.isEmpty ? 'Non associé' : parts.join(' · ');
  }

  bool get isPdf => fileType.toLowerCase() == 'application/pdf' || fileName.toLowerCase().endsWith('.pdf');
  bool get isImage {
    final t = fileType.toLowerCase();
    return t.startsWith('image/') || fileName.toLowerCase().endsWith('.jpg') || fileName.toLowerCase().endsWith('.jpeg') || fileName.toLowerCase().endsWith('.png') || fileName.toLowerCase().endsWith('.gif') || fileName.toLowerCase().endsWith('.webp');
  }

  factory DocumentItem.fromJson(Map<String, dynamic> json) {
    return DocumentItem(
      id: json['id'] as String?,
      fileName: json['fileName'] as String? ?? json['filename'] as String? ?? '',
      fileSize: (json['fileSize'] as num?)?.toInt() ?? (json['size'] as num?)?.toInt() ?? 0,
      fileType: json['fileType'] as String? ?? json['mimeType'] as String? ?? '',
      documentType: json['documentType'] != null
          ? DocumentType.fromString(json['documentType'] as String)
          : DocumentType.other,
      description: json['description'] as String?,
      buildingId: json['buildingId'] as String?,
      buildingName: json['buildingName'] as String?,
      unitId: json['unitId'] as String?,
      unitLabel: json['unitLabel'] as String?,
      fileUrl: json['fileUrl'] as String? ?? json['url'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'fileName': fileName,
        'fileSize': fileSize,
        'fileType': fileType,
        'documentType': documentType.apiValue,
        if (description != null) 'description': description,
        if (buildingId != null) 'buildingId': buildingId,
        if (unitId != null) 'unitId': unitId,
      };
}
