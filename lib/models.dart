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

class UnitItem {
  const UnitItem({
    this.id,
    this.buildingId,
    this.amenities,
    this.squareFeet,
    required this.number,
    required this.type,
    required this.bedrooms,
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
  final int rent;
  final String status;
  final String leaseEnd;
  final String? tenant;

  // Tenant occupant fields
  final String? tenantName;
  final String? tenantPhone;
  final DateTime? tenantLeaseEnd;

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
