import 'package:flutter/material.dart';

import '../models.dart';
import '../services/payment_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/immo_app_bar.dart';
import 'payment_detail_screen.dart';

class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({super.key});

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  List<PaymentItem> _payments = [];
  List<PaymentItem> _filteredPayments = [];
  bool _isLoading = true;
  String? _errorMessage;
  PaymentStatus? _filterStatus;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final payments = await PaymentService.instance.getPayments();
      setState(() {
        _payments = payments;
        _filteredPayments = List.of(_payments);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  void _applyFilter() {
    setState(() {
      if (_filterStatus == null) {
        _filteredPayments = List.of(_payments);
      } else {
        _filteredPayments =
            _payments.where((p) => p.status == _filterStatus).toList();
      }
    });
  }

  int _countByStatus(PaymentStatus status) =>
      _payments.where((p) => p.status == status).length;

  int _totalCollected() =>
      _payments.where((p) => p.isPaid).fold<int>(0, (s, p) => s + p.amountPaid);

  int _totalOutstanding() =>
      _payments.fold<int>(0, (s, p) => s + p.outstanding);

  String _formatCents(int cents) {
    final dollars = (cents / 100).toStringAsFixed(2);
    return '$dollars \$';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const ImmoAppBar(title: 'Paiements'),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: AppSpacing.lg),
            Text('Impossible de charger les paiements',
                style: AppTypography.body),
            const SizedBox(height: AppSpacing.sm),
            Text(_errorMessage!,
                style: AppTypography.caption, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Summary cards
            _buildSummaryRow(),
            const SizedBox(height: AppSpacing.xl),

            // Status filter chips
            _buildFilterChips(),
            const SizedBox(height: AppSpacing.xl),

            // Payments list
            if (_filteredPayments.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      const Icon(Icons.receipt_long_outlined,
                          size: 48, color: AppColors.textMuted),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        _payments.isEmpty
                            ? 'Aucun paiement enregistré'
                            : 'Aucun paiement ne correspond au filtre',
                        style: AppTypography.caption,
                        textAlign: TextAlign.center,
                      ),
                      if (_filterStatus != null) ...[
                        const SizedBox(height: AppSpacing.md),
                        TextButton(
                          onPressed: () {
                            setState(() => _filterStatus = null);
                            _applyFilter();
                          },
                          child: const Text('Effacer le filtre'),
                        ),
                      ],
                    ],
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _filteredPayments.length,
                itemBuilder: (context, index) {
                  return _buildPaymentCard(_filteredPayments[index]);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow() {
    return Row(
      children: [
        _buildSummaryChip(
          label: 'Total perçu',
          value: _formatCents(_totalCollected()),
          color: AppColors.success,
          icon: Icons.check_circle_outline,
        ),
        const SizedBox(width: AppSpacing.sm),
        _buildSummaryChip(
          label: 'En attente',
          value: _formatCents(_totalOutstanding()),
          color: AppColors.warning,
          icon: Icons.schedule_outlined,
        ),
      ],
    );
  }

  Widget _buildSummaryChip({
    required String label,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: AppSpacing.cardDecoration(),
        child: Column(
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: AppSpacing.sm),
                Text(label, style: AppTypography.caption),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(value,
                style: AppTypography.kpiValue.copyWith(fontSize: 20, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildFilterChip(
            label: 'Tous (${_payments.length})',
            status: null,
          ),
          const SizedBox(width: AppSpacing.sm),
          _buildFilterChip(
            label: 'Payé (${_countByStatus(PaymentStatus.paid)})',
            status: PaymentStatus.paid,
          ),
          const SizedBox(width: AppSpacing.sm),
          _buildFilterChip(
            label: 'En attente (${_countByStatus(PaymentStatus.pending)})',
            status: PaymentStatus.pending,
          ),
          const SizedBox(width: AppSpacing.sm),
          _buildFilterChip(
            label: 'En retard (${_countByStatus(PaymentStatus.late)})',
            status: PaymentStatus.late,
          ),
          const SizedBox(width: AppSpacing.sm),
          _buildFilterChip(
            label: 'Partiel (${_countByStatus(PaymentStatus.partial)})',
            status: PaymentStatus.partial,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required PaymentStatus? status,
  }) {
    final isSelected = _filterStatus == status;
    final color = status?.color ?? AppColors.textSecondary;
    return GestureDetector(
      onTap: () {
        setState(() {
          _filterStatus = isSelected ? null : status;
        });
        _applyFilter();
      },
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.1) : AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
          border: Border.all(
            color: isSelected ? color : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.chipLabel.copyWith(
            color: isSelected ? color : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentCard(PaymentItem payment) {
    final status = payment.status;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => PaymentDetailScreen(payment: payment),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: AppSpacing.cardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: status.color.withValues(alpha: 0.1),
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusSm),
                    ),
                    child: Icon(
                      status == PaymentStatus.paid
                          ? Icons.check_circle_outline
                          : status == PaymentStatus.late
                              ? Icons.warning_amber_rounded
                              : status == PaymentStatus.pending
                                  ? Icons.schedule_outlined
                                  : status == PaymentStatus.partial
                                      ? Icons.remove_circle_outline
                                      : Icons.error_outline,
                      color: status.color,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          payment.tenantName.isNotEmpty
                              ? payment.tenantName
                              : 'Locataire inconnu',
                          style: AppTypography.cardTitle,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${payment.unitLabel} — ${payment.buildingName}',
                          style: AppTypography.caption,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: status.color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      status.label,
                      style: TextStyle(
                        fontSize: 11,
                        color: status.color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Text(
                    _formatCents(payment.amount),
                    style: AppTypography.cardTitle.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const Spacer(),
                  if (payment.outstanding > 0) ...[
                    Text(
                      'Reste: ',
                      style: AppTypography.caption,
                    ),
                    Text(
                      _formatCents(payment.outstanding),
                      style: AppTypography.caption.copyWith(
                        color: AppColors.error,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  const Icon(Icons.calendar_today_outlined,
                      size: 14, color: AppColors.textMuted),
                  const SizedBox(width: 4),
                  Text(
                    'Échéance: ${payment.dueDate}',
                    style: AppTypography.caption,
                  ),
                  const Spacer(),
                  if (payment.periodLabel.isNotEmpty)
                    Text(
                      payment.periodLabel,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
