import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models.dart';
import '../services/api_service.dart';
import '../services/employee_service.dart';
import '../services/visit_service.dart';
import '../theme/app_colors.dart';
import '../widgets/immo_app_bar.dart';

class VisitFormScreen extends StatefulWidget {
  final DateTime? initialDate;

  const VisitFormScreen({super.key, this.initialDate});

  @override
  State<VisitFormScreen> createState() => _VisitFormScreenState();
}

class _VisitFormScreenState extends State<VisitFormScreen> {
  bool _isLoading = true;
  String? _error;
  bool _isSubmitting = false;

  List<UnitItem> _units = [];
  List<LeadItem> _leads = [];
  List<EmployeeItem> _employees = [];
  List<VisitItem> _existingVisits = [];

  String? _selectedUnitId;
  String? _selectedLeadId;
  String? _selectedEmployeeId;
  DateTime _selectedDate;
  TimeOfDay _selectedTime;
  String _notes = '';

  bool get _hasConflict {
    if (_selectedEmployeeId == null) return false;
    final newStart = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );
    return _existingVisits.any((v) {
      if (v.id == null) return false;
      if (v.dateTime == null) return false;
      final vEnd = v.dateTime!.add(const Duration(hours: 1));
      final newEnd = newStart.add(const Duration(hours: 1));
      return v.dateTime!.isBefore(newEnd) && vEnd.isAfter(newStart);
    });
  }

  @override
  void initState() {
    super.initState();
    final initial = widget.initialDate ?? DateTime.now().add(const Duration(hours: 1));
    _selectedDate = DateTime(initial.year, initial.month, initial.day);
    _selectedTime = TimeOfDay.now().replacing(
      hour: initial.hour,
    );
    _fetchOptions();
  }

  Future<void> _fetchOptions() async {
    try {
      final results = await Future.wait([
        ApiService.instance.get('/buildings/units?limit=100'),
        ApiService.instance.get('/leads?limit=100'),
        EmployeeService.instance.getEmployees(),
        VisitService.instance.getVisits(
          dateFrom: DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day),
          dateTo: DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, 23, 59, 59),
          limit: 100,
        ),
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
        _employees = results[2] as List<EmployeeItem>;
        _existingVisits = results[3].items;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchExistingVisits() async {
    try {
      final result = await VisitService.instance.getVisits(
        dateFrom: DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day),
        dateTo: DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, 23, 59, 59),
        limit: 100,
      );
      setState(() {
        _existingVisits = result.items;
      });
    } catch (_) {}
  }

  String _unitLabel(UnitItem u) =>
      '${u.number} — ${u.type} (${u.bedrooms}ch, ${u.rent}\$)';

  String _leadLabel(LeadItem l) => '${l.fullName} (${l.stage.label})';

  Future<void> _submit() async {
    if (_selectedUnitId == null ||
        _selectedLeadId == null ||
        _selectedEmployeeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez remplir tous les champs obligatoires'),
          backgroundColor: AppColors.warning,
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

      final result = await ApiService.instance.post('/visits', {
        'unitId': _selectedUnitId,
        'leadId': _selectedLeadId,
        'employeeId': _selectedEmployeeId,
        'dateTime': dt.toIso8601String(),
        if (_notes.isNotEmpty) 'notes': _notes,
      });

      if (mounted) {
        final occupantSMS = result['occupantSMS'] as Map<String, dynamic>?;
        if (occupantSMS != null) {
          final smsSuccess = occupantSMS['success'] as bool? ?? false;
          final needsNotice = occupantSMS['needsNotice'] as bool? ?? false;

          if (smsSuccess) {
            String message = 'Visite créée — SMS envoyé au locataire';
            if (needsNotice) {
              message += '\nNote: moins de 24h de préavis';
            }
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(message),
                backgroundColor: needsNotice
                    ? AppColors.warning
                    : AppColors.success,
                duration: Duration(seconds: needsNotice ? 5 : 3),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Visite créée, mais l\'envoi du SMS au locataire a échoué',
                ),
                backgroundColor: AppColors.warning,
                duration: Duration(seconds: 4),
              ),
            );
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Visite créée avec succès'),
              backgroundColor: AppColors.success,
            ),
          );
        }
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: AppColors.error,
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
      appBar: ImmoAppBar(title: 'Nouvelle visite', leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ))
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
                            size: 48, color: AppColors.error),
                        const SizedBox(height: 16),
                        Text(_error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: AppColors.textSecondary)),
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
                          labelText: 'Unité *',
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
                        onChanged: (v) => setState(() => _selectedUnitId = v),
                      ),
                      const SizedBox(height: 16),

                      // Lead picker
                      DropdownButtonFormField<String>(
                        initialValue: _selectedLeadId,
                        decoration: const InputDecoration(
                          labelText: 'Prospect *',
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
                        onChanged: (v) => setState(() => _selectedLeadId = v),
                      ),
                      const SizedBox(height: 16),

                      // Employee picker
                      DropdownButtonFormField<String>(
                        initialValue: _selectedEmployeeId,
                        decoration: const InputDecoration(
                          labelText: 'Employé *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.badge_outlined),
                        ),
                        items: _employees.map((e) {
                          return DropdownMenuItem(
                            value: e.id,
                            child: Text(e.fullName,
                                overflow: TextOverflow.ellipsis),
                          );
                        }).toList(),
                        onChanged: (v) => setState(() => _selectedEmployeeId = v),
                      ),
                      const SizedBox(height: 16),

                      // Date picker
                      InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _selectedDate,
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 90)),
                          );
                          if (picked != null) {
                            setState(() => _selectedDate = picked);
                            _fetchExistingVisits();
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
                      const SizedBox(height: 16),

                      // Notes
                      TextField(
                        onChanged: (v) => setState(() => _notes = v),
                        decoration: const InputDecoration(
                          labelText: 'Notes',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.notes_outlined),
                        ),
                        maxLines: 3,
                        controller: TextEditingController(text: _notes),
                      ),
                      const SizedBox(height: 16),

                      // Conflict warning
                      if (_hasConflict)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppColors.warning.withValues(alpha: 0.3),
                            ),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.warning_amber,
                                  color: AppColors.warning, size: 20),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Conflit détecté: cet employé a déjà une visite à cette heure.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.warningDark,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      const SizedBox(height: 24),

                      // Submit
                      ElevatedButton(
                        onPressed: _isSubmitting ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
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
