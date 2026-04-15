import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:immogestion/models.dart';
import 'package:immogestion/services/payment_service.dart';

void main() {
  group('PaymentStatus', () {
    test('fromString parses all known statuses', () {
      expect(PaymentStatus.fromString('paid'), PaymentStatus.paid);
      expect(PaymentStatus.fromString('pending'), PaymentStatus.pending);
      expect(PaymentStatus.fromString('late'), PaymentStatus.late);
      expect(PaymentStatus.fromString('partial'), PaymentStatus.partial);
      expect(PaymentStatus.fromString('failed'), PaymentStatus.failed);
    });

    test('fromString defaults to pending for unknown values', () {
      expect(PaymentStatus.fromString(''), PaymentStatus.pending);
      expect(PaymentStatus.fromString('unknown'), PaymentStatus.pending);
    });

    test('labels are in French', () {
      expect(PaymentStatus.paid.label, 'Payé');
      expect(PaymentStatus.pending.label, 'En attente');
      expect(PaymentStatus.late.label, 'En retard');
      expect(PaymentStatus.partial.label, 'Partiel');
      expect(PaymentStatus.failed.label, 'Échoué');
    });

    test('colors are distinct', () {
      expect(PaymentStatus.paid.color, const Color(0xFF10B981));
      expect(PaymentStatus.pending.color, const Color(0xFF3B82F6));
      expect(PaymentStatus.late.color, const Color(0xFFEF4444));
      expect(PaymentStatus.partial.color, const Color(0xFFF59E0B));
      expect(PaymentStatus.failed.color, const Color(0xFF94A3B8));
    });
  });

  group('PaymentItem', () {
    test('fromJson parses all fields', () {
      final json = {
        'id': 'p1',
        'leaseId': 'l1',
        'buildingId': 'b1',
        'unitId': 'u1',
        'tenantId': 't1',
        'amountCents': 120000,
        'amountPaidCents': 120000,
        'dueDate': '2026-01-01',
        'paidAt': '2025-12-28',
        'status': 'paid',
        'method': 'credit_card',
        'tenantName': 'Jean Dupont',
        'unitLabel': '4A',
        'buildingName': 'Le Saint-Laurent',
        'periodLabel': 'Janvier 2026',
        'notes': 'Paiement à temps',
      };
      final payment = PaymentItem.fromJson(json);
      expect(payment.id, 'p1');
      expect(payment.amount, 120000);
      expect(payment.amountPaid, 120000);
      expect(payment.dueDate, '2026-01-01');
      expect(payment.status, PaymentStatus.paid);
      expect(payment.method, 'credit_card');
      expect(payment.tenantName, 'Jean Dupont');
      expect(payment.unitLabel, '4A');
      expect(payment.buildingName, 'Le Saint-Laurent');
      expect(payment.periodLabel, 'Janvier 2026');
      expect(payment.notes, 'Paiement à temps');
    });

    test('fromJson defaults missing fields', () {
      final payment = PaymentItem.fromJson({});
      expect(payment.id, isNull);
      expect(payment.amount, 0);
      expect(payment.amountPaid, 0);
      expect(payment.dueDate, '');
      expect(payment.paidAt, '');
      expect(payment.status, PaymentStatus.pending);
      expect(payment.method, '');
      expect(payment.tenantName, '');
      expect(payment.unitLabel, '');
      expect(payment.buildingName, '');
      expect(payment.periodLabel, '');
      expect(payment.notes, isNull);
    });

    test('outstanding calculates correctly', () {
      const paid = PaymentItem(
        amount: 120000,
        amountPaid: 120000,
        dueDate: '',
        paidAt: '',
        status: PaymentStatus.paid,
        method: '',
        tenantName: '',
        unitLabel: '',
        buildingName: '',
        periodLabel: '',
      );
      expect(paid.outstanding, 0);
      expect(paid.isPaid, true);

      const partial = PaymentItem(
        amount: 120000,
        amountPaid: 80000,
        dueDate: '',
        paidAt: '',
        status: PaymentStatus.partial,
        method: '',
        tenantName: '',
        unitLabel: '',
        buildingName: '',
        periodLabel: '',
      );
      expect(partial.outstanding, 40000);
      expect(partial.isPaid, false);
    });

    test('toJson round-trips', () {
      final original = PaymentItem(
        id: 'p1',
        leaseId: 'l1',
        buildingId: 'b1',
        amount: 90000,
        amountPaid: 90000,
        dueDate: '2026-02-01',
        paidAt: '2026-01-30',
        status: PaymentStatus.paid,
        method: 'virement',
        tenantName: 'Marie Tremblay',
        unitLabel: '2B',
        buildingName: 'Le Plateau',
        periodLabel: 'Février 2026',
        notes: null,
      );
      final json = original.toJson();
      final restored = PaymentItem.fromJson(json);
      expect(restored.id, original.id);
      expect(restored.amount, original.amount);
      expect(restored.status, PaymentStatus.paid);
      expect(restored.tenantName, original.tenantName);
    });
  });

  group('PaymentService', () {
    test('singleton instance is stable', () {
      expect(
        identical(PaymentService.instance, PaymentService.instance),
        true,
      );
    });
  });
}
