import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models.dart';
import '../services/api_service.dart';
import '../services/visit_service.dart';
import 'visit_form_screen.dart';
import '../theme/app_colors.dart';
import '../widgets/immo_app_bar.dart';

enum _CalendarView { month, week }

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  _CalendarView _viewMode = _CalendarView.month;
  DateTime _focusedMonth = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  List<VisitItem> _visits = [];
  bool _isLoading = true;
  String? _errorMessage;
  String? _statusFilter;
  String? _buildingFilter;
  String? _employeeFilter;

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
      final startOfMonth = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
      final endOfMonth = DateTime(
        _focusedMonth.year,
        _focusedMonth.month + 1,
        0,
        23,
        59,
        59,
      );
      final response = await ApiService.instance.get(
        '/visits?dateFrom=${Uri.encodeComponent(startOfMonth.toIso8601String().split('T').first)}&dateTo=${Uri.encodeComponent(endOfMonth.toIso8601String().split('T').first)}&limit=200',
      );
      final data = response['data'] as List<dynamic>;
      final visits = data
          .map((e) => VisitItem.fromJson(e as Map<String, dynamic>))
          .toList();
      setState(() {
        _visits = visits;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  List<VisitItem> _filteredVisits() {
    return _visits.where((v) {
      if (_statusFilter != null && _statusFilter!.isNotEmpty) {
        if (v.status.toLowerCase() != _statusFilter!.toLowerCase()) return false;
      }
      if (_buildingFilter != null && _buildingFilter!.isNotEmpty) {
        if (v.buildingName != _buildingFilter) return false;
      }
      if (_employeeFilter != null && _employeeFilter!.isNotEmpty) {
        if (v.agent != _employeeFilter) return false;
      }
      return true;
    }).toList();
  }

  List<VisitItem> _visitsForDay(DateTime day) {
    return _filteredVisits().where((v) {
      if (v.dateTime == null) return false;
      return v.dateTime!.year == day.year &&
          v.dateTime!.month == day.month &&
          v.dateTime!.day == day.day;
    }).toList()
      ..sort((a, b) {
        if (a.dateTime == null && b.dateTime == null) return 0;
        if (a.dateTime == null) return 1;
        if (b.dateTime == null) return -1;
        return a.dateTime!.compareTo(b.dateTime!);
      });
  }

  bool _hasVisitsOnDay(DateTime day) {
    return _filteredVisits().any((v) {
      if (v.dateTime == null) return false;
      return v.dateTime!.year == day.year &&
          v.dateTime!.month == day.month &&
          v.dateTime!.day == day.day;
    });
  }

  void _goToPreviousMonth() {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1);
    });
    _fetchVisits();
  }

  void _goToNextMonth() {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1);
    });
    _fetchVisits();
  }

  void _goToPreviousWeek() {
    setState(() {
      _focusedMonth = _focusedMonth.subtract(const Duration(days: 7));
      _selectedDay = _selectedDay.subtract(const Duration(days: 7));
    });
    _fetchVisits();
  }

  void _goToNextWeek() {
    setState(() {
      _focusedMonth = _focusedMonth.add(const Duration(days: 7));
      _selectedDay = _selectedDay.add(const Duration(days: 7));
    });
    _fetchVisits();
  }

  void _goToToday() {
    setState(() {
      _focusedMonth = DateTime.now();
      _selectedDay = DateTime.now();
    });
    _fetchVisits();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ImmoAppBar(title: 'Calendrier', actions: [
          IconButton(
            icon: const Icon(Icons.today_outlined),
            tooltip: "Aujourd'hui",
            onPressed: _goToToday,
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _navigateToVisitForm(context),
          ),
        ]),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _navigateToVisitForm(context),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Planifier'),
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
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 16),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'Impossible de charger le calendrier',
                style: TextStyle(fontSize: 16, color: AppColors.textPrimary),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _errorMessage!,
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _fetchVisits,
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.surface,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchVisits,
      child: Column(
        children: [
          _buildMonthNavigation(),
          _buildViewToggle(),
          _buildFilterBar(),
          Expanded(
            child: _viewMode == _CalendarView.month
                ? _buildMonthView()
                : _buildWeekView(),
          ),
          _buildDayDetail(),
        ],
      ),
    );
  }

  Widget _buildMonthNavigation() {
    final monthLabel = DateFormat('MMMM yyyy', 'fr').format(_focusedMonth);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: _viewMode == _CalendarView.month
                ? _goToPreviousMonth
                : _goToPreviousWeek,
          ),
          Expanded(
            child: GestureDetector(
              onTap: _viewMode == _CalendarView.month ? null : () {
                setState(() {
                  _viewMode = _CalendarView.month;
                  _focusedMonth = DateTime(
                    _selectedDay.year,
                    _selectedDay.month,
                  );
                });
                _fetchVisits();
              },
              child: Text(
                monthLabel.replaceFirst(monthLabel[0], monthLabel[0].toUpperCase()),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: _viewMode == _CalendarView.month
                ? _goToNextMonth
                : _goToNextWeek,
          ),
        ],
      ),
    );
  }

  Widget _buildViewToggle() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Expanded(
              child: _buildToggleChip(
                label: 'Mois',
                isSelected: _viewMode == _CalendarView.month,
                onTap: () => setState(() => _viewMode = _CalendarView.month),
              ),
            ),
            Expanded(
              child: _buildToggleChip(
                label: 'Semaine',
                isSelected: _viewMode == _CalendarView.week,
                onTap: () => setState(() => _viewMode = _CalendarView.week),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            color: isSelected ? AppColors.primary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Filter Bar
  // ---------------------------------------------------------------------------

  Widget _buildFilterBar() {
    final statusFilters = [
      const _FilterOption(label: 'Tous', value: ''),
      const _FilterOption(label: 'Planifiée', value: 'scheduled'),
      const _FilterOption(label: 'Confirmée', value: 'confirmed'),
      const _FilterOption(label: 'Terminée', value: 'completed'),
      const _FilterOption(label: 'Annulée', value: 'cancelled'),
      const _FilterOption(label: 'Absent', value: 'no_show'),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: statusFilters.map((f) {
          final isSelected = (_statusFilter ?? '') == f.value;
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: GestureDetector(
              onTap: () {
                setState(() => _statusFilter = f.value.isEmpty ? null : f.value);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary.withValues(alpha: 0.1)
                      : AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected ? AppColors.primary : AppColors.border,
                  ),
                ),
                child: Text(
                  f.label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: isSelected ? AppColors.primary : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Month View
  // ---------------------------------------------------------------------------

  Widget _buildMonthView() {
    return _buildMonthGrid();
  }

  Widget _buildMonthGrid() {
    const dayHeaders = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];
    final firstOfMonth = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    final lastOfMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0);
    final firstWeekday = firstOfMonth.weekday;

    final gridDays = <DateTime>[];

    for (int i = 1; i < firstWeekday; i++) {
      final prevMonthDay = firstOfMonth.subtract(Duration(days: firstWeekday - i));
      gridDays.add(prevMonthDay);
    }
    for (int d = 1; d <= lastOfMonth.day; d++) {
      gridDays.add(DateTime(_focusedMonth.year, _focusedMonth.month, d));
    }
    while (gridDays.length % 7 != 0) {
      gridDays.add(
        gridDays.last.add(const Duration(days: 1)),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: dayHeaders
                .map((d) => Expanded(
                      child: Text(
                        d,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ))
                .toList(),
          ),
        ),
        Expanded(
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1.0,
            ),
            itemCount: gridDays.length,
            itemBuilder: (context, index) {
              final day = gridDays[index];
              final isCurrentMonth = day.month == _focusedMonth.month;
              final isToday = _isSameDay(day, DateTime.now());
              final isSelected = _isSameDay(day, _selectedDay);
              final hasVisits = _hasVisitsOnDay(day);

              return GestureDetector(
                onTap: () => setState(() => _selectedDay = day),
                child: Container(
                  margin: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary
                        : isToday
                            ? AppColors.primary.withValues(alpha: 0.1)
                            : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: isToday && !isSelected
                        ? Border.all(
                            color: AppColors.primary,
                            width: 1.5,
                          )
                        : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${day.day}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isToday || isSelected
                              ? FontWeight.bold
                              : FontWeight.w400,
                          color: isSelected
                              ? Colors.white
                              : isCurrentMonth
                                  ? AppColors.textPrimary
                                  : AppColors.disabled,
                        ),
                      ),
                      if (hasVisits)
                        Container(
                          margin: const EdgeInsets.only(top: 2),
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.white
                                : AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Week View
  // ---------------------------------------------------------------------------

  Widget _buildWeekView() {
    final weekStart = _selectedDay.subtract(
      Duration(days: (_selectedDay.weekday - 1) % 7),
    );
    final days = List.generate(7, (i) => weekStart.add(Duration(days: i)));

    const hours = [
      '08:00', '09:00', '10:00', '11:00', '12:00',
      '13:00', '14:00', '15:00', '16:00', '17:00', '18:00', '19:00',
    ];

    return Column(
      children: [
        // Day headers
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              const SizedBox(width: 44),
              ...days.map((day) {
                final isToday = _isSameDay(day, DateTime.now());
                final isSelected = _isSameDay(day, _selectedDay);
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedDay = day),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          Text(
                            DateFormat('E', 'fr').format(day),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: isSelected
                                  ? Colors.white.withValues(alpha: 0.8)
                                  : AppColors.textMuted,
                            ),
                          ),
                          Text(
                            '${day.day}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isSelected
                                  ? Colors.white
                                  : isToday
                                      ? AppColors.primary
                                      : AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
        const Divider(height: 1),
        // Time grid
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Hour labels
                SizedBox(
                  width: 44,
                  child: Column(
                    children: hours.map((h) {
                      return SizedBox(
                        height: 48,
                        child: Align(
                          alignment: Alignment.topRight,
                          child: Padding(
                            padding: const EdgeInsets.only(right: 4, top: 2),
                            child: Text(
                              h,
                              style: const TextStyle(
                                fontSize: 10,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const VerticalDivider(width: 1),
                // Day columns
                 Expanded(
                   child: Row(
                     children: days.map((day) {
                       final dayVisits = _visitsForDay(day);
                       return Expanded(
                         child: DragTarget<DateTime>(
                           onAcceptWithDetails: (details) async {
                             final visit = details.data as VisitItem;
                             final hour = day.hour.clamp(8, 19);
                             final newDateTime = DateTime(
                               day.year, day.month, day.day, hour,
                             );
                             _handleReschedule(visit, newDateTime);
                           },
                           builder: (context, candidateData, rejectedData) {
                             return Container(
                               height: 48.0 * hours.length,
                               decoration: candidateData.isNotEmpty
                                   ? BoxDecoration(
                                       color: AppColors.primary.withValues(alpha: 0.05),
                                       borderRadius: BorderRadius.circular(4),
                                     )
                                   : null,
                               child: Stack(
                                 children: [
                                   // Grid lines
                                   ...List.generate(hours.length, (i) {
                                     return Positioned(
                                       top: i * 48.0,
                                       left: 0,
                                       right: 0,
                                       child: const Divider(
                                         height: 1,
                                         color: AppColors.surfaceVariant,
                                       ),
                                     );
                                   }),
                               // Visit chips
                               ...dayVisits.map((visit) {
                                 if (visit.dateTime == null) return const SizedBox.shrink();
                                 final hour = visit.dateTime!.hour;
                                 final minute = visit.dateTime!.minute;
                                 final top = (hour - 8) * 48.0 + (minute / 60.0) * 48.0;
                                 if (top < 0 || top > hours.length * 48.0) {
                                   return const SizedBox.shrink();
                                 }
                                 final color = _statusColor(visit.status);
                                 return Positioned(
                                   top: top.clamp(0.0, (hours.length * 48.0 - 24.0)),
                                   left: 1,
                                   right: 1,
                                   child: LongPressDraggable<VisitItem>(
                                     data: visit,
                                     feedback: Material(
                                       elevation: 4,
                                       borderRadius: BorderRadius.circular(6),
                                       child: Container(
                                         padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                         decoration: BoxDecoration(
                                           color: color.withValues(alpha: 0.2),
                                           borderRadius: BorderRadius.circular(6),
                                           border: Border.all(color: color),
                                         ),
                                         child: Text(
                                           '${visit.unitLabel} - ${DateFormat('HH:mm', 'fr').format(visit.dateTime!)}',
                                           style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.w600),
                                         ),
                                       ),
                                     ),
                                     childWhenDragging: Opacity(opacity: 0.3, child: _buildWeekVisitChip(visit, color)),
                                     child: GestureDetector(
                                       onTap: () => _showVisitDetailDialog(context, visit),
                                       child: _buildWeekVisitChip(visit, color),
                                     ),
                                   ),
                                 );
                               }),
                             ],
                           ),
                             );
                           },
                         ),
                       );
                     }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Drag-to-Reschedule
  // ---------------------------------------------------------------------------

  Future<void> _handleReschedule(VisitItem visit, DateTime newDateTime) async {
    if (visit.id == null) return;
    try {
      await VisitService.instance.rescheduleVisit(
        visit.id!,
        newDateTime: newDateTime,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Visite reprogrammée au ${DateFormat('d MMM à HH:mm', 'fr').format(newDateTime)}'),
            backgroundColor: AppColors.success,
          ),
        );
        _fetchVisits();
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
    }
  }

  Widget _buildWeekVisitChip(VisitItem visit, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              visit.unitLabel,
              style: TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.w600,
                color: color,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (visit.agent.isNotEmpty)
            CircleAvatar(
              radius: 7,
              backgroundColor: AppColors.surface,
              child: Text(
                visit.agent.split(RegExp(r'\s+')).take(2).map((w) => w.isNotEmpty ? w[0] : '').join().toUpperCase(),
                style: TextStyle(fontSize: 6, fontWeight: FontWeight.bold, color: color),
              ),
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Day Detail Panel
  // ---------------------------------------------------------------------------

  Widget _buildDayDetail() {
    final dayVisits = _visitsForDay(_selectedDay);
    final isCurrentMonth = _selectedDay.month == _focusedMonth.month ||
        _viewMode == _CalendarView.week;
    final dayLabel = isCurrentMonth
        ? DateFormat('EEEE d MMMM', 'fr').format(_selectedDay)
        : DateFormat('d MMMM', 'fr').format(_selectedDay);

    return Container(
      constraints: const BoxConstraints(maxHeight: 280),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.surfaceVariant, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 8,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Text(
                  dayLabel.replaceFirst(dayLabel[0], dayLabel[0].toUpperCase()),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${dayVisits.length} visite${dayVisits.length != 1 ? 's' : ''}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (dayVisits.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.event_busy, size: 20, color: AppColors.disabled),
                  SizedBox(width: 8),
                  Text(
                    'Aucune visite ce jour',
                    style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                  ),
                ],
              ),
            )
          else
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: dayVisits.length,
                itemBuilder: (context, index) {
                  final visit = dayVisits[index];
                  return _buildVisitCard(visit);
                },
              ),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildVisitCard(VisitItem visit) {
    final color = _statusColor(visit.status);
    final timeLabel = visit.dateTime != null
        ? DateFormat('HH:mm').format(visit.dateTime!)
        : '';
    final statusLabel = _statusLabel(visit.status);
    final agentInitials = visit.agent.isNotEmpty
        ? visit.agent.split(RegExp(r'\s+')).take(2).map((w) => w.isNotEmpty ? w[0] : '').join().toUpperCase()
        : '?';

    return GestureDetector(
      onTap: () => _showVisitDetailDialog(context, visit),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 36,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        timeLabel,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          statusLabel,
                          style: TextStyle(
                            fontSize: 10,
                            color: color,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${visit.buildingName} · ${visit.unitLabel}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if (visit.leadName != null && visit.leadName!.isNotEmpty)
                    Text(
                      visit.leadName!,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                ],
              ),
            ),
            if (visit.agent.isNotEmpty)
              CircleAvatar(
                radius: 14,
                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                child: Text(
                  agentInitials,
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              )
            else
              const Icon(Icons.person_outline, size: 18, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Visit Detail Dialog
  // ---------------------------------------------------------------------------

  void _showVisitDetailDialog(BuildContext context, VisitItem visit) {
    final displayStatus = _statusLabel(visit.status);
    final timeLabel = visit.dateTime != null
        ? DateFormat('EEEE d MMMM yyyy à HH:mm', 'fr').format(visit.dateTime!)
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
                    const Text('Locataire notifié: ',
                        style: TextStyle(fontWeight: FontWeight.w500)),
                    Text(visit.occupantNotified ? 'Oui' : 'Non'),
                  ],
                ),
                const SizedBox(height: 4),
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

  // ---------------------------------------------------------------------------
  // Navigation
  // ---------------------------------------------------------------------------

  void _navigateToVisitForm(BuildContext context) {
    Navigator.of(context)
        .push(
      MaterialPageRoute(
        builder: (_) => VisitFormScreen(initialDate: _selectedDay),
        fullscreenDialog: true,
      ),
    )
        .then((didCreate) {
      if (didCreate == true && mounted) _fetchVisits();
    });
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
        return AppColors.visitConfirmed;
      case 'completed':
        return AppColors.visitCompleted;
      case 'cancelled':
        return AppColors.visitCancelled;
      case 'no_show':
        return AppColors.visitNoShow;
      case 'scheduled':
      case 'pending':
        return AppColors.visitScheduled;
      default:
        return AppColors.textSecondary;
    }
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
      case 'pending':
        return 'Planifiée';
      default:
        return status;
    }
  }
}

class _FilterOption {
  const _FilterOption({required this.label, required this.value});
  final String label;
  final String value;
}
