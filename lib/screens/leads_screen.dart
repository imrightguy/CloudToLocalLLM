import 'package:flutter/material.dart';
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
              ? 'Hermes notifié pour ${lead.fullName}'
              : 'Hermes non configuré — notification ignorée'),
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
    if (_filteredLeads.isEmpty) { return const EmptyState(
      title: 'Aucune piste',
      description: 'Les pistes de locataires potentiels apparaîtront ici.',
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
              hintText: 'Rechercher par nom…',
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
