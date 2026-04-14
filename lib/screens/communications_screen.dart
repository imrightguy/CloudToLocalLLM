import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models.dart';
import '../services/communication_service.dart';
import 'conversation_detail_screen.dart';
import 'compose_sms_screen.dart';

class CommunicationsScreen extends StatefulWidget {
  const CommunicationsScreen({super.key});

  @override
  State<CommunicationsScreen> createState() => _CommunicationsScreenState();
}

class _CommunicationsScreenState extends State<CommunicationsScreen> {
  List<CommunicationItem> _communications = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _searchQuery = '';
  String _selectedFilter = 'all';
  bool _isStatusFilter = false;

  @override
  void initState() {
    super.initState();
    _fetchCommunications();
  }

  Future<void> _fetchCommunications() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      String? type;
      String? status;
      if (!_isStatusFilter && _selectedFilter != 'all') {
        type = _selectedFilter;
      } else if (_isStatusFilter) {
        status = _selectedFilter;
      }

      final items = await CommunicationService.instance.getCommunications(
        type: type,
        status: status,
        search: _searchQuery.isNotEmpty ? _searchQuery : null,
      );
      setState(() {
        _communications = items;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  void _filterCommunications(String query) {
    setState(() {
      _searchQuery = query;
    });
    _fetchCommunications();
  }

  void _selectFilter(String filter, {bool isStatus = false}) {
    setState(() {
      _selectedFilter = filter;
      _isStatusFilter = isStatus;
    });
    _fetchCommunications();
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'sms':
        return Icons.sms_outlined;
      case 'email':
        return Icons.email_outlined;
      case 'call':
        return Icons.phone_outlined;
      default:
        return Icons.note_outlined;
    }
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'sms':
        return const Color(0xFF6366F1);
      case 'email':
        return const Color(0xFF3B82F6);
      case 'call':
        return const Color(0xFF10B981);
      default:
        return const Color(0xFFF59E0B);
    }
  }

  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return "À l'instant";
    if (diff.inMinutes < 60) return '${diff.inMinutes} min';
    if (diff.inHours < 24) return '${diff.inHours} h';
    if (diff.inDays < 7) return '${diff.inDays} j';
    return DateFormat('d MMM', 'fr').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Communications'),
        titleTextStyle: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Color(0xFF1E293B),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF0F766E),
        child: const Icon(Icons.edit, color: Colors.white),
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const ComposeSmsScreen(),
              fullscreenDialog: true,
            ),
          );
        },
      ),
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
            const Icon(Icons.error_outline, size: 48, color: Color(0xFFEF4444)),
            const SizedBox(height: 16),
            const Text(
              'Impossible de charger les communications',
              style: TextStyle(fontSize: 16, color: Color(0xFF1E293B)),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _fetchCommunications,
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F766E),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
              const Icon(Icons.search, size: 20, color: Color(0xFF64748B)),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Rechercher par nom ou numéro...',
                    hintStyle:
                        TextStyle(fontSize: 14, color: Color(0xFF64748B)),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                  onChanged: _filterCommunications,
                ),
              ),
            ],
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              _buildFilterChip('Tous', 'all', false),
              _buildFilterChip('SMS', 'sms', false, icon: Icons.sms_outlined),
              _buildFilterChip('Courriel', 'email', false,
                  icon: Icons.email_outlined),
              _buildFilterChip('Appel', 'call', false,
                  icon: Icons.phone_outlined),
              _buildFilterChip('Note', 'note', false,
                  icon: Icons.note_outlined),
              _buildFilterChip('Envoyé', 'sent', true,
                  icon: Icons.check_circle_outline),
              _buildFilterChip('Échoué', 'failed', true,
                  icon: Icons.error_outline),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _communications.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  color: const Color(0xFF0F766E),
                  backgroundColor: Colors.white,
                  onRefresh: _fetchCommunications,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: _communications.length,
                    itemBuilder: (context, index) {
                      return _buildCommunicationItem(
                          _communications[index]);
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, String value, bool isStatus,
      {IconData? icon}) {
    final isSelected = _selectedFilter == value && _isStatusFilter == isStatus;
    return GestureDetector(
      onTap: () => _selectFilter(value, isStatus: isStatus),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF0F766E).withValues(alpha: 0.1)
              : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF0F766E)
                : const Color(0xFFE2E8F0),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null)
              Icon(icon,
                  size: 14,
                  color: isSelected
                      ? const Color(0xFF0F766E)
                      : const Color(0xFF64748B)),
            if (icon != null) const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isSelected
                    ? const Color(0xFF0F766E)
                    : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommunicationItem(CommunicationItem item) {
    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ConversationDetailScreen(
              contactId: item.contactId,
              contactName: item.contactName,
              contactPhone: item.contactPhone,
              contactInitials: item.contactInitials,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
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
            CircleAvatar(
              radius: 24,
              backgroundColor:
                  const Color(0xFF0F766E).withValues(alpha: 0.1),
              child: Text(
                item.contactInitials,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F766E),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        item.contactName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      Text(
                        _formatTimestamp(item.createdAt),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(_typeIcon(item.type),
                          size: 14, color: _typeColor(item.type)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          item.body.isNotEmpty
                              ? item.body
                              : item.subject,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF64748B),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _buildStatusIcon(item.status),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIcon(String status) {
    switch (status) {
      case 'sent':
        return const Icon(Icons.check, size: 16, color: Color(0xFF94A3B8));
      case 'delivered':
        return const Icon(Icons.done_all, size: 16, color: Color(0xFF94A3B8));
      case 'read':
        return const Icon(Icons.done_all, size: 16, color: Color(0xFF0F766E));
      case 'failed':
        return const Icon(Icons.error_outline, size: 16, color: Color(0xFFEF4444));
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.message_outlined,
                size: 48, color: Color(0xFFCBD5E1)),
            SizedBox(height: 16),
            Text(
              'Aucune communication',
              style: TextStyle(fontSize: 16, color: Color(0xFF1E293B)),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              'Vos messages et appels apparaîtront ici',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
