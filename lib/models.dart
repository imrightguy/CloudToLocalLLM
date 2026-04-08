import 'package:flutter/material.dart';

enum LeadStage {
  nouveau,
  contacte,
  qualifie,
  visitePlanifiee,
  offreEnvoyee,
  negociation,
  bailSigne,
}

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

class AlertItem {
  const AlertItem({required this.label, required this.severity});

  final String label;
  final String severity;
}

class VisitItem {
  const VisitItem({
    required this.unitLabel,
    required this.buildingName,
    required this.dateLabel,
    required this.status,
    required this.agent,
    required this.notes,
  });

  final String unitLabel;
  final String buildingName;
  final String dateLabel;
  final String status;
  final String agent;
  final String notes;
}

class OfferItem {
  const OfferItem({required this.amount, required this.status, required this.sentAt});

  final int amount;
  final String status;
  final String sentAt;
}

class LeadItem {
  const LeadItem({
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
}

class UnitItem {
  const UnitItem({
    required this.number,
    required this.type,
    required this.bedrooms,
    required this.rent,
    required this.status,
    required this.leaseEnd,
    this.tenant,
  });

  final String number;
  final String type;
  final int bedrooms;
  final int rent;
  final String status;
  final String leaseEnd;
  final String? tenant;
}

class BuildingItem {
  const BuildingItem({
    required this.name,
    required this.address,
    required this.city,
    required this.totalUnits,
    required this.occupiedUnits,
    required this.monthlyRevenue,
    required this.units,
  });

  final String name;
  final String address;
  final String city;
  final int totalUnits;
  final int occupiedUnits;
  final int monthlyRevenue;
  final List<UnitItem> units;

  double get occupancyRate => occupiedUnits / totalUnits;
}