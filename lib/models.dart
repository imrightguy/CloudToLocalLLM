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
// NotificationPreferences – user notification settings
// =============================================================================

class NotificationPreferences {
  const NotificationPreferences({
    this.emailNotifications = true,
    this.smsNotifications = false,
    this.weeklyDigest = true,
    this.quietHoursStart,
    this.quietHoursEnd,
    this.quietHoursEnabled = false,
  });

  final bool emailNotifications;
  final bool smsNotifications;
  final bool weeklyDigest;
  final TimeOfDay? quietHoursStart;
  final TimeOfDay? quietHoursEnd;
  final bool quietHoursEnabled;

  factory NotificationPreferences.fromJson(Map<String, dynamic> json) {
    TimeOfDay? parseTime(String? s) {
      if (s == null || s.isEmpty) return null;
      final parts = s.split(':');
      if (parts.length != 2) return null;
      final hour = int.tryParse(parts[0]);
      final minute = int.tryParse(parts[1]);
      if (hour == null || minute == null) return null;
      if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
      return TimeOfDay(hour: hour, minute: minute);
    }

    return NotificationPreferences(
      emailNotifications: json['emailNotifications'] as bool? ?? true,
      smsNotifications: json['smsNotifications'] as bool? ?? false,
      weeklyDigest: json['weeklyDigest'] as bool? ?? true,
      quietHoursStart: parseTime(json['quietHoursStart'] as String?),
      quietHoursEnd: parseTime(json['quietHoursEnd'] as String?),
      quietHoursEnabled: json['quietHoursEnabled'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'emailNotifications': emailNotifications,
        'smsNotifications': smsNotifications,
        'weeklyDigest': weeklyDigest,
        if (quietHoursStart != null)
          'quietHoursStart':
              '${quietHoursStart!.hour.toString().padLeft(2, '0')}:${quietHoursStart!.minute.toString().padLeft(2, '0')}',
        if (quietHoursEnd != null)
          'quietHoursEnd':
              '${quietHoursEnd!.hour.toString().padLeft(2, '0')}:${quietHoursEnd!.minute.toString().padLeft(2, '0')}',
        'quietHoursEnabled': quietHoursEnabled,
      };

  NotificationPreferences copyWith({
    bool? emailNotifications,
    bool? smsNotifications,
    bool? weeklyDigest,
    TimeOfDay? quietHoursStart,
    TimeOfDay? quietHoursEnd,
    bool? quietHoursEnabled,
    bool clearStart = false,
    bool clearEnd = false,
  }) {
    return NotificationPreferences(
      emailNotifications: emailNotifications ?? this.emailNotifications,
      smsNotifications: smsNotifications ?? this.smsNotifications,
      weeklyDigest: weeklyDigest ?? this.weeklyDigest,
      quietHoursStart: clearStart ? null : (quietHoursStart ?? this.quietHoursStart),
      quietHoursEnd: clearEnd ? null : (quietHoursEnd ?? this.quietHoursEnd),
      quietHoursEnabled: quietHoursEnabled ?? this.quietHoursEnabled,
    );
  }
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
    this.leadId,
    this.dateTime,
    this.leadName,
    this.tenantConfirmed = false,
    this.tenantConfirmationRequestedAt,
    this.tenantConfirmedAt,
    this.tenantDeclinedAt,
    this.employeeConfirmed = false,
    this.employeeConfirmationRequestedAt,
    this.employeeConfirmedAt,
    this.employeeDeclinedAt,
    this.occupantNotified = false,
    this.morningOfSent = false,
    this.morningReminderSentAt,
    this.reminder24hQueuedAt,
    this.reminder2hQueuedAt,
    this.occupantSMS,
    this.outcome,
    this.reasonCode,
    this.failureReasonCode,
    this.completedAt,
    this.cancelledAt,
    this.noShowAt,
    this.rescheduledAt,
    required this.unitLabel,
    required this.buildingName,
    required this.dateLabel,
    required this.status,
    required this.agent,
    required this.notes,
  });

  // API fields (optional)
  final String? id;
  final String? leadId;
  final DateTime? dateTime;
  final String? leadName;
  final bool tenantConfirmed;
  final DateTime? tenantConfirmationRequestedAt;
  final DateTime? tenantConfirmedAt;
  final DateTime? tenantDeclinedAt;
  final bool employeeConfirmed;
  final DateTime? employeeConfirmationRequestedAt;
  final DateTime? employeeConfirmedAt;
  final DateTime? employeeDeclinedAt;
  final bool occupantNotified;
  final bool morningOfSent;
  final DateTime? morningReminderSentAt;
  final DateTime? reminder24hQueuedAt;
  final DateTime? reminder2hQueuedAt;
  final Map<String, dynamic>? occupantSMS;
  final String? outcome;
  final String? reasonCode;
  final String? failureReasonCode;
  final DateTime? completedAt;
  final DateTime? cancelledAt;
  final DateTime? noShowAt;
  final DateTime? rescheduledAt;

  // Display fields (non-nullable, backward compat)
  final String unitLabel;
  final String buildingName;
  final String dateLabel;
  final String status;
  final String agent;
  final String notes;

  factory VisitItem.fromJson(Map<String, dynamic> json) {
    DateTime? parseNullableDate(dynamic value) {
      if (value == null) return null;
      return DateTime.parse(value as String);
    }

    String formatFrenchDate(DateTime dateTime) {
      const monthNames = [
        'janv.',
        'févr.',
        'mars',
        'avr.',
        'mai',
        'juin',
        'juil.',
        'août',
        'sept.',
        'oct.',
        'nov.',
        'déc.',
      ];
      final day = dateTime.day.toString().padLeft(2, '0');
      final month = monthNames[dateTime.month - 1];
      final year = dateTime.year.toString();
      return '$day $month $year';
    }

    final parsedDateTime = parseNullableDate(json['dateTime']);
    final explicitDateLabel = json['dateLabel'] as String?;
    final derivedDateLabel = parsedDateTime == null ? null : formatFrenchDate(parsedDateTime);

    return VisitItem(
      id: json['id'] as String?,
      leadId: json['leadId'] as String?,
      unitLabel: (json['unit'] is Map<String, dynamic>)
          ? (json['unit'] as Map<String, dynamic>)['label'] as String? ?? ''
          : json['unitLabel'] as String? ?? '',
      buildingName: (json['building'] is Map<String, dynamic>)
          ? (json['building'] as Map<String, dynamic>)['name'] as String? ?? ''
          : json['buildingName'] as String? ?? '',
      dateLabel: explicitDateLabel ?? derivedDateLabel ?? '',
      dateTime: parsedDateTime,
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
      tenantConfirmationRequestedAt: parseNullableDate(json['tenantConfirmationRequestedAt']),
      tenantConfirmedAt: parseNullableDate(json['tenantConfirmedAt']),
      tenantDeclinedAt: parseNullableDate(json['tenantDeclinedAt']),
      employeeConfirmed: json['employeeConfirmed'] as bool? ?? false,
      employeeConfirmationRequestedAt: parseNullableDate(json['employeeConfirmationRequestedAt']),
      employeeConfirmedAt: parseNullableDate(json['employeeConfirmedAt']),
      employeeDeclinedAt: parseNullableDate(json['employeeDeclinedAt']),
      occupantNotified: json['occupantNotified'] as bool? ?? false,
      morningOfSent: json['morningOfSent'] as bool? ?? false,
      morningReminderSentAt: parseNullableDate(json['morningReminderSentAt']),
      reminder24hQueuedAt: parseNullableDate(json['reminder24hQueuedAt']),
      reminder2hQueuedAt: parseNullableDate(json['reminder2hQueuedAt']),
      occupantSMS: json['occupantSMS'] as Map<String, dynamic>?,
      outcome: json['outcome'] as String?,
      reasonCode: json['reasonCode'] as String? ?? json['failureReasonCode'] as String?,
      failureReasonCode: json['failureReasonCode'] as String? ?? json['reasonCode'] as String?,
      completedAt: parseNullableDate(json['completedAt']),
      cancelledAt: parseNullableDate(json['cancelledAt']),
      noShowAt: parseNullableDate(json['noShowAt']),
      rescheduledAt: parseNullableDate(json['rescheduledAt']),
    );
  }

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        if (leadId != null) 'leadId': leadId,
        'unitLabel': unitLabel,
        'buildingName': buildingName,
        'dateLabel': dateLabel,
        if (dateTime != null) 'dateTime': dateTime!.toIso8601String(),
        'status': status,
        'agent': agent,
        'notes': notes,
        'leadName': leadName,
        'tenantConfirmed': tenantConfirmed,
        if (tenantConfirmationRequestedAt != null) 'tenantConfirmationRequestedAt': tenantConfirmationRequestedAt!.toIso8601String(),
        if (tenantConfirmedAt != null) 'tenantConfirmedAt': tenantConfirmedAt!.toIso8601String(),
        if (tenantDeclinedAt != null) 'tenantDeclinedAt': tenantDeclinedAt!.toIso8601String(),
        'employeeConfirmed': employeeConfirmed,
        if (employeeConfirmationRequestedAt != null) 'employeeConfirmationRequestedAt': employeeConfirmationRequestedAt!.toIso8601String(),
        if (employeeConfirmedAt != null) 'employeeConfirmedAt': employeeConfirmedAt!.toIso8601String(),
        if (employeeDeclinedAt != null) 'employeeDeclinedAt': employeeDeclinedAt!.toIso8601String(),
        'occupantNotified': occupantNotified,
        'morningOfSent': morningOfSent,
        if (morningReminderSentAt != null) 'morningReminderSentAt': morningReminderSentAt!.toIso8601String(),
        if (reminder24hQueuedAt != null) 'reminder24hQueuedAt': reminder24hQueuedAt!.toIso8601String(),
        if (reminder2hQueuedAt != null) 'reminder2hQueuedAt': reminder2hQueuedAt!.toIso8601String(),
        if (occupantSMS != null) 'occupantSMS': occupantSMS,
        if (outcome != null) 'outcome': outcome,
        if (reasonCode != null) 'reasonCode': reasonCode,
        if (failureReasonCode != null && reasonCode == null) 'failureReasonCode': failureReasonCode,
        if (completedAt != null) 'completedAt': completedAt!.toIso8601String(),
        if (cancelledAt != null) 'cancelledAt': cancelledAt!.toIso8601String(),
        if (noShowAt != null) 'noShowAt': noShowAt!.toIso8601String(),
        if (rescheduledAt != null) 'rescheduledAt': rescheduledAt!.toIso8601String(),
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
// Maintenance capacity planning
// =============================================================================

class MaintenanceTaskItem {
  const MaintenanceTaskItem({
    required this.id,
    required this.title,
    required this.status,
    this.buildingId,
    this.buildingName,
  });

  final String id;
  final String title;
  final String status;
  final String? buildingId;
  final String? buildingName;

  factory MaintenanceTaskItem.fromJson(Map<String, dynamic> json) {
    return MaintenanceTaskItem(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      status: json['status'] as String? ?? '',
      buildingId: json['buildingId'] as String?,
      buildingName: json['buildingName'] as String?,
    );
  }
}

class MaintenanceCapacityCandidate {
  const MaintenanceCapacityCandidate({
    required this.employee,
    required this.assignments,
    required this.schedules,
    required this.tasks,
    required this.openTaskCount,
    required this.buildingTaskCount,
    required this.fitScore,
    required this.fitLabel,
    required this.loadLabel,
    required this.canDispatch,
    required this.reasons,
  });

  final EmployeeItem employee;
  final List<BuildingAssignment> assignments;
  final List<ScheduleItem> schedules;
  final List<MaintenanceTaskItem> tasks;
  final int openTaskCount;
  final int buildingTaskCount;
  final int fitScore;
  final String fitLabel;
  final String loadLabel;
  final bool canDispatch;
  final List<String> reasons;

  factory MaintenanceCapacityCandidate.fromJson(Map<String, dynamic> json) {
    return MaintenanceCapacityCandidate(
      employee: EmployeeItem.fromJson(json['employee'] as Map<String, dynamic>),
      assignments: (json['assignments'] as List<dynamic>? ?? const [])
          .map((e) => BuildingAssignment.fromJson(e as Map<String, dynamic>))
          .toList(),
      schedules: (json['schedules'] as List<dynamic>? ?? const [])
          .map((e) => ScheduleItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      tasks: (json['tasks'] as List<dynamic>? ?? const [])
          .map((e) => MaintenanceTaskItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      openTaskCount: (json['openTaskCount'] as num?)?.toInt() ?? 0,
      buildingTaskCount: (json['buildingTaskCount'] as num?)?.toInt() ?? 0,
      fitScore: (json['fitScore'] as num?)?.toInt() ?? 0,
      fitLabel: json['fitLabel'] as String? ?? 'Faible',
      loadLabel: json['loadLabel'] as String? ?? 'Libre',
      canDispatch: json['canDispatch'] as bool? ?? false,
      reasons: (json['reasons'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
    );
  }
}

class MaintenanceCapacitySummary {
  const MaintenanceCapacitySummary({
    required this.totalCandidates,
    required this.dispatchableCount,
    required this.totalOpenTasks,
    required this.buildingOpenTasks,
  });

  final int totalCandidates;
  final int dispatchableCount;
  final int totalOpenTasks;
  final int buildingOpenTasks;

  factory MaintenanceCapacitySummary.fromJson(Map<String, dynamic> json) {
    return MaintenanceCapacitySummary(
      totalCandidates: (json['totalCandidates'] as num?)?.toInt() ?? 0,
      dispatchableCount: (json['dispatchableCount'] as num?)?.toInt() ?? 0,
      totalOpenTasks: (json['totalOpenTasks'] as num?)?.toInt() ?? 0,
      buildingOpenTasks: (json['buildingOpenTasks'] as num?)?.toInt() ?? 0,
    );
  }
}

class MaintenanceCapacityResult {
  const MaintenanceCapacityResult({
    required this.buildingId,
    required this.buildingName,
    required this.date,
    required this.dayOfWeek,
    required this.dayLabel,
    required this.candidates,
    required this.summary,
  });

  final String buildingId;
  final String buildingName;
  final String date;
  final int dayOfWeek;
  final String dayLabel;
  final List<MaintenanceCapacityCandidate> candidates;
  final MaintenanceCapacitySummary summary;

  factory MaintenanceCapacityResult.fromJson(Map<String, dynamic> json) {
    return MaintenanceCapacityResult(
      buildingId: json['buildingId'] as String? ?? '',
      buildingName: json['buildingName'] as String? ?? '',
      date: json['date'] as String? ?? '',
      dayOfWeek: (json['dayOfWeek'] as num?)?.toInt() ?? 0,
      dayLabel: json['dayLabel'] as String? ?? '',
      candidates: (json['candidates'] as List<dynamic>? ?? const [])
          .map((e) => MaintenanceCapacityCandidate.fromJson(e as Map<String, dynamic>))
          .toList(),
      summary: MaintenanceCapacitySummary.fromJson(
        (json['summary'] as Map<String, dynamic>? ?? const {}),
      ),
    );
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
// LeaseStatus
// =============================================================================

enum LeaseStatus {
  draft,
  sent,
  signed,
  active,
  terminated;

  static LeaseStatus fromString(String value) {
    final normalized = value.toLowerCase();
    if (normalized == 'draft' || normalized == 'brouillon') return LeaseStatus.draft;
    if (normalized == 'sent' || normalized == 'envoyé' || normalized == 'envoye') return LeaseStatus.sent;
    if (normalized == 'signed' || normalized == 'signé' || normalized == 'signe') return LeaseStatus.signed;
    if (normalized == 'active' || normalized == 'actif') return LeaseStatus.active;
    if (normalized == 'terminated' || normalized == 'résilié' || normalized == 'resilie') return LeaseStatus.terminated;
    return LeaseStatus.draft;
  }

  String get label {
    switch (this) {
      case LeaseStatus.draft:
        return 'Brouillon';
      case LeaseStatus.sent:
        return 'Envoyé';
      case LeaseStatus.signed:
        return 'Signé';
      case LeaseStatus.active:
        return 'Actif';
      case LeaseStatus.terminated:
        return 'Résilié';
    }
  }

  String get apiValue {
    switch (this) {
      case LeaseStatus.draft:
        return 'draft';
      case LeaseStatus.sent:
        return 'sent';
      case LeaseStatus.signed:
        return 'signed';
      case LeaseStatus.active:
        return 'active';
      case LeaseStatus.terminated:
        return 'terminated';
    }
  }

  Color get color {
    switch (this) {
      case LeaseStatus.draft:
        return const Color(0xFF6B7280);
      case LeaseStatus.sent:
        return const Color(0xFF3B82F6);
      case LeaseStatus.signed:
        return const Color(0xFF8B5CF6);
      case LeaseStatus.active:
        return const Color(0xFF10B981);
      case LeaseStatus.terminated:
        return const Color(0xFFEF4444);
    }
  }

  IconData get icon {
    switch (this) {
      case LeaseStatus.draft:
        return Icons.edit_note_outlined;
      case LeaseStatus.sent:
        return Icons.send_outlined;
      case LeaseStatus.signed:
        return Icons.draw_outlined;
      case LeaseStatus.active:
        return Icons.check_circle_outlined;
      case LeaseStatus.terminated:
        return Icons.cancel_outlined;
    }
  }

  int get orderIndex {
    switch (this) {
      case LeaseStatus.draft:
        return 0;
      case LeaseStatus.sent:
        return 1;
      case LeaseStatus.signed:
        return 2;
      case LeaseStatus.active:
        return 3;
      case LeaseStatus.terminated:
        return 4;
    }
  }
}

// =============================================================================
// LeaseItem
// =============================================================================

class LeaseItem {
  const LeaseItem({
    this.id,
    this.buildingId,
    this.buildingName,
    this.unitId,
    this.unitLabel,
    this.tenantName,
    this.tenantEmail,
    this.tenantPhone,
    this.startDate,
    this.endDate,
    this.monthlyRent,
    this.deposit,
    this.status,
    this.notes,
    this.terms,
    this.createdAt,
    this.updatedAt,
  });

  final String? id;
  final String? buildingId;
  final String? buildingName;
  final String? unitId;
  final String? unitLabel;
  final String? tenantName;
  final String? tenantEmail;
  final String? tenantPhone;
  final DateTime? startDate;
  final DateTime? endDate;
  final int? monthlyRent;
  final int? deposit;
  final LeaseStatus? status;
  final String? notes;
  final String? terms;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  LeaseStatus get leaseStatus => status ?? LeaseStatus.draft;

  String get displayRent {
    if (monthlyRent == null || monthlyRent == 0) return '--';
    return '${(monthlyRent! / 100).toStringAsFixed(2)} \$';
  }

  String get displayDeposit {
    if (deposit == null || deposit == 0) return '--';
    return '${(deposit! / 100).toStringAsFixed(2)} \$';
  }

  String get displayStartDate {
    if (startDate == null) return '--';
    return DateFormat('dd MMM yyyy', 'fr').format(startDate!);
  }

  String get displayEndDate {
    if (endDate == null) return '--';
    return DateFormat('dd MMM yyyy', 'fr').format(endDate!);
  }

  factory LeaseItem.fromJson(Map<String, dynamic> json) {
    DateTime? parsedStartDate;
    if (json['startDate'] != null) {
      try { parsedStartDate = DateTime.parse(json['startDate'] as String); } catch (_) {}
    }
    DateTime? parsedEndDate;
    if (json['endDate'] != null) {
      try { parsedEndDate = DateTime.parse(json['endDate'] as String); } catch (_) {}
    }
    DateTime? parsedCreatedAt;
    if (json['createdAt'] != null) {
      try { parsedCreatedAt = DateTime.parse(json['createdAt'] as String); } catch (_) {}
    }
    DateTime? parsedUpdatedAt;
    if (json['updatedAt'] != null) {
      try { parsedUpdatedAt = DateTime.parse(json['updatedAt'] as String); } catch (_) {}
    }

    return LeaseItem(
      id: json['id'] as String?,
      buildingId: json['buildingId'] as String?,
      buildingName: (json['building'] is Map<String, dynamic>)
          ? (json['building'] as Map<String, dynamic>)['name'] as String?
          : json['buildingName'] as String?,
      unitId: json['unitId'] as String?,
      unitLabel: (json['unit'] is Map<String, dynamic>)
          ? (json['unit'] as Map<String, dynamic>)['label'] as String?
          : json['unitLabel'] as String?,
      tenantName: (json['tenant'] is Map<String, dynamic>)
          ? (json['tenant'] as Map<String, dynamic>)['fullName'] as String?
          : json['tenantName'] as String?,
      tenantEmail: (json['tenant'] is Map<String, dynamic>)
          ? (json['tenant'] as Map<String, dynamic>)['email'] as String?
          : json['tenantEmail'] as String?,
      tenantPhone: (json['tenant'] is Map<String, dynamic>)
          ? (json['tenant'] as Map<String, dynamic>)['phone'] as String?
          : json['tenantPhone'] as String?,
      startDate: parsedStartDate,
      endDate: parsedEndDate,
      monthlyRent: (json['monthlyRent'] as num?)?.toInt(),
      deposit: (json['deposit'] as num?)?.toInt(),
      status: json['status'] != null
          ? LeaseStatus.fromString(json['status'] as String)
          : null,
      notes: json['notes'] as String?,
      terms: json['terms'] as String?,
      createdAt: parsedCreatedAt,
      updatedAt: parsedUpdatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        if (buildingId != null) 'buildingId': buildingId,
        if (unitId != null) 'unitId': unitId,
        if (tenantName != null) 'tenantName': tenantName,
        if (tenantEmail != null) 'tenantEmail': tenantEmail,
        if (tenantPhone != null) 'tenantPhone': tenantPhone,
        if (startDate != null) 'startDate': startDate!.toIso8601String(),
        if (endDate != null) 'endDate': endDate!.toIso8601String(),
        if (monthlyRent != null) 'monthlyRent': monthlyRent,
        if (deposit != null) 'deposit': deposit,
        if (status != null) 'status': status!.apiValue,
        if (notes != null) 'notes': notes,
        if (terms != null) 'terms': terms,
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

// =============================================================================
// CommunicationItem
// =============================================================================

class CommunicationItem {
  const CommunicationItem({
    this.id,
    required this.contactId,
    required this.contactName,
    required this.contactPhone,
    required this.contactInitials,
    required this.type,
    required this.direction,
    required this.status,
    required this.subject,
    required this.body,
    required this.createdAt,
    this.parentId,
  });

  final String? id;
  final String contactId;
  final String contactName;
  final String contactPhone;
  final String contactInitials;
  final String type;
  final String direction;
  final String status;
  final String subject;
  final String body;
  final DateTime createdAt;
  final String? parentId;

  factory CommunicationItem.fromJson(Map<String, dynamic> json) {
    DateTime? parsedCreatedAt;
    if (json['createdAt'] != null) {
      try {
        parsedCreatedAt = DateTime.parse(json['createdAt'] as String);
      } catch (_) {
        parsedCreatedAt = DateTime.now();
      }
    }

    final contactName = (json['contact'] is Map<String, dynamic>)
        ? (json['contact'] as Map<String, dynamic>)['fullName'] as String? ?? ''
        : json['contactName'] as String? ?? '';

    final contactPhone = (json['contact'] is Map<String, dynamic>)
        ? (json['contact'] as Map<String, dynamic>)['phone'] as String? ?? ''
        : json['contactPhone'] as String? ?? '';

    final nameParts = contactName
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    final initials = nameParts.length >= 2
        ? '${nameParts[0][0]}${nameParts[1][0]}'
        : nameParts.isNotEmpty
            ? nameParts[0].substring(0, nameParts[0].length > 1 ? 2 : 1)
            : '?';

    return CommunicationItem(
      id: json['id'] as String?,
      contactId: (json['contact'] is Map<String, dynamic>)
          ? (json['contact'] as Map<String, dynamic>)['id'] as String? ?? ''
          : json['contactId'] as String? ?? '',
      contactName: contactName,
      contactPhone: contactPhone,
      contactInitials: initials.toUpperCase(),
      type: json['type'] as String? ?? 'note',
      direction: json['direction'] as String? ?? 'outbound',
      status: json['status'] as String? ?? 'sent',
      subject: json['subject'] as String? ?? '',
      body: json['body'] as String? ?? json['content'] as String? ?? '',
      createdAt: parsedCreatedAt ?? DateTime.now(),
      parentId: json['parentId'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'contactId': contactId,
        'contactName': contactName,
        'contactPhone': contactPhone,
        'type': type,
        'direction': direction,
        'status': status,
        if (subject.isNotEmpty) 'subject': subject,
        'body': body,
        'createdAt': createdAt.toIso8601String(),
        if (parentId != null) 'parentId': parentId,
      };
}

class MarketplaceInboxThread {
  const MarketplaceInboxThread({
    this.leadId,
    required this.contactId,
    required this.contactName,
    required this.contactPhone,
    required this.contactInitials,
    this.qualificationState,
    this.qualificationReasonCode,
    this.qualificationReasonNote,
    required this.messageCount,
    required this.coordinationState,
    this.lastMessageAt,
    this.firstSeenAt,
    this.firstResponseAt,
    this.firstResponseDelayMinutes,
    this.latestVisit,
    this.lastMessage,
  });

  final String? leadId;
  final String contactId;
  final String contactName;
  final String contactPhone;
  final String contactInitials;
  final String? qualificationState;
  final String? qualificationReasonCode;
  final String? qualificationReasonNote;
  final int messageCount;
  final String coordinationState;
  final DateTime? lastMessageAt;
  final DateTime? firstSeenAt;
  final DateTime? firstResponseAt;
  final int? firstResponseDelayMinutes;
  final VisitItem? latestVisit;
  final CommunicationItem? lastMessage;

  bool get needsResponse => firstResponseAt == null;

  factory MarketplaceInboxThread.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      try {
        return DateTime.parse(value as String);
      } catch (_) {
        return null;
      }
    }

    final lastMessageJson = json['lastMessage'];
    final visitJson = json['latestVisit'];
    final contactName = json['contactName'] as String? ?? '';
    final nameParts = contactName
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    final initials = nameParts.isNotEmpty
        ? nameParts.take(2).map((part) => part[0]).join().toUpperCase()
        : '?';

    return MarketplaceInboxThread(
      leadId: json['leadId'] as String? ?? json['contactId'] as String?,
      contactId: json['contactId'] as String? ?? '',
      contactName: contactName,
      contactPhone: json['contactPhone'] as String? ?? '',
      contactInitials: json['contactInitials'] as String? ?? initials,
      qualificationState: json['qualificationState'] as String?,
      qualificationReasonCode: json['qualificationReasonCode'] as String?,
      qualificationReasonNote: json['qualificationReasonNote'] as String?,
      messageCount: (json['messageCount'] as num?)?.toInt() ?? 0,
      coordinationState: json['coordinationState'] as String? ?? 'message_only',
      lastMessageAt: parseDate(json['lastMessageAt']),
      firstSeenAt: parseDate(json['firstSeenAt']),
      firstResponseAt: parseDate(json['firstResponseAt']),
      firstResponseDelayMinutes: (json['firstResponseDelayMinutes'] as num?)?.toInt(),
      latestVisit: visitJson is Map<String, dynamic>
          ? VisitItem.fromJson(visitJson)
          : null,
      lastMessage: lastMessageJson is Map<String, dynamic>
          ? CommunicationItem.fromJson(lastMessageJson)
          : null,
    );
  }
}

// =============================================================================
// ConversationThread
// =============================================================================

class ConversationThread {
  ConversationThread({
    required this.contactId,
    required this.contactName,
    required this.contactPhone,
    required this.contactInitials,
    required this.messages,
  });

  final String contactId;
  final String contactName;
  final String contactPhone;
  final String contactInitials;
  final List<CommunicationItem> messages;

  CommunicationItem? get lastMessage =>
      messages.isNotEmpty ? messages.first : null;
}

// =============================================================================
// SmsScheduleRequest
// =============================================================================

class SmsScheduleRequest {
  SmsScheduleRequest({
    required this.contactId,
    required this.message,
    this.scheduledAt,
    this.templateId,
  });

  final String contactId;
  final String message;
  final DateTime? scheduledAt;
  final String? templateId;

  Map<String, dynamic> toJson() => {
        'contactId': contactId,
        'message': message,
        if (scheduledAt != null) 'scheduledAt': scheduledAt!.toIso8601String(),
        if (templateId != null) 'templateId': templateId,
      };
}

// =============================================================================
// SmsDeliveryStatus
// =============================================================================

enum SmsDeliveryStatus {
  queued,
  sent,
  delivered,
  read,
  failed;

  static SmsDeliveryStatus fromString(String value) {
    final normalized = value.toLowerCase();
    switch (normalized) {
      case 'queued':
        return SmsDeliveryStatus.queued;
      case 'sent':
        return SmsDeliveryStatus.sent;
      case 'delivered':
        return SmsDeliveryStatus.delivered;
      case 'read':
        return SmsDeliveryStatus.read;
      case 'failed':
        return SmsDeliveryStatus.failed;
      default:
        return SmsDeliveryStatus.queued;
    }
  }

  String get label {
    switch (this) {
      case SmsDeliveryStatus.queued:
        return 'En attente';
      case SmsDeliveryStatus.sent:
        return 'Envoyé';
      case SmsDeliveryStatus.delivered:
        return 'Livré';
      case SmsDeliveryStatus.read:
        return 'Lu';
      case SmsDeliveryStatus.failed:
        return 'Échoué';
    }
  }
}

// =============================================================================
// SmsMessage
// =============================================================================

class SmsMessage {
  const SmsMessage({
    this.id,
    required this.contactId,
    required this.direction,
    required this.body,
    required this.status,
    required this.createdAt,
    this.errorCode,
    this.errorMessage,
  });

  final String? id;
  final String contactId;
  final String direction;
  final String body;
  final SmsDeliveryStatus status;
  final DateTime createdAt;
  final String? errorCode;
  final String? errorMessage;

  bool get isInbound => direction == 'inbound';
  bool get isOutbound => direction == 'outbound';
  bool get isFailed => status == SmsDeliveryStatus.failed;

  factory SmsMessage.fromJson(Map<String, dynamic> json) {
    DateTime? parsedCreatedAt;
    if (json['createdAt'] != null || json['sentAt'] != null) {
      try {
        parsedCreatedAt = DateTime.parse(
          (json['createdAt'] ?? json['sentAt']) as String,
        );
      } catch (_) {
        parsedCreatedAt = DateTime.now();
      }
    }

    return SmsMessage(
      id: json['id'] as String?,
      contactId: (json['contactId'] as String?) ?? '',
      direction: json['direction'] as String? ?? 'outbound',
      body: json['body'] as String? ?? json['content'] as String? ?? '',
      status: SmsDeliveryStatus.fromString(
        json['status'] as String? ?? json['deliveryStatus'] as String? ?? 'queued',
      ),
      createdAt: parsedCreatedAt ?? DateTime.now(),
      errorCode: json['errorCode'] as String?,
      errorMessage: json['errorMessage'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'contactId': contactId,
        'direction': direction,
        'body': body,
        'status': status.name,
        'createdAt': createdAt.toIso8601String(),
        if (errorCode != null) 'errorCode': errorCode,
        if (errorMessage != null) 'errorMessage': errorMessage,
      };
}

// =============================================================================
// QuickReply
// =============================================================================

class QuickReply {
  const QuickReply({
    required this.label,
    required this.message,
    this.icon,
  });

  final String label;
  final String message;
  final IconData? icon;
}

// =============================================================================
// PaymentStatus
// =============================================================================

enum PaymentStatus {
  paid,
  pending,
  late,
  partial,
  failed;

  static PaymentStatus fromString(String value) {
    final normalized = value.toLowerCase();
    switch (normalized) {
      case 'paid':
        return PaymentStatus.paid;
      case 'pending':
        return PaymentStatus.pending;
      case 'late':
        return PaymentStatus.late;
      case 'partial':
        return PaymentStatus.partial;
      case 'failed':
        return PaymentStatus.failed;
      default:
        return PaymentStatus.pending;
    }
  }

  String get label {
    switch (this) {
      case PaymentStatus.paid:
        return 'Payé';
      case PaymentStatus.pending:
        return 'En attente';
      case PaymentStatus.late:
        return 'En retard';
      case PaymentStatus.partial:
        return 'Partiel';
      case PaymentStatus.failed:
        return 'Échoué';
    }
  }

  Color get color {
    switch (this) {
      case PaymentStatus.paid:
        return const Color(0xFF10B981);
      case PaymentStatus.pending:
        return const Color(0xFF3B82F6);
      case PaymentStatus.late:
        return const Color(0xFFEF4444);
      case PaymentStatus.partial:
        return const Color(0xFFF59E0B);
      case PaymentStatus.failed:
        return const Color(0xFF94A3B8);
    }
  }
}

// =============================================================================
// PaymentItem
// =============================================================================

class PaymentItem {
  const PaymentItem({
    this.id,
    this.leaseId,
    this.buildingId,
    this.unitId,
    this.tenantId,
    required this.amount,
    required this.amountPaid,
    required this.dueDate,
    required this.paidAt,
    required this.status,
    required this.method,
    required this.tenantName,
    required this.unitLabel,
    required this.buildingName,
    required this.periodLabel,
    this.notes,
    this.createdAt,
  });

  final String? id;
  final String? leaseId;
  final String? buildingId;
  final String? unitId;
  final String? tenantId;
  final int amount;
  final int amountPaid;
  final String dueDate;
  final String paidAt;
  final PaymentStatus status;
  final String method;
  final String tenantName;
  final String unitLabel;
  final String buildingName;
  final String periodLabel;
  final String? notes;
  final DateTime? createdAt;

  int get outstanding => amount - amountPaid;

  bool get isPaid => status == PaymentStatus.paid;

  factory PaymentItem.fromJson(Map<String, dynamic> json) {
    return PaymentItem(
      id: json['id'] as String?,
      leaseId: json['leaseId'] as String?,
      buildingId: json['buildingId'] as String?,
      unitId: json['unitId'] as String?,
      tenantId: json['tenantId'] as String?,
      amount: (json['amountCents'] as num?)?.toInt() ?? 0,
      amountPaid: (json['amountPaidCents'] as num?)?.toInt() ?? 0,
      dueDate: json['dueDate'] as String? ?? '',
      paidAt: json['paidAt'] as String? ?? '',
      status: PaymentStatus.fromString(json['status'] as String? ?? ''),
      method: json['method'] as String? ?? '',
      tenantName: json['tenantName'] as String? ?? '',
      unitLabel: json['unitLabel'] as String? ?? '',
      buildingName: json['buildingName'] as String? ?? '',
      periodLabel: json['periodLabel'] as String? ?? '',
      notes: json['notes'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        if (leaseId != null) 'leaseId': leaseId,
        if (buildingId != null) 'buildingId': buildingId,
        if (unitId != null) 'unitId': unitId,
        if (tenantId != null) 'tenantId': tenantId,
        'amountCents': amount,
        'amountPaidCents': amountPaid,
        'dueDate': dueDate,
        'paidAt': paidAt,
        'status': status.name,
        'method': method,
        'tenantName': tenantName,
        'unitLabel': unitLabel,
        'buildingName': buildingName,
        'periodLabel': periodLabel,
        if (notes != null) 'notes': notes,
        if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      };
}
