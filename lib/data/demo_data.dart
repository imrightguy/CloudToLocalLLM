import 'package:flutter/material.dart';

import '../models.dart';

const stats = <StatCard>[
  StatCard(
    title: 'Taux d\'occupation',
    value: '45 / 48',
    delta: '+3 unités relouées',
    description: '93,8 % du parc actuellement occupé',
  ),
  StatCard(
    title: 'Loyers mensuels',
    value: '77 480 \$',
    delta: '+4,6 % vs février',
    description: 'Encaissement projeté au prochain cycle',
  ),
  StatCard(
    title: 'Leads actifs',
    value: '24',
    delta: '9 très chauds',
    description: 'Prospects suivis pour avril à juillet',
  ),
  StatCard(
    title: 'Visites cette semaine',
    value: '14',
    delta: '5 confirmées demain',
    description: 'Visites planifiées ou déjà confirmées',
  ),
];

const activityFeed = <ActivityItem>[
  ActivityItem(
    title: 'Bail signé pour le 223',
    detail: 'Résidences du Parc · David Côté · entrée 1er mai',
    time: 'Il y a 1 h',
    color: Color(0xFF10B981),
  ),
  ActivityItem(
    title: 'Visite confirmée demain 10h00',
    detail: 'Le Saint-Laurent · 4 1/2 - 302 · Sophie Tremblay',
    time: 'Il y a 2 h',
    color: Color(0xFF38BDF8),
  ),
  ActivityItem(
    title: 'Offre en attente de retour',
    detail: 'Mélissa Ouellet négocie le 4 1/2 - 507 à 1 895 \$',
    time: 'Aujourd\'hui',
    color: Color(0xFFF59E0B),
  ),
  ActivityItem(
    title: 'Nouvelle lead - Émilie B.',
    detail: '3 1/2 - Rue Sherbrooke - téléphone reçu',
    time: 'Aujourd\'hui',
    color: Color(0xFF6366F1),
  ),
];

const buildingItems = <BuildingItem>[
  BuildingItem(
    name: 'Le Saint-Laurent',
    address: '305 Rue Sherbrooke Ouest',
    city: 'Montréal',
    totalUnits: 24,
    occupiedUnits: 23,
    monthlyRevenue: 36000,
    units: [
      UnitItem(
        number: '302',
        type: '4 1/2',
        bedrooms: 4,
        rent: 1850,
        status: 'occupé',
        leaseEnd: '31/12/2024',
        tenant: 'Sophie Tremblay',
      ),
      UnitItem(
        number: '201',
        type: '3 1/2',
        bedrooms: 3,
        rent: 1450,
        status: 'libre',
        leaseEnd: '',
      ),
    ],
  ),
  BuildingItem(
    name: 'Résidences du Parc',
    address: '415 Rue de la Montagne',
    city: 'Montréal',
    totalUnits: 18,
    occupiedUnits: 17,
    monthlyRevenue: 28000,
    units: [
      UnitItem(
        number: '223',
        type: '5 1/2',
        bedrooms: 5,
        rent: 2100,
        status: 'occupé',
        leaseEnd: '31/05/2024',
        tenant: 'David Côté',
      ),
    ],
  ),
];

const leadItems = <LeadItem>[
  LeadItem(
    fullName: 'Émilie Beaudoin',
    email: 'emilie.beaudoin@email.com',
    phone: '514-555-0123',
    desiredUnit: '3 1/2 - Rue Sherbrooke',
    budget: 1600,
    source: 'FB',
    stage: LeadStage.qualifie,
    notes: 'Intéressée par le 3 1/2 - disponible en mai',
    tags: ['très chaud', 'professionnel'],
    lastContact: 'Il y a 2 jours',
    offers: [
      OfferItem(amount: 1580, status: 'envoyée', sentAt: '3 jours'),
    ],
  ),
  LeadItem(
    fullName: 'Alexandre Martin',
    email: 'alex.martin@gmail.com',
    phone: '418-555-0456',
    desiredUnit: '4 1/2 - Rue de la Montagne',
    budget: 1900,
    source: 'Annonce',
    stage: LeadStage.visitePlanifiee,
    notes: 'Visite programmée pour demain 14h00',
    tags: ['confiance'],
    lastContact: 'Aujourd\'hui',
    offers: [],
  ),
];