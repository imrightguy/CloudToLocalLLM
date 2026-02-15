import 'package:flutter/material.dart';
import '../../di/locator.dart' as di;
import '../../services/admin_center_service.dart';
import '../../models/admin_role_model.dart';

/// DNS Configuration Tab for the Admin Center
/// Allows administrators to manage DNS records (MX, SPF, DKIM, DMARC)
class DnsConfigTab extends StatefulWidget {
  const DnsConfigTab({super.key});

  @override
  State<DnsConfigTab> createState() => _DnsConfigTabState();
}

class _DnsConfigTabState extends State<DnsConfigTab> {
  // Form controllers
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _recordNameController = TextEditingController();
  final TextEditingController _recordValueController = TextEditingController();
  final TextEditingController _ttlController = TextEditingController(
    text: '3600',
  );

  // State
  bool _isLoading = false;
  bool _isSaving = false;
  bool _isValidating = false;
  String? _error;
  String? _successMessage;
  List<DnsRecord> _records = [];

  // Configuration
  String _selectedRecordType = 'MX'; // MX, SPF, DKIM, DMARC, CNAME

  @override
  void initState() {
    super.initState();
    _loadDnsRecords();
  }

  @override
  void dispose() {
    _recordNameController.dispose();
    _recordValueController.dispose();
    _ttlController.dispose();
    super.dispose();
  }

  /// Load DNS records
  Future<void> _loadDnsRecords() async {
    final adminService = di.serviceLocator.get<AdminCenterService>();

    // Check permission
    if (!adminService.hasPermission(AdminPermission.viewConfiguration)) {
      setState(() {
        _error = 'You do not have permission to view DNS configuration';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final recordsData = await adminService.getDnsRecords();
      final records = recordsData
          .map(
            (record) => DnsRecord(
              id: record['id'] ?? '',
              type: record['recordType'] ?? '',
              name: record['name'] ?? '',
              value: record['value'] ?? '',
              ttl: record['ttl'] ?? 3600,
              status: record['status'] ?? 'pending',
              validatedAt: record['validatedAt'] != null
                  ? DateTime.parse(record['validatedAt'])
                  : null,
            ),
          )
          .toList();

      setState(() {
        _isLoading = false;
        _records = records;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load DNS records: $e';
        _isLoading = false;
      });
    }
  }

  /// Create or update DNS record
  Future<void> _saveDnsRecord() async {
    if (_formKey.currentState == null || !_formKey.currentState!.validate()) {
      return;
    }

    final adminService = di.serviceLocator.get<AdminCenterService>();

    // Check permission
    if (!adminService.hasPermission(AdminPermission.editConfiguration)) {
      setState(() {
        _error = 'You do not have permission to edit DNS configuration';
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
      _successMessage = null;
    });

    try {
      await adminService.createDnsRecord(
        recordType: _selectedRecordType,
        name: _recordNameController.text,
        value: _recordValueController.text,
        ttl: int.parse(_ttlController.text),
      );

      setState(() {
        _isSaving = false;
        _successMessage = 'DNS record saved successfully';
        _recordNameController.clear();
        _recordValueController.clear();
        _ttlController.text = '3600';
      });

      await _loadDnsRecords();
    } catch (e) {
      setState(() {
        _error = 'Failed to save DNS record: $e';
        _isSaving = false;
      });
    }
  }

  /// Validate DNS records
  Future<void> _validateDnsRecords() async {
    final adminService = di.serviceLocator.get<AdminCenterService>();

    setState(() {
      _isValidating = true;
      _error = null;
      _successMessage = null;
    });

    try {
      await adminService.validateDnsRecords();

      setState(() {
        _isValidating = false;
        _successMessage = 'DNS records validated successfully';
      });

      await _loadDnsRecords();
    } catch (e) {
      setState(() {
        _error = 'Failed to validate DNS records: $e';
        _isValidating = false;
      });
    }
  }

  /// Delete DNS record
  Future<void> _deleteDnsRecord(String recordId) async {
    final adminService = di.serviceLocator.get<AdminCenterService>();

    // Check permission
    if (!adminService.hasPermission(AdminPermission.editConfiguration)) {
      setState(() {
        _error = 'You do not have permission to delete DNS records';
      });
      return;
    }

    try {
      await adminService.deleteDnsRecord(recordId);

      setState(() {
        _successMessage = 'DNS record deleted successfully';
      });

      await _loadDnsRecords();
    } catch (e) {
      setState(() {
        _error = 'Failed to delete DNS record: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'DNS Configuration',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Manage DNS records (MX, SPF, DKIM, DMARC) for email authentication',
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: Colors.grey.shade700),
              ),
            ],
          ),
        ),

        // Content
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // DNS Provider Info (Cloudflare only)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue.shade300),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.info, color: Colors.blue),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'DNS records are managed via Cloudflare API. Your domain (zoidbot.online) is configured with Cloudflare.',
                                  style: TextStyle(color: Colors.blue.shade900),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Add DNS Record Form
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Add DNS Record',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 16),

                                  // Record Type
                                  DropdownButtonFormField<String>(
                                    initialValue: _selectedRecordType,
                                    decoration: const InputDecoration(
                                      labelText: 'Record Type',
                                      border: OutlineInputBorder(),
                                    ),
                                    items: const [
                                      DropdownMenuItem(
                                        value: 'MX',
                                        child: Text('MX (Mail Exchange)'),
                                      ),
                                      DropdownMenuItem(
                                        value: 'SPF',
                                        child: Text(
                                          'SPF (Sender Policy Framework)',
                                        ),
                                      ),
                                      DropdownMenuItem(
                                        value: 'DKIM',
                                        child: Text(
                                          'DKIM (DomainKeys Identified Mail)',
                                        ),
                                      ),
                                      DropdownMenuItem(
                                        value: 'DMARC',
                                        child: Text(
                                          'DMARC (Domain-based Message Authentication)',
                                        ),
                                      ),
                                      DropdownMenuItem(
                                        value: 'CNAME',
                                        child: Text('CNAME (Canonical Name)'),
                                      ),
                                    ],
                                    onChanged: (value) {
                                      if (value != null) {
                                        setState(() {
                                          _selectedRecordType = value;
                                        });
                                      }
                                    },
                                  ),
                                  const SizedBox(height: 16),

                                  // Record Name
                                  TextFormField(
                                    controller: _recordNameController,
                                    decoration: const InputDecoration(
                                      labelText: 'Record Name',
                                      hintText: 'e.g., mail.example.com',
                                      border: OutlineInputBorder(),
                                    ),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Record name is required';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 16),

                                  // Record Value
                                  TextFormField(
                                    controller: _recordValueController,
                                    decoration: const InputDecoration(
                                      labelText: 'Record Value',
                                      hintText: 'e.g., 10 mail.example.com',
                                      border: OutlineInputBorder(),
                                    ),
                                    maxLines: 3,
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Record value is required';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 16),

                                  // TTL
                                  TextFormField(
                                    controller: _ttlController,
                                    decoration: const InputDecoration(
                                      labelText: 'TTL (Time To Live)',
                                      hintText: '3600',
                                      border: OutlineInputBorder(),
                                    ),
                                    keyboardType: TextInputType.number,
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'TTL is required';
                                      }
                                      if (int.tryParse(value) == null) {
                                        return 'TTL must be a number';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 16),

                                  // Error message
                                  if (_error != null)
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.red.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: Colors.red.shade300,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.error_outline,
                                            color: Colors.red,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              _error!,
                                              style: const TextStyle(
                                                color: Colors.red,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                  // Success message
                                  if (_successMessage != null)
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.green.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: Colors.green.shade300,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.check_circle,
                                            color: Colors.green,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              _successMessage!,
                                              style: const TextStyle(
                                                color: Colors.green,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                  const SizedBox(height: 16),

                                  // Action buttons
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      ElevatedButton(
                                        onPressed:
                                            _isSaving ? null : _saveDnsRecord,
                                        child: _isSaving
                                            ? const SizedBox(
                                                width: 16,
                                                height: 16,
                                                child:
                                                    CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                ),
                                              )
                                            : const Text('Save Record'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // DNS Records List
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'DNS Records',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            ElevatedButton.icon(
                              onPressed:
                                  _isValidating ? null : _validateDnsRecords,
                              icon: const Icon(Icons.check_circle),
                              label: _isValidating
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text('Validate All'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        if (_records.isEmpty)
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32.0),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.dns,
                                    size: 48,
                                    color: Colors.grey.shade300,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No DNS records configured',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              columns: const [
                                DataColumn(label: Text('Type')),
                                DataColumn(label: Text('Name')),
                                DataColumn(label: Text('Value')),
                                DataColumn(label: Text('TTL')),
                                DataColumn(label: Text('Status')),
                                DataColumn(label: Text('Actions')),
                              ],
                              rows: _records
                                  .map(
                                    (record) => DataRow(
                                      cells: [
                                        DataCell(Text(record.type)),
                                        DataCell(Text(record.name)),
                                        DataCell(
                                          SizedBox(
                                            width: 200,
                                            child: Text(
                                              record.value,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ),
                                        DataCell(Text(record.ttl.toString())),
                                        DataCell(
                                          Chip(
                                            label: Text(record.status),
                                            backgroundColor:
                                                record.status == 'valid'
                                                    ? Colors.green.shade100
                                                    : Colors.orange.shade100,
                                          ),
                                        ),
                                        DataCell(
                                          IconButton(
                                            icon: const Icon(
                                              Icons.delete,
                                              color: Colors.red,
                                            ),
                                            onPressed: () =>
                                                _deleteDnsRecord(record.id),
                                            tooltip: 'Delete Record',
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                  .toList(),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

/// DNS Record model
class DnsRecord {
  final String id;
  final String type;
  final String name;
  final String value;
  final int ttl;
  final String status;
  final DateTime? validatedAt;

  DnsRecord({
    required this.id,
    required this.type,
    required this.name,
    required this.value,
    required this.ttl,
    required this.status,
    this.validatedAt,
  });
}
