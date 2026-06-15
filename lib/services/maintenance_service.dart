import 'api_service.dart';

class MaintenanceCommandCenterData {
  const MaintenanceCommandCenterData({
    required this.summary,
    required this.properties,
    required this.backlog,
    required this.tenantMessages,
    required this.asOf,
  });

  final MaintenanceCommandCenterSummary summary;
  final List<MaintenanceCommandCenterProperty> properties;
  final List<MaintenanceCommandCenterBacklogItem> backlog;
  final List<MaintenanceCommandCenterTenantMessage> tenantMessages;
  final DateTime? asOf;

  bool get isEmpty =>
      summary.isEmpty &&
      properties.isEmpty &&
      backlog.isEmpty &&
      tenantMessages.isEmpty;

  factory MaintenanceCommandCenterData.fromJson(Map<String, dynamic> json) {
    return MaintenanceCommandCenterData(
      summary: MaintenanceCommandCenterSummary.fromJson(
        (json['summary'] as Map<String, dynamic>?) ?? const {},
      ),
      properties: (json['properties'] as List<dynamic>? ?? const [])
          .map((entry) => MaintenanceCommandCenterProperty.fromJson(
                entry as Map<String, dynamic>,
              ))
          .toList(),
      backlog: (json['backlog'] as List<dynamic>? ?? const [])
          .map((entry) => MaintenanceCommandCenterBacklogItem.fromJson(
                entry as Map<String, dynamic>,
              ))
          .toList(),
      tenantMessages: (json['tenantMessages'] as List<dynamic>? ?? const [])
          .map((entry) => MaintenanceCommandCenterTenantMessage.fromJson(
                entry as Map<String, dynamic>,
              ))
          .toList(),
      asOf: json['asOf'] != null ? DateTime.tryParse(json['asOf'] as String) : null,
    );
  }
}

class MaintenanceCommandCenterSummary {
  const MaintenanceCommandCenterSummary({
    required this.propertyCount,
    required this.renovationCount,
    required this.blockedCount,
    required this.readyCount,
    required this.overdueTaskCount,
    required this.dueSoonTaskCount,
    required this.openOrderCount,
    required this.pendingIntakeCount,
    required this.dispatchableEmployeeCount,
    required this.tenantMessageSentCount,
    required this.tenantMessageFailedCount,
    required this.tenantMessagePendingCount,
  });

  final int propertyCount;
  final int renovationCount;
  final int blockedCount;
  final int readyCount;
  final int overdueTaskCount;
  final int dueSoonTaskCount;
  final int openOrderCount;
  final int pendingIntakeCount;
  final int dispatchableEmployeeCount;
  final int tenantMessageSentCount;
  final int tenantMessageFailedCount;
  final int tenantMessagePendingCount;

  bool get isEmpty =>
      propertyCount == 0 &&
      renovationCount == 0 &&
      blockedCount == 0 &&
      readyCount == 0 &&
      overdueTaskCount == 0 &&
      dueSoonTaskCount == 0 &&
      openOrderCount == 0 &&
      pendingIntakeCount == 0 &&
      dispatchableEmployeeCount == 0 &&
      tenantMessageSentCount == 0 &&
      tenantMessageFailedCount == 0 &&
      tenantMessagePendingCount == 0;

  factory MaintenanceCommandCenterSummary.fromJson(Map<String, dynamic> json) {
    return MaintenanceCommandCenterSummary(
      propertyCount: (json['propertyCount'] as num?)?.toInt() ?? 0,
      renovationCount: (json['renovationCount'] as num?)?.toInt() ?? 0,
      blockedCount: (json['blockedCount'] as num?)?.toInt() ?? 0,
      readyCount: (json['readyCount'] as num?)?.toInt() ?? 0,
      overdueTaskCount: (json['overdueTaskCount'] as num?)?.toInt() ?? 0,
      dueSoonTaskCount: (json['dueSoonTaskCount'] as num?)?.toInt() ?? 0,
      openOrderCount: (json['openOrderCount'] as num?)?.toInt() ?? 0,
      pendingIntakeCount: (json['pendingIntakeCount'] as num?)?.toInt() ?? 0,
      dispatchableEmployeeCount: (json['dispatchableEmployeeCount'] as num?)?.toInt() ?? 0,
      tenantMessageSentCount: (json['tenantMessageSentCount'] as num?)?.toInt() ?? 0,
      tenantMessageFailedCount: (json['tenantMessageFailedCount'] as num?)?.toInt() ?? 0,
      tenantMessagePendingCount: (json['tenantMessagePendingCount'] as num?)?.toInt() ?? 0,
    );
  }
}

class MaintenanceCommandCenterTenantMessageStats {
  const MaintenanceCommandCenterTenantMessageStats({
    required this.total,
    required this.sent,
    required this.failed,
    required this.latestAt,
  });

  final int total;
  final int sent;
  final int failed;
  final DateTime? latestAt;

  factory MaintenanceCommandCenterTenantMessageStats.fromJson(Map<String, dynamic> json) {
    return MaintenanceCommandCenterTenantMessageStats(
      total: (json['total'] as num?)?.toInt() ?? 0,
      sent: (json['sent'] as num?)?.toInt() ?? 0,
      failed: (json['failed'] as num?)?.toInt() ?? 0,
      latestAt: json['latestAt'] != null ? DateTime.tryParse(json['latestAt'] as String) : null,
    );
  }
}

class MaintenanceCommandCenterCapacity {
  const MaintenanceCommandCenterCapacity({
    required this.candidateCount,
    required this.dispatchableCount,
    required this.totalOpenTasks,
    required this.buildingOpenTasks,
  });

  final int candidateCount;
  final int dispatchableCount;
  final int totalOpenTasks;
  final int buildingOpenTasks;

  factory MaintenanceCommandCenterCapacity.fromJson(Map<String, dynamic> json) {
    return MaintenanceCommandCenterCapacity(
      candidateCount: (json['candidateCount'] as num?)?.toInt() ?? 0,
      dispatchableCount: (json['dispatchableCount'] as num?)?.toInt() ?? 0,
      totalOpenTasks: (json['totalOpenTasks'] as num?)?.toInt() ?? 0,
      buildingOpenTasks: (json['buildingOpenTasks'] as num?)?.toInt() ?? 0,
    );
  }
}

class MaintenanceCommandCenterProperty {
  const MaintenanceCommandCenterProperty({
    required this.buildingId,
    required this.buildingName,
    required this.unitCount,
    required this.renovationCount,
    required this.blockedCount,
    required this.readyCount,
    required this.overdueTaskCount,
    required this.dueSoonTaskCount,
    required this.openOrderCount,
    required this.pendingIntakeCount,
    required this.tenantMessageStats,
    required this.capacity,
    required this.backlog,
    required this.nextDueAt,
  });

  final String buildingId;
  final String buildingName;
  final int unitCount;
  final int renovationCount;
  final int blockedCount;
  final int readyCount;
  final int overdueTaskCount;
  final int dueSoonTaskCount;
  final int openOrderCount;
  final int pendingIntakeCount;
  final MaintenanceCommandCenterTenantMessageStats tenantMessageStats;
  final MaintenanceCommandCenterCapacity capacity;
  final List<MaintenanceCommandCenterBacklogItem> backlog;
  final DateTime? nextDueAt;

  factory MaintenanceCommandCenterProperty.fromJson(Map<String, dynamic> json) {
    return MaintenanceCommandCenterProperty(
      buildingId: json['buildingId'] as String? ?? '',
      buildingName: json['buildingName'] as String? ?? '—',
      unitCount: (json['unitCount'] as num?)?.toInt() ?? 0,
      renovationCount: (json['renovationCount'] as num?)?.toInt() ?? 0,
      blockedCount: (json['blockedCount'] as num?)?.toInt() ?? 0,
      readyCount: (json['readyCount'] as num?)?.toInt() ?? 0,
      overdueTaskCount: (json['overdueTaskCount'] as num?)?.toInt() ?? 0,
      dueSoonTaskCount: (json['dueSoonTaskCount'] as num?)?.toInt() ?? 0,
      openOrderCount: (json['openOrderCount'] as num?)?.toInt() ?? 0,
      pendingIntakeCount: (json['pendingIntakeCount'] as num?)?.toInt() ?? 0,
      tenantMessageStats: MaintenanceCommandCenterTenantMessageStats.fromJson(
        (json['tenantMessageStats'] as Map<String, dynamic>?) ?? const {},
      ),
      capacity: MaintenanceCommandCenterCapacity.fromJson(
        (json['capacity'] as Map<String, dynamic>?) ?? const {},
      ),
      backlog: (json['backlog'] as List<dynamic>? ?? const [])
          .map((entry) => MaintenanceCommandCenterBacklogItem.fromJson(
                entry as Map<String, dynamic>,
              ))
          .toList(),
      nextDueAt: json['nextDueAt'] != null ? DateTime.tryParse(json['nextDueAt'] as String) : null,
    );
  }
}

class MaintenanceCommandCenterBacklogItem {
  const MaintenanceCommandCenterBacklogItem({
    required this.id,
    required this.unitId,
    required this.buildingId,
    required this.unitLabel,
    required this.buildingName,
    required this.phase,
    required this.readiness,
    required this.taskCount,
    required this.doneCount,
    required this.blockerCount,
    required this.overdueTaskCount,
    required this.dueSoonTaskCount,
    required this.nextStep,
    required this.updatedAt,
    required this.blockerNote,
    required this.nextDueAt,
    required this.assignedEmployeeLabel,
    required this.tenantPhone,
    required this.tenantMessageStatus,
  });

  final String id;
  final String unitId;
  final String buildingId;
  final String unitLabel;
  final String buildingName;
  final String phase;
  final String readiness;
  final int taskCount;
  final int doneCount;
  final int blockerCount;
  final int overdueTaskCount;
  final int dueSoonTaskCount;
  final String nextStep;
  final DateTime? updatedAt;
  final String blockerNote;
  final DateTime? nextDueAt;
  final String assignedEmployeeLabel;
  final String? tenantPhone;
  final MaintenanceCommandCenterTenantMessage tenantMessageStatus;

  bool get isReady => phase == 'ready';
  bool get isBlocked => phase == 'blocked';

  factory MaintenanceCommandCenterBacklogItem.fromJson(Map<String, dynamic> json) {
    return MaintenanceCommandCenterBacklogItem(
      id: json['id'] as String? ?? '',
      unitId: json['unitId'] as String? ?? '',
      buildingId: json['buildingId'] as String? ?? '',
      unitLabel: json['unitLabel'] as String? ?? '—',
      buildingName: json['buildingName'] as String? ?? '—',
      phase: json['phase'] as String? ?? 'active',
      readiness: json['readiness'] as String? ?? '0 % prêt',
      taskCount: (json['taskCount'] as num?)?.toInt() ?? 0,
      doneCount: (json['doneCount'] as num?)?.toInt() ?? 0,
      blockerCount: (json['blockerCount'] as num?)?.toInt() ?? 0,
      overdueTaskCount: (json['overdueTaskCount'] as num?)?.toInt() ?? 0,
      dueSoonTaskCount: (json['dueSoonTaskCount'] as num?)?.toInt() ?? 0,
      nextStep: json['nextStep'] as String? ?? '',
      updatedAt: json['updatedAt'] != null ? DateTime.tryParse(json['updatedAt'] as String) : null,
      blockerNote: json['blockerNote'] as String? ?? '',
      nextDueAt: json['nextDueAt'] != null ? DateTime.tryParse(json['nextDueAt'] as String) : null,
      assignedEmployeeLabel: json['assignedEmployeeLabel'] as String? ?? '',
      tenantPhone: json['tenantPhone'] as String?,
      tenantMessageStatus: MaintenanceCommandCenterTenantMessage.fromJson(
        (json['tenantMessageStatus'] as Map<String, dynamic>?) ?? const {},
      ),
    );
  }
}

class MaintenanceCommandCenterTenantMessage {
  const MaintenanceCommandCenterTenantMessage({
    required this.renovationId,
    required this.unitId,
    required this.buildingId,
    required this.buildingName,
    required this.unitLabel,
    required this.tenantPhone,
    required this.status,
    required this.lastSentAt,
    required this.phoneNumber,
    required this.errorMessage,
  });

  final String? renovationId;
  final String? unitId;
  final String? buildingId;
  final String? buildingName;
  final String? unitLabel;
  final String? tenantPhone;
  final String status;
  final DateTime? lastSentAt;
  final String? phoneNumber;
  final String? errorMessage;

  bool get isFailed => status == 'failed';
  bool get isSent => status == 'sent';
  bool get isPending => status == 'not_sent' || status == 'unavailable';

  factory MaintenanceCommandCenterTenantMessage.fromJson(Map<String, dynamic> json) {
    return MaintenanceCommandCenterTenantMessage(
      renovationId: json['renovationId'] as String?,
      unitId: json['unitId'] as String?,
      buildingId: json['buildingId'] as String?,
      buildingName: json['buildingName'] as String?,
      unitLabel: json['unitLabel'] as String?,
      tenantPhone: json['tenantPhone'] as String?,
      status: json['status'] as String? ?? 'unavailable',
      lastSentAt: json['lastSentAt'] != null ? DateTime.tryParse(json['lastSentAt'] as String) : null,
      phoneNumber: json['phoneNumber'] as String?,
      errorMessage: json['errorMessage'] as String?,
    );
  }
}

class MaintenanceTicket {
  const MaintenanceTicket({
    required this.id,
    required this.title,
    required this.description,
    required this.urgency,
    required this.status,
    required this.source,
    required this.tenantName,
    required this.callerPhone,
    required this.unitId,
    required this.buildingId,
    required this.photos,
    required this.resolvedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final String description;
  final String urgency;
  final String status;
  final String source;
  final String tenantName;
  final String callerPhone;
  final String? unitId;
  final String? buildingId;
  final List<String> photos;
  final DateTime? resolvedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory MaintenanceTicket.fromJson(Map<String, dynamic> json) {
    return MaintenanceTicket(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      urgency: json['urgency'] as String? ?? 'moyenne',
      status: json['status'] as String? ?? 'ouvert',
      source: json['source'] as String? ?? 'manual',
      tenantName: json['tenantName'] as String? ?? '',
      callerPhone: json['callerPhone'] as String? ?? '',
      unitId: json['unitId'] as String?,
      buildingId: json['buildingId'] as String?,
      photos: (json['photos'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
      resolvedAt: json['resolvedAt'] != null
          ? DateTime.tryParse(json['resolvedAt'] as String)
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'] as String)
          : null,
    );
  }

  String get urgencyLabel {
    switch (urgency) {
      case 'basse':
        return 'Basse';
      case 'haute':
        return 'Haute';
      case 'urgence':
        return 'Urgence';
      default:
        return 'Moyenne';
    }
  }

  String get statusLabel {
    switch (status) {
      case 'en_cours':
        return 'En cours';
      case 'resolu':
        return 'Résolu';
      default:
        return 'Ouvert';
    }
  }
}

class MaintenanceService {
  MaintenanceService._();
  static final MaintenanceService instance = MaintenanceService._();

  Future<MaintenanceCommandCenterData> getCommandCenter({
    String? buildingId,
    int limit = 12,
  }) async {
    final params = <String, String>{
      'limit': limit.toString(),
    };
    if (buildingId != null && buildingId.isNotEmpty) {
      params['buildingId'] = buildingId;
    }

    final query = params.entries
        .map((entry) => '${entry.key}=${Uri.encodeComponent(entry.value)}')
        .join('&');
    final path = query.isEmpty
        ? '/maintenance/command-center'
        : '/maintenance/command-center?$query';

    final result = await ApiService.instance.get(path);
    return MaintenanceCommandCenterData.fromJson(
      (result['data'] as Map<String, dynamic>?) ?? const {},
    );
  }

  /// GET /maintenance/tickets
  Future<List<MaintenanceTicket>> getTickets({
    String? status,
    String? urgency,
    String? search,
    int limit = 50,
  }) async {
    final params = <String, String>{'limit': limit.toString()};
    if (status != null && status.isNotEmpty) params['status'] = status;
    if (urgency != null && urgency.isNotEmpty) params['urgency'] = urgency;
    if (search != null && search.isNotEmpty) params['search'] = search;

    final query = params.entries
        .map((entry) => '${entry.key}=${Uri.encodeComponent(entry.value)}')
        .join('&');

    final result = await ApiService.instance.get('/maintenance/tickets?$query');
    final data = result['data'] as List<dynamic>? ?? const [];
    return data
        .map((e) => MaintenanceTicket.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// GET /maintenance/tickets/:id
  Future<MaintenanceTicket> getTicket(String id) async {
    final result = await ApiService.instance.get('/maintenance/tickets/$id');
    return MaintenanceTicket.fromJson(result['data'] as Map<String, dynamic>);
  }

  /// POST /maintenance/tickets
  Future<MaintenanceTicket> createTicket(Map<String, dynamic> data) async {
    final result = await ApiService.instance.post('/maintenance/tickets', data);
    return MaintenanceTicket.fromJson(result['data'] as Map<String, dynamic>);
  }

  /// PUT /maintenance/tickets/:id
  Future<MaintenanceTicket> updateTicket(
    String id,
    Map<String, dynamic> data,
  ) async {
    final result =
        await ApiService.instance.put('/maintenance/tickets/$id', data);
    return MaintenanceTicket.fromJson(result['data'] as Map<String, dynamic>);
  }

  /// GET /maintenance/tickets/open-count-by-building?buildingIds=...
  Future<Map<String, int>> getOpenTicketCountByBuilding(
    List<String> buildingIds,
  ) async {
    if (buildingIds.isEmpty) return {};
    final query = buildingIds.map((id) => Uri.encodeComponent(id)).join(',');
    final result = await ApiService.instance
        .get('/maintenance/tickets/open-count-by-building?buildingIds=$query');
    final data = result['data'] as Map<String, dynamic>? ?? {};
    return data.map((key, value) => MapEntry(key, (value as num).toInt()));
  }
}
