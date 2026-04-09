import 'package:flutter/material.dart';

import '../services/api_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isLoading = true;
  String? _errorMessage;

  // Profile fields
  String _firstName = '';
  String _lastName = '';
  String _email = '';
  String _role = '';
  String _company = '';

  // Edit mode
  bool _isEditing = false;
  late final TextEditingController _firstNameCtrl;
  late final TextEditingController _lastNameCtrl;
  late final TextEditingController _companyCtrl;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _firstNameCtrl = TextEditingController();
    _lastNameCtrl = TextEditingController();
    _companyCtrl = TextEditingController();
    _loadProfile();
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _companyCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final profile = await ApiService.instance.getProfile();
      setState(() {
        _firstName = profile['firstName'] as String? ?? '';
        _lastName = profile['lastName'] as String? ?? '';
        _email = profile['email'] as String? ?? '';
        _role = profile['role'] as String? ?? '';
        _company = profile['company'] as String? ?? '';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);
    try {
      await ApiService.instance.patch('/auth/profile', {
        'firstName': _firstNameCtrl.text.trim(),
        'lastName': _lastNameCtrl.text.trim(),
        'company': _companyCtrl.text.trim(),
      });
      setState(() {
        _firstName = _firstNameCtrl.text.trim();
        _lastName = _lastNameCtrl.text.trim();
        _company = _companyCtrl.text.trim();
        _isEditing = false;
        _isSaving = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profil mis à jour'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      setState(() => _isSaving = false);
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

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Se déconnecter?'),
        content: const Text(
            'Vous devrez vous reconnecter pour accéder à l\'application.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFEF4444)),
            child: const Text('Déconnexion'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await ApiService.instance.logout();
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    }
  }

  String _getRoleLabel() {
    switch (_role.toLowerCase()) {
      case 'admin':
        return 'Administrateur';
      case 'manager':
        return 'Gestionnaire';
      case 'agent':
        return 'Agent';
      case 'owner':
        return 'Propriétaire';
      default:
        return _role.isNotEmpty ? _role : 'Utilisateur';
    }
  }

  String _getInitials() {
    final first = _firstName.isNotEmpty ? _firstName[0].toUpperCase() : '';
    final last = _lastName.isNotEmpty ? _lastName[0].toUpperCase() : '';
    return '$first$last';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Paramètres'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline,
                          size: 48, color: Color(0xFFEF4444)),
                      const SizedBox(height: 16),
                      const Text('Erreur de chargement',
                          style: TextStyle(
                              fontSize: 16, color: Color(0xFF1E293B))),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(_errorMessage!,
                            style: const TextStyle(
                                fontSize: 12, color: Color(0xFF64748B)),
                            textAlign: TextAlign.center),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _loadProfile,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Réessayer'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F766E),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // -- Profile card --
                      _buildProfileCard(),
                      const SizedBox(height: 24),

                      // -- Preferences --
                      const Text('Préférences',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E293B),
                          )),
                      const SizedBox(height: 8),
                      _buildPreferencesCard(),
                      const SizedBox(height: 24),

                      // -- About --
                      const Text('À propos',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E293B),
                          )),
                      const SizedBox(height: 8),
                      _buildAboutCard(),
                      const SizedBox(height: 24),

                      // -- Danger zone --
                      _buildLogoutButton(),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
    );
  }

  // ---------------------------------------------------------------------------
  // Profile card
  // ---------------------------------------------------------------------------

  Widget _buildProfileCard() {
    if (_isEditing) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            // Avatar
            CircleAvatar(
              radius: 40,
              backgroundColor: const Color(0xFF0F766E).withValues(alpha: 0.1),
              child: Text(
                _getInitials(),
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F766E),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Editable fields
            _editField('Prénom', _firstName, _firstNameCtrl),
            const SizedBox(height: 12),
            _editField('Nom', _lastName, _lastNameCtrl),
            const SizedBox(height: 12),
            _editField('Entreprise', _company, _companyCtrl),
            const SizedBox(height: 8),

            // Email (read-only)
            Row(
              children: [
                const Icon(Icons.email_outlined,
                    size: 20, color: Color(0xFF94A3B8)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Courriel',
                          style: TextStyle(
                              fontSize: 12, color: Color(0xFF94A3B8))),
                      Text(_email,
                          style: const TextStyle(
                              fontSize: 14, color: Color(0xFF64748B))),
                    ],
                  ),
                ),
              ],
            ),

            const Divider(height: 24),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isSaving
                        ? null
                        : () => setState(() {
                              _isEditing = false;
                            }),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF64748B),
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Annuler'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F766E),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Sauvegarder'),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 36,
                backgroundColor:
                    const Color(0xFF0F766E).withValues(alpha: 0.1),
                child: Text(
                  _getInitials(),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F766E),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$_firstName $_lastName'.trim().isEmpty
                          ? 'Utilisateur'
                          : '$_firstName $_lastName',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _email,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () {
                  _firstNameCtrl.text = _firstName;
                  _lastNameCtrl.text = _lastName;
                  _companyCtrl.text = _company;
                  setState(() => _isEditing = true);
                },
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Modifier le profil',
              ),
            ],
          ),

          const Divider(height: 24),

          // Info rows
          _infoRow(Icons.badge_outlined, 'Rôle', _getRoleLabel()),
          if (_company.isNotEmpty) ...[
            const SizedBox(height: 12),
            _infoRow(Icons.business_outlined, 'Entreprise', _company),
          ],
        ],
      ),
    );
  }

  Widget _editField(String label, String value, TextEditingController ctrl) {
    return Row(
      children: [
        const Icon(Icons.person_outline, size: 20, color: Color(0xFF64748B)),
        const SizedBox(width: 12),
        Expanded(
          child: TextField(
            controller: ctrl,
            decoration: InputDecoration(
              labelText: label,
              border: const OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ),
      ],
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: const Color(0xFF64748B)),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
            Text(value,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF1E293B))),
          ],
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Preferences card
  // ---------------------------------------------------------------------------

  Widget _buildPreferencesCard() {
    return Container(
      width: double.infinity,
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
        children: [
          _settingsTile(
            icon: Icons.language_outlined,
            title: 'Langue',
            subtitle: 'Français (Canada)',
            trailing: 'FR',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Langue: Français — bientôt plus d\'options'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
          const Divider(height: 1, indent: 56),
          _settingsTile(
            icon: Icons.palette_outlined,
            title: 'Thème',
            subtitle: 'Clair',
            trailing: '☀️',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Thème sombre bientôt disponible'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
          const Divider(height: 1, indent: 56),
          _settingsTile(
            icon: Icons.notifications_outlined,
            title: 'Notifications',
            subtitle: 'Actives',
            trailing: '',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Gestion des notifications bientôt disponible'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // About card
  // ---------------------------------------------------------------------------

  Widget _buildAboutCard() {
    return Container(
      width: double.infinity,
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
        children: [
          _settingsTile(
            icon: Icons.info_outline,
            title: 'Version',
            subtitle: '1.0.0',
            trailing: '',
            onTap: null,
          ),
          const Divider(height: 1, indent: 56),
          _settingsTile(
            icon: Icons.code_outlined,
            title: 'Développé par',
            subtitle: 'ImmoGestion Inc.',
            trailing: '',
            onTap: null,
          ),
          const Divider(height: 1, indent: 56),
          _settingsTile(
            icon: Icons.description_outlined,
            title: 'Conditions d\'utilisation',
            subtitle: '',
            trailing: '',
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: 'ImmoGestion',
                applicationVersion: '1.0.0',
                applicationIcon: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F766E).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.apartment,
                      color: Color(0xFF0F766E), size: 28),
                ),
                children: [
                  const Text(
                    'ImmoGestion — Leasing automation engine pour gestionnaires immobiliers au Québec.',
                    style: TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '© 2025 ImmoGestion Inc. Tous droits réservés.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Logout
  // ---------------------------------------------------------------------------

  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _handleLogout,
        icon: const Icon(Icons.logout, size: 20),
        label: const Text('Se déconnecter'),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFFEF4444),
          side: const BorderSide(color: Color(0xFFFCA5A5),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Reusable settings tile
  // ---------------------------------------------------------------------------

  Widget _settingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required String trailing,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 20, color: const Color(0xFF64748B)),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: Color(0xFF1E293B),
        ),
      ),
      subtitle: subtitle.isNotEmpty
          ? Text(
              subtitle,
              style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
            )
          : null,
      trailing: trailing.isNotEmpty
          ? Text(
              trailing,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF94A3B8),
                fontWeight: FontWeight.w500,
              ),
            )
          : onTap != null
              ? const Icon(Icons.chevron_right, color: Color(0xFFCBD5E1))
              : null,
      onTap: onTap,
    );
  }
}
