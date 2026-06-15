#!/usr/bin/env python3
"""Patches leads_screen.dart and payments_screen.dart with new loading/error/empty widget patterns."""
import os

SCREENS_DIR = r'C:\Users\SimonGravel\ImmoGestion\lib\screens'

LEADS_SCREEN = r"""import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models.dart';
import '../services/hermes_service.dart';
import '../services/lead_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../widgets/immo_app_bar.dart';
import '../widgets/loading_state.dart';
import '../widgets/error_state.dart';
import '../widgets/empty_state.dart';

class LeadsScreen extends StatefulWidget {
  const LeadsScreen({super.key});

  @override
  State<LeadsScreen> createState() => _LeadsScreenState();
}

class _LeadsScreenState extends State<LeadsScreen> {
  bool _isLoading = true;
  Object? _lastError;
  List<LeadItem> _leads = [];

  LeadStage? _stageFilter;
  String _sourceFilter = '_all';
  String _search = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchLeads();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchLeads() async {
    setState(() {
      _isLoading = true;
      _lastError = null;
    });
    try {
      final result = await LeadService.instance.getLeads(
        stage: _stageFilter,
        search: _search.isEmpty ? null : _search,
        limit: 100,
        forceRefresh: true,
      );
      setState(() {
        _leads = result.items;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _lastError = e;
        _isLoading = false;
      });
    }
  }

  List<String> get _sources {
    final set = <String>{};
    for (final l in _leads) {
      if (l.source.isNotEmpty) set.add(l.source);
    }
    final list = set.toList()..sort();
    return list;
  }

  List<LeadItem> get _filteredLeads {
    if (_sourceFilter == '_all') return _leads;
    return _leads.where((l) => l.source == _sourceFilter).toList();
  }

  Future<void> _qualifyWithHermes(LeadItem lead) async {
    if (lead.id == null) return;
    try {
      final notified = await HermesService.instance.notifyLead(lead.id!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(notified
              ? 'Hermes notifie pour ${lead.fullName}'
              : 'Hermes non configure - notification ignoree'),
          backgroundColor: notified ? AppColors.success : AppColors.warning,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const ImmoAppBar(title: 'Pistes'),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const ListSkeleton(showSearchBar: true);
    if (_lastError != null) return ErrorState(error: _lastError!, onRetry: _fetchLeads);
    if (_leads.isEmpty) {
      return const EmptyState(
        title: 'Aucune piste',
        description: 'Les pistes de locataires potentiels apparaitront ici.',
        icon: Icons.person_add_alt_outlined,
      );
    }

    final leads = _filteredLeads;

    return Column(
      children: [
        _buildFilters(),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _fetchLeads,
            child: leads.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      SizedBox(height: 120),
                      Center(
                        child: Text(
                          'Aucune piste',
                          style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                        ),
                      ),
                    ],
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: leads.length,
                    itemBuilder: (context, index) => _buildLeadCard(leads[index]),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.md, AppSpacing.md, 0),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Rechercher par nom...',
              prefixIcon: const Icon(Icons.search),
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              ),
            ),
            onSubmitted: (value) {
              _search = value.trim();
              _fetchLeads();
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _stageChip(null, 'Tous'),
                ...LeadStage.values.map((s) => _stageChip(s, s.label)),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              const Icon(Icons.filter_list, size: 18, color: AppColors.textSecondary),
              const SizedBox(width: AppSpacing.sm),
              const Text('Source:', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: DropdownButton<String>(
                  value: _sourceFilter,
                  isExpanded: true,
                  isDense: true,
                  items: [
                    const DropdownMenuItem(value: '_all', child: Text('Toutes')),
                    ..._sources.map((s) => DropdownMenuItem(value: s, child: Text(s))),
                  ],
                  onChanged: (value) {
                    setState(() => _sourceFilter = value ?? '_all');
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stageChip(LeadStage? stage, String label) {
    final selected = _stageFilter == stage;
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.sm),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) {
          setState(() => _stageFilter = stage);
          _fetchLeads();
        },
      ),
    );
  }

  Widget _buildLeadCard(LeadItem lead) {
    final budgetLabel = lead.budget > 0
        ? '${(lead.budget / 100).toStringAsFixed(0)} \$'
        : null;
    final createdLabel = lead.createdAt != null
        ? DateFormat('d MMM yyyy', 'fr').format(lead.createdAt!)
        : null;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: InkWell(
        onTap: () {
          if (lead.id != null) {
            Navigator.of(context).pushNamed('/leads/${lead.id}');
          }
        },
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      lead.fullName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                    ),
                    child: Text(
                      lead.stage.label,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: AppSpacing.md,
                runSpacing: 4,
                children: [
                  if (lead.source.isNotEmpty)
                    _metaChip(Icons.campaign_outlined, lead.source),
                  if (lead.phone.isNotEmpty)
                    _metaChip(Icons.phone_outlined, lead.phone),
                  if (budgetLabel != null)
                    _metaChip(Icons.attach_money, budgetLabel),
                  if (createdLabel != null)
                    _metaChip(Icons.calendar_today_outlined, createdLabel),
                ],
              ),
              if (lead.desiredUnit.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  lead.desiredUnit,
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _qualifyWithHermes(lead),
                  icon: const Icon(Icons.smart_toy_outlined, size: 18),
                  label: const Text('Qualifier (Hermes)'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _metaChip(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.textMuted),
        const SizedBox(width: 3),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}
"""

PAYMENTS_SCREEN = r"""import 'package:flutter/material.dart';

import '../models.dart';
import '../services/payment_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/immo_app_bar.dart';
import '../widgets/loading_state.dart';
import '../widgets/error_state.dart';
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
  Object? _lastError;
  PaymentStatus? _filterStatus;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _lastError = null;
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
        _lastError = e;
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
    if (_isLoading) return const ListSkeleton(showSearchBar: false);
    if (_lastError != null) return ErrorState(error: _lastError!, onRetry: _loadData);

    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSummaryRow(),
            const SizedBox(height: AppSpacing.xl),
            _buildFilterChips(),
            const SizedBox(height: AppSpacing.xl),
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
                            ? 'Aucun paiement enregistre'
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
          label: 'Total percu',
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
          _buildFilterChip(label: 'Tous (${_payments.length})', status: null),
          const SizedBox(width: AppSpacing.sm),
          _buildFilterChip(label: 'Paye (${_countByStatus(PaymentStatus.paid)})', status: PaymentStatus.paid),
          const SizedBox(width: AppSpacing.sm),
          _buildFilterChip(label: 'En attente (${_countByStatus(PaymentStatus.pending)})', status: PaymentStatus.pending),
          const SizedBox(width: AppSpacing.sm),
          _buildFilterChip(label: 'En retard (${_countByStatus(PaymentStatus.late)})', status: PaymentStatus.late),
          const SizedBox(width: AppSpacing.sm),
          _buildFilterChip(label: 'Partiel (${_countByStatus(PaymentStatus.partial)})', status: PaymentStatus.partial),
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.1) : AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
          border: Border.all(color: isSelected ? color : AppColors.border),
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
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
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
                          '${payment.unitLabel} -- ${payment.buildingName}',
                          style: AppTypography.caption,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
                    const Text('Reste: ', style: AppTypography.caption),
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
                  Text('Echeance: ${payment.dueDate}', style: AppTypography.caption),
                  const Spacer(),
                  if (payment.periodLabel.isNotEmpty)
                    Text(
                      payment.periodLabel,
                      style: AppTypography.caption.copyWith(color: AppColors.textMuted),
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
"""

leads_path = os.path.join(SCREENS_DIR, 'leads_screen.dart')
payments_path = os.path.join(SCREENS_DIR, 'payments_screen.dart')

with open(leads_path, 'w', encoding='utf-8') as f:
    f.write(LEADS_SCREEN)
print(f"Written: {leads_path}")

with open(payments_path, 'w', encoding='utf-8') as f:
    f.write(PAYMENTS_SCREEN)
print(f"Written: {payments_path}")
print("Done.")
