import 'package:flutter/material.dart';

import '../models.dart';
import '../services/employee_service.dart';
import '../services/schedule_service.dart';

class EmployeeDetailScreen extends StatefulWidget {
  final EmployeeItem employee;
  const EmployeeDetailScreen({super.key, required this.employee});

  @override
  State<EmployeeDetailScreen> createState() => _EmployeeDetailScreenState();
}

class _EmployeeDetailScreenState extends State<EmployeeDetailScreen> {
  late EmployeeItem _employee;
  List<ScheduleItem> _schedules = [];
  bool _isLoadingSchedules = true;
  String? _scheduleError;
  bool _isEditing = false;
  bool _isDeleting = false;

  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _employee = widget.employee;
    _firstNameController.text = _employee.firstName;
    _lastNameController.text = _employee.lastName;
    _emailController.text = _employee.email;
    _phoneController.text = _employee.phone;
    _fetchSchedules();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _fetchSchedules() async {
    if (_employee.id == null) return;
    setState(() {
      _isLoadingSchedules = true;
      _scheduleError = null;
    });
    try {
      final schedules = await ScheduleService.instance
          .getSchedules(employeeId: _employee.id);
      setState(() {
        _schedules = schedules;
        _isLoadingSchedules = false;
      });
    } catch (e) {
      setState(() {
        _scheduleError = e.toString();
        _isLoadingSchedules = false;
      });
    }
  }

  Future<void> _saveEmployee() async {
    if (!_formKey.currentState!.validate() || _employee.id == null) return;
    try {
      final updated = await EmployeeService.instance.updateEmployee(
        _employee.id!,
        {
          'firstName': _firstNameController.text.trim(),
          'lastName': _lastNameController.text.trim(),
          'email': _emailController.text.trim(),
          'phone': _phoneController.text.trim(),
        },
      );
      setState(() {
        _employee = updated;
        _isEditing = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Employé mis à jour avec succès'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
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
    }
  }

  Future<void> _deleteEmployee() async {
    if (_employee.id == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer l\'employé'),
        content: Text(
          'Voulez-vous vraiment supprimer ${_employee.fullName} ? Cette action est irréversible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child:
                const Text('Supprimer', style: TextStyle(color: Color(0xFFEF4444))),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _isDeleting = true);
    try {
      await EmployeeService.instance.deleteEmployee(_employee.id!);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
        setState(() => _isDeleting = false);
      }
    }
  }

  Future<void> _addScheduleBlock() async {
    if (_employee.id == null) return;
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => const _ScheduleBlockDialog(),
    );
    if (result == null) return;

    try {
      await ScheduleService.instance.createSchedule({
        'employeeId': _employee.id,
        'dayOfWeek': result['dayOfWeek'],
        'startTime': result['startTime'],
        'endTime': result['endTime'],
        if (result['buildingId'] != null) 'buildingId': result['buildingId'],
      });
      _fetchSchedules();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Horaire ajouté avec succès'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
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
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_employee.fullName),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => setState(() => _isEditing = true),
              tooltip: 'Modifier',
            ),
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: _saveEmployee,
              tooltip: 'Enregistrer',
            ),
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                setState(() {
                  _isEditing = false;
                  _firstNameController.text = _employee.firstName;
                  _lastNameController.text = _employee.lastName;
                  _emailController.text = _employee.email;
                  _phoneController.text = _employee.phone;
                });
              },
              tooltip: 'Annuler',
            ),
          if (!_isEditing)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'delete') _deleteEmployee();
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline,
                          color: Color(0xFFEF4444), size: 20),
                      SizedBox(width: 12),
                      Text('Supprimer',
                          style: TextStyle(color: Color(0xFFEF4444))),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: _isDeleting
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildContactCard(),
                  const SizedBox(height: 24),
                  _buildBuildingAssignments(),
                  const SizedBox(height: 24),
                  _buildWeeklySchedule(),
                ],
              ),
            ),
    );
  }

  Widget _buildContactCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Coordonnées',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 16),
            if (_isEditing)
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _firstNameController,
                            decoration: const InputDecoration(
                              labelText: 'Prénom *',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                            validator: (v) =>
                                (v == null || v.trim().isEmpty) ? 'Requis' : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _lastNameController,
                            decoration: const InputDecoration(
                              labelText: 'Nom *',
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) =>
                                (v == null || v.trim().isEmpty) ? 'Requis' : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        labelText: 'Courriel *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Requis';
                        if (!v.contains('@')) return 'Courriel invalide';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _phoneController,
                      decoration: const InputDecoration(
                        labelText: 'Téléphone',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                  ],
                ),
              )
            else ...[
              _ContactRow(
                icon: Icons.person_outline,
                label: _employee.fullName,
              ),
              const SizedBox(height: 12),
              _ContactRow(
                icon: Icons.email_outlined,
                label: _employee.email,
              ),
              if (_employee.phone.isNotEmpty) ...[
                const SizedBox(height: 12),
                _ContactRow(
                  icon: Icons.phone_outlined,
                  label: _employee.phone,
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _employee.isActive
                          ? const Color(0xFF10B981).withValues(alpha: 0.1)
                          : const Color(0xFFEF4444).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _employee.isActive ? 'Actif' : 'Inactif',
                      style: TextStyle(
                        fontSize: 12,
                        color: _employee.isActive
                            ? const Color(0xFF10B981)
                            : const Color(0xFFEF4444),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBuildingAssignments() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Assignations d\'immeubles',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 12),
        if (_employee.buildingAssignments.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Aucune assignation',
              style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _employee.buildingAssignments.length,
            itemBuilder: (context, index) {
              final assignment = _employee.buildingAssignments[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.apartment_outlined,
                        size: 20, color: Color(0xFF64748B)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        assignment.buildingName ?? assignment.buildingId ?? 'Immeuble',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: assignment.role.toLowerCase() == 'primary'
                            ? const Color(0xFF0F766E).withValues(alpha: 0.1)
                            : const Color(0xFFF59E0B).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        assignment.roleLabel,
                        style: TextStyle(
                          fontSize: 11,
                          color: assignment.role.toLowerCase() == 'primary'
                              ? const Color(0xFF0F766E)
                              : const Color(0xFFF59E0B),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildWeeklySchedule() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Horaire hebdomadaire',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: _addScheduleBlock,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Ajouter'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF0F766E),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_isLoadingSchedules)
          const Center(
              child: Padding(
            padding: EdgeInsets.all(24),
            child: CircularProgressIndicator(),
          ))
        else if (_scheduleError != null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Erreur: $_scheduleError',
              style: const TextStyle(fontSize: 13, color: Color(0xFFEF4444)),
            ),
          )
        else if (_schedules.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Aucun horaire configuré',
              style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
            ),
          )
        else
          _buildScheduleTable(),
      ],
    );
  }

  Widget _buildScheduleTable() {
    final dayOrder = [1, 2, 3, 4, 5, 6, 0];
    final grouped = <int, List<ScheduleItem>>{};
    for (final s in _schedules) {
      grouped.putIfAbsent(s.dayOfWeek, () => []).add(s);
    }

    return Table(
      columnWidths: const {
        0: FlexColumnWidth(1.2),
        1: FlexColumnWidth(1),
        2: FlexColumnWidth(1),
        3: FlexColumnWidth(1.5),
      },
      border: TableBorder.all(
        color: const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(8),
      ),
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        TableRow(
          decoration: const BoxDecoration(
            color: Color(0xFFF8FAFC),
          ),
          children: const [
            _TableCell('Jour', isHeader: true),
            _TableCell('Début', isHeader: true),
            _TableCell('Fin', isHeader: true),
            _TableCell('Immeuble', isHeader: true),
          ],
        ),
        for (final day in dayOrder)
          if (grouped[day] != null)
            for (final s in grouped[day]!)
              TableRow(
                decoration: BoxDecoration(
                  color: day == DateTime.now().weekday
                      ? const Color(0xFF0F766E).withValues(alpha: 0.05)
                      : Colors.white,
                ),
                children: [
                  _TableCell(s.dayLabel),
                  _TableCell(s.startTime),
                  _TableCell(s.endTime),
                  _TableCell(
                    s.buildingName ?? '—',
                    style: TextStyle(
                      fontSize: 12,
                      color: s.buildingName != null
                          ? const Color(0xFF1E293B)
                          : const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
      ],
    );
  }
}

class _ContactRow extends StatelessWidget {
  final IconData icon;
  final String label;
  const _ContactRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: const Color(0xFF64748B)),
        const SizedBox(width: 12),
        Text(
          label,
          style: const TextStyle(fontSize: 14, color: Color(0xFF1E293B)),
        ),
      ],
    );
  }
}

class _TableCell extends StatelessWidget {
  final String text;
  final bool isHeader;
  final TextStyle? style;
  const _TableCell(this.text, {this.isHeader = false, this.style});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Text(
        text,
        style: style ??
            TextStyle(
              fontSize: 12,
              fontWeight: isHeader ? FontWeight.w600 : FontWeight.normal,
              color: isHeader ? const Color(0xFF64748B) : const Color(0xFF1E293B),
            ),
      ),
    );
  }
}

class _ScheduleBlockDialog extends StatefulWidget {
  const _ScheduleBlockDialog();

  @override
  State<_ScheduleBlockDialog> createState() => _ScheduleBlockDialogState();
}

class _ScheduleBlockDialogState extends State<_ScheduleBlockDialog> {
  int _selectedDay = DateTime.now().weekday;
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 17, minute: 0);
  String? _selectedBuildingId;

  static const _dayLabels = [
    'Lundi',
    'Mardi',
    'Mercredi',
    'Jeudi',
    'Vendredi',
    'Samedi',
    'Dimanche',
  ];

  String _formatTime(TimeOfDay t) {
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Ajouter un horaire'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<int>(
              value: _selectedDay,
              decoration: const InputDecoration(
                labelText: 'Jour',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.calendar_today_outlined),
              ),
              items: List.generate(7, (i) {
                return DropdownMenuItem(
                  value: i + 1 > 7 ? 1 : i + 1,
                  child: Text(_dayLabels[i]),
                );
              }),
              onChanged: (v) {
                if (v != null) setState(() => _selectedDay = v);
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: _startTime,
                      );
                      if (picked != null) setState(() => _startTime = picked);
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Heure début',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.schedule),
                        suffixIcon: Icon(Icons.arrow_drop_down),
                      ),
                      child: Text(_formatTime(_startTime)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: _endTime,
                      );
                      if (picked != null) setState(() => _endTime = picked);
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Heure fin',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.schedule_outlined),
                        suffixIcon: Icon(Icons.arrow_drop_down),
                      ),
                      child: Text(_formatTime(_endTime)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop({
              'dayOfWeek': _selectedDay,
              'startTime': _formatTime(_startTime),
              'endTime': _formatTime(_endTime),
              if (_selectedBuildingId != null)
                'buildingId': _selectedBuildingId,
            });
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0F766E),
            foregroundColor: Colors.white,
          ),
          child: const Text('Ajouter'),
        ),
      ],
    );
  }
}
