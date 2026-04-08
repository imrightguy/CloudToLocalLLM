import 'package:flutter/material.dart';

import '../data/demo_data.dart';
import '../models.dart';

class PipelineScreen extends StatefulWidget {
  const PipelineScreen({super.key});

  @override
  State<PipelineScreen> createState() => _PipelineScreenState();
}

class _PipelineScreenState extends State<PipelineScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pipeline'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: const Color(0xFF1E293B),
          unselectedLabelColor: const Color(0xFF64748B),
          labelStyle: const TextStyle(fontWeight: FontWeight.w500),
          indicator: const UnderlineTabIndicator(
            borderSide: BorderSide(color: Color(0xFF0F766E), width: 3),
            insets: EdgeInsets.symmetric(horizontal: 16),
          ),
          tabs: const [
            Tab(text: 'Nouveau'),
            Tab(text: 'Contacté'),
            Tab(text: 'Qualifié'),
            Tab(text: 'Visite'),
            Tab(text: 'Offre'),
            Tab(text: 'Négociation'),
            Tab(text: 'Signé'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPipelineStage(LeadStage.nouveau, 3),
          _buildPipelineStage(LeadStage.contacte, 5),
          _buildPipelineStage(LeadStage.qualifie, 4),
          _buildPipelineStage(LeadStage.visitePlanifiee, 2),
          _buildPipelineStage(LeadStage.offreEnvoyee, 1),
          _buildPipelineStage(LeadStage.negociation, 1),
          _buildPipelineStage(LeadStage.bailSigne, 1),
        ],
      ),
    );
  }

  Widget _buildPipelineStage(LeadStage stage, int count) {
    // Filter leads by stage
    final filteredLeads = leadItems.where((lead) => lead.stage == stage).toList();
    
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
                  color: Colors.black.withOpacity(0.05),
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
                    color: _getStageColor(stage).withOpacity(0.1),
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
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      Text(
                        '${filteredLeads.length} ${filteredLeads.length == 1 ? 'prospect' : 'prospects'}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${(count / 24 * 100).toStringAsFixed(1)}%',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F766E),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Leads list
          Expanded(
            child: ListView.builder(
              itemCount: filteredLeads.length,
              itemBuilder: (context, index) {
                final lead = filteredLeads[index];
                return _buildLeadCard(lead);
              },
            ),
          ),
          
          // Add button
          Container(
            margin: const EdgeInsets.only(top: 16),
            child: ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.add),
              label: const Text('Ajouter un prospect'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                backgroundColor: const Color(0xFF0F766E),
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

  Widget _buildLeadCard(LeadItem lead) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
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
                backgroundColor: Color(0xFFE0E7FF),
                child: Icon(
                  Icons.person,
                  color: Color(0xFF6366F1),
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
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    Text(
                      lead.desiredUnit,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getStageColor(lead.stage).withOpacity(0.1),
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
              Icon(
                Icons.email_outlined,
                size: 16,
                color: const Color(0xFF64748B),
              ),
              const SizedBox(width: 4),
              Text(
                lead.email,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(width: 16),
              Icon(
                Icons.phone_outlined,
                size: 16,
                color: const Color(0xFF64748B),
              ),
              const SizedBox(width: 4),
              Text(
                lead.phone,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF64748B),
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
                color: Color(0xFF64748B),
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
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(width: 8),
              if (lead.tags.isNotEmpty) ...[
                ...lead.tags.take(2).expand((tag) => [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0E7FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      tag,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF4338CA),
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
        return const Color(0xFF6B7280);
      case LeadStage.contacte:
        return const Color(0xFF3B82F6);
      case LeadStage.qualifie:
        return const Color(0xFF10B981);
      case LeadStage.visitePlanifiee:
        return const Color(0xFF8B5CF6);
      case LeadStage.offreEnvoyee:
        return const Color(0xFFF59E0B);
      case LeadStage.negociation:
        return const Color(0xFFEF4444);
      case LeadStage.bailSigne:
        return const Color(0xFF10B981);
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