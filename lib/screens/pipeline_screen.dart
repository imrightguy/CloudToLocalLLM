import 'package:flutter/material.dart';

import '../models.dart';
import '../services/api_service.dart';
import 'lead_detail_screen.dart';
import '../theme/app_colors.dart';
import '../widgets/immo_app_bar.dart';

class PipelineScreen extends StatefulWidget {
  const PipelineScreen({super.key});

  @override
  State<PipelineScreen> createState() => _PipelineScreenState();
}

class _PipelineScreenState extends State<PipelineScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<LeadItem> _allLeads = [];
  bool _isLoading = true;
  String? _errorMessage;

  static const _stages = [
    LeadStage.nouveau,
    LeadStage.contacte,
    LeadStage.qualifie,
    LeadStage.visitePlanifiee,
    LeadStage.offreEnvoyee,
    LeadStage.negociation,
    LeadStage.bailSigne,
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _stages.length, vsync: this);
    _fetchLeads();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchLeads() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final response = await ApiService.instance.get('/leads');
      final data = response['data'] as List<dynamic>;
      final leads = data
          .map((e) => LeadItem.fromJson(e as Map<String, dynamic>))
          .toList();
      setState(() {
        _allLeads = leads;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  List<LeadItem> _leadsForStage(LeadStage stage) {
    return _allLeads.where((lead) => lead.stage == stage).toList();
  }

  int _countForStage(LeadStage stage) {
    return _allLeads.where((lead) => lead.stage == stage).length;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: ImmoAppBar(title: 'Pipeline')
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: ImmoAppBar(title: 'Pipeline')
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline,
                  size: 48, color: AppColors.error),
              const SizedBox(height: 16),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  'Impossible de charger les prospects',
                  style: TextStyle(fontSize: 16, color: AppColors.textPrimary),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  _errorMessage!,
                  style:
                      const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _fetchLeads,
                icon: const Icon(Icons.refresh),
                label: const Text('Réessayer'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pipeline'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: AppColors.textPrimary,
          unselectedLabelColor: AppColors.textSecondary,
          labelStyle: const TextStyle(fontWeight: FontWeight.w500),
          indicator: const UnderlineTabIndicator(
            borderSide: BorderSide(color: AppColors.primary, width: 3),
            insets: EdgeInsets.symmetric(horizontal: 16),
          ),
          tabs: _stages.map((stage) {
            final count = _countForStage(stage);
            return Tab(
              text: '${stage.label}$count',
            );
          }).toList(),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchLeads,
        child: TabBarView(
          controller: _tabController,
          children: _stages.map((stage) {
            return _buildPipelineStage(stage);
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildPipelineStage(LeadStage stage) {
    final filteredLeads = _leadsForStage(stage);
    final totalCount = _allLeads.length;

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stats header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _getStageColor(stage).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _getStageIcon(stage),
                    color: _getStageColor(stage),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getStageTitle(stage),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        '${filteredLeads.length} ${filteredLeads.length == 1 ? 'prospect' : 'prospects'}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  totalCount > 0
                      ? '${(filteredLeads.length / totalCount * 100).toStringAsFixed(1)}%'
                      : '0%',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Leads list
          Expanded(
            child: filteredLeads.isEmpty
                ? const Center(
                    child: Text(
                      'Aucun prospect dans cette étape',
                      style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                    ),
                  )
                : ListView.builder(
                    itemCount: filteredLeads.length,
                    itemBuilder: (context, index) {
                      final lead = filteredLeads[index];
                      return GestureDetector(
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => LeadDetailScreen(
                                lead: lead,
                                onStageChanged: _fetchLeads,
                              ),
                            ),
                          );
                          // Refresh after returning (stage may have changed)
                          _fetchLeads();
                        },
                        child: _buildLeadCard(lead),
                      );
                    },
                  ),
          ),

          // Add button
          Container(
            margin: const EdgeInsets.only(top: 16),
            child: ElevatedButton.icon(
              onPressed: () => _showAddLeadDialog(context, stage),
              icon: const Icon(Icons.add),
              label: const Text('Ajouter un prospect'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddLeadDialog(BuildContext context, LeadStage stage) async {
    final fullNameController = TextEditingController();
    final emailController = TextEditingController();
    final phoneController = TextEditingController();
    final budgetController = TextEditingController();
    final notesController = TextEditingController();

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Ajouter un prospect'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: fullNameController,
                  decoration: const InputDecoration(
                    labelText: 'Nom complet',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Téléphone',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: budgetController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Budget (\$)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Notes',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () async {
                final fullName = fullNameController.text.trim();
                final email = emailController.text.trim();
                if (fullName.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Le nom est requis')),
                  );
                  return;
                }
                Navigator.of(dialogContext).pop();
                final messenger = ScaffoldMessenger.of(context);
                try {
                  final budgetText = budgetController.text.trim();
                  final body = <String, dynamic>{
                    'fullName': fullName,
                    'email': email,
                    'phone': phoneController.text.trim(),
                    'stage': stage.name,
                    'notes': notesController.text.trim(),
                  };
                  if (budgetText.isNotEmpty) {
                    body['budget'] = int.tryParse(budgetText) ?? 0;
                  }
                  await ApiService.instance.post('/leads', body);
                  if (mounted) {
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('Prospect ajouté avec succès'),
                        backgroundColor: AppColors.success,
                      ),
                    );
                    _fetchLeads();
                  }
                } catch (e) {
                  if (mounted) {
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text('Erreur: ${e.toString()}'),
                        backgroundColor: AppColors.error,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Ajouter'),
            ),
          ],
        );
      },
    );

    fullNameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    budgetController.dispose();
    notesController.dispose();
  }

  Widget _buildLeadCard(LeadItem lead) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.indigoTint,
                child: Icon(
                  Icons.person,
                  color: AppColors.indigo,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lead.fullName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      lead.desiredUnit,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getStageColor(lead.stage).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _getStageTitle(lead.stage),
                  style: TextStyle(
                    fontSize: 11,
                    color: _getStageColor(lead.stage),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(
                Icons.email_outlined,
                size: 16,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 4),
              Text(
                lead.email,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 16),
              const Icon(
                Icons.phone_outlined,
                size: 16,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 4),
              Text(
                lead.phone,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          if (lead.notes.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              lead.notes,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                lead.budget > 0 ? '${lead.budget}\$' : 'Budget non spécifié',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 8),
              if (lead.tags.isNotEmpty) ...[
                ...lead.tags.take(2).expand((tag) => [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.indigoTint,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          tag,
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.indigoDark,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                    ]),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Color _getStageColor(LeadStage stage) {
    switch (stage) {
      case LeadStage.nouveau:
        return AppColors.stageNouveau;
      case LeadStage.contacte:
        return AppColors.info;
      case LeadStage.qualifie:
        return AppColors.success;
      case LeadStage.visitePlanifiee:
        return AppColors.stageVisitePlanifiee;
      case LeadStage.offreEnvoyee:
        return AppColors.warning;
      case LeadStage.negociation:
        return AppColors.error;
      case LeadStage.bailSigne:
        return AppColors.success;
    }
  }

  IconData _getStageIcon(LeadStage stage) {
    switch (stage) {
      case LeadStage.nouveau:
        return Icons.new_releases_outlined;
      case LeadStage.contacte:
        return Icons.contact_phone_outlined;
      case LeadStage.qualifie:
        return Icons.verified_outlined;
      case LeadStage.visitePlanifiee:
        return Icons.calendar_today_outlined;
      case LeadStage.offreEnvoyee:
        return Icons.send_outlined;
      case LeadStage.negociation:
        return Icons.handshake_outlined;
      case LeadStage.bailSigne:
        return Icons.check_circle_outlined;
    }
  }

  String _getStageTitle(LeadStage stage) {
    switch (stage) {
      case LeadStage.nouveau:
        return 'Nouveau';
      case LeadStage.contacte:
        return 'Contacté';
      case LeadStage.qualifie:
        return 'Qualifié';
      case LeadStage.visitePlanifiee:
        return 'Visite';
      case LeadStage.offreEnvoyee:
        return 'Offre envoyée';
      case LeadStage.negociation:
        return 'Négociation';
      case LeadStage.bailSigne:
        return 'Bail signé';
    }
  }
}
