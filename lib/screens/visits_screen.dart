import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models.dart';
import '../services/api_service.dart';

class VisitsScreen extends StatefulWidget {
  const VisitsScreen({super.key});

  @override
  State<VisitsScreen> createState() => _VisitsScreenState();
}

class _VisitsScreenState extends State<VisitsScreen> {
  DateTime _selectedDate = DateTime.now();
  List<VisitItem> _allVisits = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchVisits();
  }

  Future<void> _fetchVisits() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final response = await ApiService.instance.get('/visits');
      final data = response['data'] as List<dynamic>;
      final visits =
          data.map((e) => VisitItem.fromJson(e as Map<String, dynamic>)).toList();
      setState(() {
        _allVisits = visits;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  /// Filter visits that match the selected date (compare date part of dateTime).
  List<VisitItem> get _filteredVisits {
    final selected = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );
    return _allVisits.where((v) {
      if (v.dateTime == null) return false;
      final visitDate = DateTime(
        v.dateTime!.year,
        v.dateTime!.month,
        v.dateTime!.day,
      );
      return visitDate.isAtSameMomentAs(selected);
    }).toList();
  }

  /// Count visits by status for selected date.
  int _countByStatus(String status) {
    return _filteredVisits.where((v) => v.status.toLowerCase() == status).length;
  }

  String _statusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
        return 'Confirmée';
      case 'completed':
        return 'Terminée';
      case 'cancelled':
        return 'Annulée';
      case 'no_show':
        return 'Absent';
      case 'scheduled':
        return 'Planifiée';
      default:
        return status;
    }
  }

  bool _isConfirmed(String status) {
    return status.toLowerCase() == 'confirmed';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Visites'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showCreateVisitDialog(context),
          ),
        ],
      ),
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
            const Icon(Icons.error_outline, size: 48, color: Color(0xFFEF4444)),
            const SizedBox(height: 16),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'Impossible de charger les visites',
                style: TextStyle(fontSize: 16, color: Color(0xFF1E293B)),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _errorMessage!,
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _fetchVisits,
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

    final filtered = _filteredVisits;
    final total = filtered.length;
    final confirmed = _countByStatus('confirmed');
    final pending = _countByStatus('scheduled');

    return RefreshIndicator(
      onRefresh: _fetchVisits,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date selector
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () {
                    setState(() {
                      _selectedDate =
                          _selectedDate.subtract(const Duration(days: 1));
                    });
                  },
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      DateFormat('EEEE d MMMM yyyy').format(_selectedDate),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () {
                    setState(() {
                      _selectedDate =
                          _selectedDate.add(const Duration(days: 1));
                    });
                  },
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Stats summary
            Row(
              children: [
                Expanded(
                  child: Container(
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
                        const Text(
                          "Visites aujourd'hui",
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '$total',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
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
                        const Text(
                          'Confirmées',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '$confirmed',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF10B981),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
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
                        const Text(
                          'Potentielles',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '$pending',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFF59E0B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Upcoming visits
            const Text(
              'Visites à venir',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),

            const SizedBox(height: 12),

            if (filtered.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text(
                    'Aucune visite pour cette date',
                    style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final visit = filtered[index];
                  final isConfirmed = _isConfirmed(visit.status);
                  final statusColor = isConfirmed
                      ? const Color(0xFF10B981)
                      : const Color(0xFFF59E0B);
                  final displayStatus = _statusLabel(visit.status);
                  final timeLabel = visit.dateTime != null
                      ? DateFormat('HH:mm').format(visit.dateTime!)
                      : visit.dateLabel;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: statusColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    isConfirmed
                                        ? Icons.check_circle_outlined
                                        : Icons.schedule_outlined,
                                    color: statusColor,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            timeLabel,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF1E293B),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding:
                                                const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 2),
                                            decoration: BoxDecoration(
                                              color: statusColor
                                                  .withValues(alpha: 0.1),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              displayStatus,
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: statusColor,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        visit.buildingName,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 12),

                            Row(
                              children: [
                                const Icon(Icons.person_outline,
                                    size: 16, color: Color(0xFF64748B)),
                                const SizedBox(width: 4),
                                Text(
                                  visit.agent,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                const Icon(Icons.apartment_outlined,
                                    size: 16, color: Color(0xFF64748B)),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    visit.unitLabel,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            if (visit.notes.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                visit.notes,
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
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () =>
                                        _showVisitDetailDialog(context, visit),
                                    child: const Text(
                                      'Détails',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF0F766E),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: isConfirmed
                                        ? null
                                        : () => _confirmVisit(visit),
                                    child: const Text(
                                      'Confirmer',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showVisitDetailDialog(BuildContext context, VisitItem visit) {
    final displayStatus = _statusLabel(visit.status);
    final timeLabel = visit.dateTime != null
        ? DateFormat('EEEE d MMMM yyyy à HH:mm').format(visit.dateTime!)
        : visit.dateLabel;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Détails de la visite'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _detailRow('Date', timeLabel),
                _detailRow('Statut', displayStatus),
                _detailRow('Immeuble', visit.buildingName),
                _detailRow('Unité', visit.unitLabel),
                _detailRow('Agent', visit.agent),
                if (visit.leadName != null && visit.leadName!.isNotEmpty)
                  _detailRow('Prospect', visit.leadName!),
                if (visit.notes.isNotEmpty) _detailRow('Notes', visit.notes),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('Tenant confirmé: ',
                        style: TextStyle(fontWeight: FontWeight.w500)),
                    Text(visit.tenantConfirmed ? 'Oui' : 'Non'),
                  ],
                ),
                Row(
                  children: [
                    const Text('Employé confirmé: ',
                        style: TextStyle(fontWeight: FontWeight.w500)),
                    Text(visit.employeeConfirmed ? 'Oui' : 'Non'),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Fermer'),
            ),
          ],
        );
      },
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Future<void> _confirmVisit(VisitItem visit) async {
    if (visit.id == null) return;
    try {
      await ApiService.instance
          .patch('/visits/${visit.id}/status', {'status': 'confirmed'});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Visite confirmée'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
        _fetchVisits();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString()}'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  void _showCreateVisitDialog(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const _CreateVisitScreen(),
        fullscreenDialog: true,
      ),
    ).then((_) {
      if (mounted) _fetchVisits();
    });
  }
}

// =============================================================================
// Create Visit — full-screen dialog with dropdown pickers
// =============================================================================

class _CreateVisitScreen extends StatefulWidget {
  const _CreateVisitScreen();

  @override
  State<_CreateVisitScreen> createState() => _CreateVisitScreenState();
}

class _CreateVisitScreenState extends State<_CreateVisitScreen> {
  bool _isLoading = true;
  String? _error;

  // Fetched options
  List<UnitItem> _units = [];
  List<LeadItem> _leads = [];
  List<Map<String, dynamic>> _employees = [];

  // Selected values
  String? _selectedUnitId;
  String? _selectedLeadId;
  String? _selectedEmployeeId;
  DateTime _selectedDate = DateTime.now().add(const Duration(hours: 1));
  TimeOfDay _selectedTime = TimeOfDay.now().replacing(
    hour: DateTime.now().add(const Duration(hours: 1)).hour,
  );
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _fetchOptions();
  }

  Future<void> _fetchOptions() async {
    try {
      final results = await Future.wait([
        ApiService.instance.get('/buildings/units?limit=100'),
        ApiService.instance.get('/leads?limit=100'),
        ApiService.instance.get('/employees?limit=100'),
      ]);

      setState(() {
        _units = (results[0]['data'] as List<dynamic>?)
                ?.map((e) => UnitItem.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [];
        _leads = (results[1]['data'] as List<dynamic>?)
                ?.map((e) => LeadItem.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [];
        _employees = (results[2]['data'] as List<dynamic>?)
                ?.cast<Map<String, dynamic>>()
                .toList() ??
            [];
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  String _unitLabel(UnitItem u) => '${u.number} — ${u.type} (${u.bedrooms}ch, ${u.rent}\$)';

  String _leadLabel(LeadItem l) => '${l.fullName} (${l.stage.label})';

  String _employeeLabel(Map<String, dynamic> e) {
    final first = e['firstName'] as String? ?? '';
    final last = e['lastName'] as String? ?? '';
    return '$first $last'.trim();
  }

  Future<void> _submit() async {
    if (_selectedUnitId == null ||
        _selectedLeadId == null ||
        _selectedEmployeeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez remplir tous les champs'),
          backgroundColor: Color(0xFFF59E0B),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final dt = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );

      await ApiService.instance.post('/visits', {
        'unitId': _selectedUnitId,
        'leadId': _selectedLeadId,
        'employeeId': _selectedEmployeeId,
        'dateTime': dt.toIso8601String(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Visite créée avec succès'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nouvelle visite'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline,
                            size: 48, color: Color(0xFFEF4444)),
                        const SizedBox(height: 16),
                        Text(_error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Color(0xFF64748B))),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _fetchOptions,
                          child: const Text('Réessayer'),
                        ),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Unit picker
                      DropdownButtonFormField<String>(
                        initialValue: _selectedUnitId,
                        decoration: const InputDecoration(
                          labelText: 'Unité',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.door_front_door_outlined),
                        ),
                        items: _units.map((u) {
                          return DropdownMenuItem(
                            value: u.id,
                            child: Text(_unitLabel(u),
                                overflow: TextOverflow.ellipsis),
                          );
                        }).toList(),
                        onChanged: (v) =>
                            setState(() => _selectedUnitId = v),
                      ),
                      const SizedBox(height: 16),

                      // Lead picker
                      DropdownButtonFormField<String>(
                        initialValue: _selectedLeadId,
                        decoration: const InputDecoration(
                          labelText: 'Prospect',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        items: _leads.map((l) {
                          return DropdownMenuItem(
                            value: l.id,
                            child: Text(_leadLabel(l),
                                overflow: TextOverflow.ellipsis),
                          );
                        }).toList(),
                        onChanged: (v) =>
                            setState(() => _selectedLeadId = v),
                      ),
                      const SizedBox(height: 16),

                      // Employee picker
                      DropdownButtonFormField<String>(
                        initialValue: _selectedEmployeeId,
                        decoration: const InputDecoration(
                          labelText: 'Employé',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.badge_outlined),
                        ),
                        items: _employees.map((e) {
                          return DropdownMenuItem(
                            value: e['id'] as String?,
                            child: Text(_employeeLabel(e),
                                overflow: TextOverflow.ellipsis),
                          );
                        }).toList(),
                        onChanged: (v) =>
                            setState(() => _selectedEmployeeId = v),
                      ),
                      const SizedBox(height: 16),

                      // Date picker
                      InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _selectedDate,
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now()
                                .add(const Duration(days: 90)),
                          );
                          if (picked != null) {
                            setState(() => _selectedDate = picked);
                          }
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Date',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.calendar_today_outlined),
                          ),
                          child: Text(
                            DateFormat('d MMMM yyyy', 'fr_CA')
                                .format(_selectedDate),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Time picker
                      InkWell(
                        onTap: () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: _selectedTime,
                          );
                          if (picked != null) {
                            setState(() => _selectedTime = picked);
                          }
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Heure',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.schedule_outlined),
                          ),
                          child: Text(_selectedTime.format(context)),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Submit
                      ElevatedButton(
                        onPressed: _isSubmitting ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F766E),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                ),
                              )
                            : const Text(
                                'Créer la visite',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
    );
  }
}
