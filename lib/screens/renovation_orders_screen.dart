import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/renovation_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../widgets/immo_app_bar.dart';

class RenovationOrdersScreen extends StatefulWidget {
  const RenovationOrdersScreen({
    super.key,
    required this.renovationId,
    required this.unitLabel,
  });

  final String renovationId;
  final String unitLabel;

  @override
  State<RenovationOrdersScreen> createState() => _RenovationOrdersScreenState();
}

class _RenovationOrdersScreenState extends State<RenovationOrdersScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<RenovationOrder> _orders = [];

  @override
  void initState() {
    super.initState();
    _fetchOrders();
  }

  Future<void> _fetchOrders() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final orders =
          await RenovationService.instance.getOrders(widget.renovationId);
      setState(() {
        _orders = orders;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'received':
        return AppColors.success;
      case 'partially_received':
        return AppColors.warning;
      case 'cancelled':
        return AppColors.error;
      case 'ordered':
        return AppColors.info;
      default:
        return AppColors.textMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ImmoAppBar(
        title: 'Commandes — ${widget.unitLabel}',
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showCreateDialog,
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
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 16),
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
              onPressed: _fetchOrders,
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchOrders,
      child: _orders.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 120),
                Center(
                  child: Text(
                    'Aucune commande de matériaux',
                    style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                  ),
                ),
              ],
            )
          : ListView.builder(
              padding: const EdgeInsets.all(AppSpacing.md),
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: _orders.length,
              itemBuilder: (context, index) => _buildOrderCard(_orders[index]),
            ),
    );
  }

  Widget _buildOrderCard(RenovationOrder order) {
    final expectedLabel = order.expectedAt != null
        ? DateFormat('d MMM yyyy', 'fr').format(order.expectedAt!)
        : null;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    order.itemName,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _statusColor(order.status).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                  ),
                  child: Text(
                    order.statusLabel,
                    style: TextStyle(
                      fontSize: 11,
                      color: _statusColor(order.status),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              order.vendorName,
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.inventory_2_outlined, size: 14, color: AppColors.textMuted),
                const SizedBox(width: 4),
                Text(
                  'Reçu ${order.quantityReceived}/${order.quantityOrdered}',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                if (expectedLabel != null) ...[
                  const SizedBox(width: 12),
                  const Icon(Icons.event_outlined, size: 14, color: AppColors.textMuted),
                  const SizedBox(width: 4),
                  Text(expectedLabel,
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ],
              ],
            ),
            if (order.status != 'received' && order.status != 'cancelled') ...[
              const SizedBox(height: AppSpacing.sm),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _markReceived(order),
                  icon: const Icon(Icons.check_circle_outline, size: 18),
                  label: const Text('Marquer reçue'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _markReceived(RenovationOrder order) async {
    try {
      await RenovationService.instance.markReceived(
        order.id,
        order.quantityOrdered,
        order.quantityOrdered,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Commande reçue'), backgroundColor: AppColors.success),
      );
      _fetchOrders();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  void _showCreateDialog() {
    final vendorController = TextEditingController();
    final itemController = TextEditingController();
    final qtyController = TextEditingController(text: '1');

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Nouvelle commande'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: itemController,
                  decoration: const InputDecoration(labelText: 'Matériau'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: vendorController,
                  decoration: const InputDecoration(labelText: 'Fournisseur'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: qtyController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Quantité'),
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
                final item = itemController.text.trim();
                final vendor = vendorController.text.trim();
                final qty = int.tryParse(qtyController.text.trim()) ?? 0;
                if (item.isEmpty || vendor.isEmpty || qty <= 0) return;
                Navigator.of(dialogContext).pop();
                await _createOrder(vendor, item, qty);
              },
              child: const Text('Créer'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _createOrder(String vendor, String item, int qty) async {
    try {
      await RenovationService.instance.createOrder(
        widget.renovationId,
        vendorName: vendor,
        itemName: item,
        quantityOrdered: qty,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Commande créée'), backgroundColor: AppColors.success),
      );
      _fetchOrders();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: AppColors.error),
      );
    }
  }
}
