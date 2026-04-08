import 'package:flutter/material.dart';

// =============================================================================
// Enums
// =============================================================================

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

  // Display fields (non-nullable, backward compat)
  final String unitLabel;
  final String buildingName;
  final String dateLabel;
  final String status;
  final String agent;
  final String notes;

  factory VisitItem.fromJson(Map<String, dynamic> json) {
    return VisitItem(
      id: json['id'] as String?,
      unitLabel: json['unitLabel'] as String? ?? '',
      buildingName: json['buildingName'] as String? ?? '',
      dateLabel: json['dateLabel'] as String? ?? '',
      dateTime: json['dateTime'] != null
          ? DateTime.parse(json['dateTime'] as String)
          : null,
      status: json['status'] as String? ?? '',
      agent: json['agent'] as String? ?? '',
      notes: json['notes'] as String? ?? '',
      leadName: json['leadName'] as String?,
      tenantConfirmed: json['tenantConfirmed'] as bool? ?? false,
      employeeConfirmed: json['employeeConfirmed'] as bool? ?? false,
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
      budget: (json['budget'] as num?)?.toInt() ?? 0,
      source: json['source'] as String? ?? '',
      stage: json['stage'] != null
          ? LeadStage.fromString(json['stage'] as String)
          : LeadStage.nouveau,
      notes: json['notes'] as String? ?? '',
      tags: (json['tags'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
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
        'budget': budget,
        'source': source,
        'stage': stage.name,
        'notes': notes,
        'tags': tags,
        'lastContact': lastContact,
        'offers': offers.map((o) => o.toJson()).toList(),
        if (language != null) 'language': language,
        if (createdAt != null)
          'createdAt': (createdAt!).toIso8601String(),
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
    required this.number,
    required this.type,
    required this.bedrooms,
    required this.rent,
    required this.status,
    required this.leaseEnd,
    this.tenant,
  });

  // API fields
  final String? id;
  final String? buildingId;
  final List<String>? amenities;

  // Display fields
  final String number;
  final String type;
  final int bedrooms;
  final int rent;
  final String status;
  final String leaseEnd;
  final String? tenant;

  factory UnitItem.fromJson(Map<String, dynamic> json) {
    return UnitItem(
      id: json['id'] as String?,
      buildingId: json['buildingId'] as String?,
      number: json['number'] as String? ?? '',
      type: json['type'] as String? ?? '',
      bedrooms: (json['bedrooms'] as num?)?.toInt() ?? 0,
      rent: (json['rent'] as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? '',
      leaseEnd: json['leaseEnd'] as String? ?? '',
      tenant: json['tenant'] as String?,
      amenities: (json['amenities'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        if (buildingId != null) 'buildingId': buildingId,
        'number': number,
        'type': type,
        'bedrooms': bedrooms,
        'rent': rent,
        'status': status,
        'leaseEnd': leaseEnd,
        'tenant': tenant,
        if (amenities != null) 'amenities': amenities,
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
