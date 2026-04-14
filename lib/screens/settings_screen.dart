import 'package:flutter/material.dart';

import '../models.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/notification_preferences_service.dart';

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
  String _phone = '';
  String _role = '';
  String _company = '';

  // Edit mode
  bool _isEditing = false;
  late final TextEditingController _firstNameCtrl;
  late final TextEditingController _lastNameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _companyCtrl;

  bool _isSaving = false;

  // Notification preferences
  bool _notifLoading = false;
  NotificationPreferences _notifPrefs = const NotificationPreferences();

  // Theme mode
  ThemeMode _themeMode = ThemeMode.system;

  // Password change
  bool _isChangingPassword = false;
  final _currentPasswordCtrl = TextEditingController();
  final _newPasswordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _firstNameCtrl = TextEditingController();
    _lastNameCtrl = TextEditingController();
    _phoneCtrl = TextEditingController();
    _companyCtrl = TextEditingController();
    _loadProfile();
    _loadNotificationPreferences();
    _loadThemeMode();
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _phoneCtrl.dispose();
    _companyCtrl.dispose();
    _currentPasswordCtrl.dispose();
    _newPasswordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
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
        _firstName = profile.firstName;
        _lastName = profile.lastName;
        _email = profile.email;
        _phone = profile.phone ?? '';
        _role = profile.role ?? '';
        _company = profile.company ?? '';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadNotificationPreferences() async {
    setState(() => _notifLoading = true);
    try {
      await NotificationPreferencesService.instance.fetchPreferences();
      if (mounted) {
        setState(() {
          _notifPrefs = NotificationPreferencesService.instance.prefs;
          _notifLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _notifLoading = false);
    }
  }

  Future<void> _loadThemeMode() async {
    final prefs = await ApiService.instance.getThemeMode();
    if (mounted) setState(() => _themeMode = prefs);
  }

  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);
    try {
      await AuthNotifier.instance.updateProfile({
        'firstName': _firstNameCtrl.text.trim(),
        'lastName': _lastNameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'company': _companyCtrl.text.trim(),
      });
      setState(() {
        _firstName = _firstNameCtrl.text.trim();
        _lastName = _lastNameCtrl.text.trim();
        _phone = _phoneCtrl.text.trim();
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

  Future<void> _saveNotificationPreferences() async {
    setState(() => _notifLoading = true);
    try {
      await NotificationPreferencesService.instance
          .updatePreferences(_notifPrefs);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Préférences de notification enregistrées'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
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
    } finally {
      if (mounted) setState(() => _notifLoading = false);
    }
  }

  Future<void> _setThemeMode(ThemeMode mode) async {
    setState(() => _themeMode = mode);
    await ApiService.instance.setThemeMode(mode);
  }

  Future<void> _handleChangePassword() async {
    final current = _currentPasswordCtrl.text.trim();
    final newPwd = _newPasswordCtrl.text.trim();
    final confirm = _confirmPasswordCtrl.text.trim();

    if (current.isEmpty || newPwd.isEmpty || confirm.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez remplir tous les champs'),
          backgroundColor: Color(0xFFF59E0B),
        ),
      );
      return;
    }
    if (newPwd != confirm) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Les mots de passe ne correspondent pas'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    setState(() => _isChangingPassword = true);
    try {
      await AuthNotifier.instance.changePassword(
        currentPassword: current,
        newPassword: newPwd,
      );
      _currentPasswordCtrl.clear();
      _newPasswordCtrl.clear();
      _confirmPasswordCtrl.clear();
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Mot de passe modifié avec succès'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
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
    } finally {
      if (mounted) setState(() => _isChangingPassword = false);
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
            style:
                TextButton.styleFrom(foregroundColor: const Color(0xFFEF4444)),
            child: const Text('Déconnexion'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await AuthNotifier.instance.logout();
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    }
  }

  Future<void> _handleDeleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer le compte?'),
        content: const Text(
            'Cette action est irréversible. Toutes vos données seront supprimées.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style:
                TextButton.styleFrom(foregroundColor: const Color(0xFFEF4444)),
            child: const Text('Supprimer définitivement'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ApiService.instance.delete('/users/me');
      await AuthNotifier.instance.logout();
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Compte supprimé'),
            backgroundColor: Color(0xFFEF4444),
          ),
        );
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

  String _getThemeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'Clair';
      case ThemeMode.dark:
        return 'Sombre';
      case ThemeMode.system:
        return 'Système';
    }
  }

  String _formatTimeOfDay(TimeOfDay? t) {
    if (t == null) return '--:--';
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _pickTime(TimeOfDay? current, ValueChanged<TimeOfDay> onPicked) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: current ?? const TimeOfDay(hour: 22, minute: 0),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked != null) onPicked(picked);
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
                      _buildProfileCard(),
                      const SizedBox(height: 24),

                      const Text('Notifications',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E293B),
                          )),
                      const SizedBox(height: 8),
                      _buildNotificationCard(),
                      const SizedBox(height: 24),

                      const Text('Apparence',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E293B),
                          )),
                      const SizedBox(height: 8),
                      _buildAppearanceCard(),
                      const SizedBox(height: 24),

                      const Text('Compte',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E293B),
                          )),
                      const SizedBox(height: 8),
                      _buildAccountCard(),
                      const SizedBox(height: 24),

                      const Text('À propos',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E293B),
                          )),
                      const SizedBox(height: 8),
                      _buildAboutCard(),
                      const SizedBox(height: 24),

                      _buildLogoutButton(),
                      const SizedBox(height: 16),
                      _buildDeleteAccountButton(),
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
        decoration: _cardDecoration(),
        child: Column(
          children: [
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
            _editField('Prénom', _firstName, _firstNameCtrl, Icons.person_outline),
            const SizedBox(height: 12),
            _editField('Nom', _lastName, _lastNameCtrl, Icons.person_outline),
            const SizedBox(height: 12),
            _editField('Téléphone', _phone, _phoneCtrl, Icons.phone_outlined),
            const SizedBox(height: 12),
            _editField('Entreprise', _company, _companyCtrl, Icons.business_outlined),
            const SizedBox(height: 8),

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
      decoration: _cardDecoration(),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 36,
                backgroundColor: const Color(0xFF0F766E).withValues(alpha: 0.1),
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
                  _phoneCtrl.text = _phone;
                  _companyCtrl.text = _company;
                  setState(() => _isEditing = true);
                },
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Modifier le profil',
              ),
            ],
          ),

          const Divider(height: 24),

          _infoRow(Icons.badge_outlined, 'Rôle', _getRoleLabel()),
          if (_phone.isNotEmpty) ...[
            const SizedBox(height: 12),
            _infoRow(Icons.phone_outlined, 'Téléphone', _phone),
          ],
          if (_company.isNotEmpty) ...[
            const SizedBox(height: 12),
            _infoRow(Icons.business_outlined, 'Entreprise', _company),
          ],
        ],
      ),
    );
  }

  Widget _editField(String label, String value, TextEditingController ctrl, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: const Color(0xFF64748B)),
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
  // Notification preferences card
  // ---------------------------------------------------------------------------

  Widget _buildNotificationCard() {
    if (_notifLoading) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: _cardDecoration(),
        child: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      decoration: _cardDecoration(),
      child: Column(
        children: [
          _switchTile(
            icon: Icons.email_outlined,
            title: 'Notifications par courriel',
            subtitle: 'Recevoir les alertes par courriel',
            value: _notifPrefs.emailNotifications,
            onChanged: (v) {
              setState(() => _notifPrefs = _notifPrefs.copyWith(emailNotifications: v));
              _saveNotificationPreferences();
            },
          ),
          const Divider(height: 1, indent: 56),
          _switchTile(
            icon: Icons.sms_outlined,
            title: 'Notifications par SMS',
            subtitle: 'Recevoir les alertes par texto',
            value: _notifPrefs.smsNotifications,
            onChanged: (v) {
              setState(() => _notifPrefs = _notifPrefs.copyWith(smsNotifications: v));
              _saveNotificationPreferences();
            },
          ),
          const Divider(height: 1, indent: 56),
          _switchTile(
            icon: Icons.mail_outline,
            title: 'Résumé hebdomadaire',
            subtitle: 'Recevoir un résumé chaque lundi',
            value: _notifPrefs.weeklyDigest,
            onChanged: (v) {
              setState(() => _notifPrefs = _notifPrefs.copyWith(weeklyDigest: v));
              _saveNotificationPreferences();
            },
          ),
          const Divider(height: 1, indent: 56),
          _switchTile(
            icon: Icons.bedtime_outlined,
            title: 'Heures silencieuses',
            subtitle: _notifPrefs.quietHoursEnabled
                ? '${_formatTimeOfDay(_notifPrefs.quietHoursStart)} – ${_formatTimeOfDay(_notifPrefs.quietHoursEnd)}'
                : 'Désactivées',
            value: _notifPrefs.quietHoursEnabled,
            onChanged: (v) {
              setState(() => _notifPrefs = _notifPrefs.copyWith(quietHoursEnabled: v));
              _saveNotificationPreferences();
            },
          ),
          if (_notifPrefs.quietHoursEnabled) ...[
            const Divider(height: 1, indent: 56),
            _settingsTile(
              icon: Icons.schedule,
              title: 'Début',
              subtitle: _formatTimeOfDay(_notifPrefs.quietHoursStart),
              onTap: () async {
                await _pickTime(_notifPrefs.quietHoursStart, (t) {
                  setState(() => _notifPrefs = _notifPrefs.copyWith(quietHoursStart: t));
                  _saveNotificationPreferences();
                });
              },
            ),
            const Divider(height: 1, indent: 56),
            _settingsTile(
              icon: Icons.schedule_outlined,
              title: 'Fin',
              subtitle: _formatTimeOfDay(_notifPrefs.quietHoursEnd),
              onTap: () async {
                await _pickTime(_notifPrefs.quietHoursEnd, (t) {
                  setState(() => _notifPrefs = _notifPrefs.copyWith(quietHoursEnd: t));
                  _saveNotificationPreferences();
                });
              },
            ),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Appearance card
  // ---------------------------------------------------------------------------

  Widget _buildAppearanceCard() {
    return Container(
      width: double.infinity,
      decoration: _cardDecoration(),
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
            subtitle: _getThemeLabel(_themeMode),
            trailing: _themeMode == ThemeMode.light
                ? '☀️'
                : _themeMode == ThemeMode.dark
                    ? '🌙'
                    : '💻',
            onTap: () {
              _showThemePicker();
            },
          ),
        ],
      ),
    );
  }

  void _showThemePicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Choisir le thème',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 16),
            RadioListTile<ThemeMode>(
              value: ThemeMode.system,
              groupValue: _themeMode,
              title: const Text('Système'),
              subtitle: const Text('Suivre les paramètres de l\'appareil',
                  style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
              secondary: const Text('💻'),
              activeColor: const Color(0xFF0F766E),
              onChanged: (v) {
                Navigator.of(ctx).pop();
                if (v != null) _setThemeMode(v);
              },
            ),
            RadioListTile<ThemeMode>(
              value: ThemeMode.light,
              groupValue: _themeMode,
              title: const Text('Clair'),
              subtitle: const Text('Thème clair permanent',
                  style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
              secondary: const Text('☀️'),
              activeColor: const Color(0xFF0F766E),
              onChanged: (v) {
                Navigator.of(ctx).pop();
                if (v != null) _setThemeMode(v);
              },
            ),
            RadioListTile<ThemeMode>(
              value: ThemeMode.dark,
              groupValue: _themeMode,
              title: const Text('Sombre'),
              subtitle: const Text('Thème sombre permanent',
                  style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
              secondary: const Text('🌙'),
              activeColor: const Color(0xFF0F766E),
              onChanged: (v) {
                Navigator.of(ctx).pop();
                if (v != null) _setThemeMode(v);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Account card
  // ---------------------------------------------------------------------------

  Widget _buildAccountCard() {
    return Container(
      width: double.infinity,
      decoration: _cardDecoration(),
      child: Column(
        children: [
          _settingsTile(
            icon: Icons.lock_outline,
            title: 'Changer le mot de passe',
            subtitle: 'Modifier votre mot de passe',
            onTap: _showChangePasswordDialog,
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog() {
    _currentPasswordCtrl.clear();
    _newPasswordCtrl.clear();
    _confirmPasswordCtrl.clear();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Changer le mot de passe'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _currentPasswordCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Mot de passe actuel',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _newPasswordCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Nouveau mot de passe',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _confirmPasswordCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Confirmer le mot de passe',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: _isChangingPassword ? null : _handleChangePassword,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F766E),
              foregroundColor: Colors.white,
            ),
            child: _isChangingPassword
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child:
                        CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Enregistrer'),
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
      decoration: _cardDecoration(),
      child: Column(
        children: [
          _settingsTile(
            icon: Icons.info_outline,
            title: 'Version',
            subtitle: '1.0.0',
            onTap: null,
          ),
          const Divider(height: 1, indent: 56),
          _settingsTile(
            icon: Icons.code_outlined,
            title: 'Développé par',
            subtitle: 'ImmoGestion Inc.',
            onTap: null,
          ),
          const Divider(height: 1, indent: 56),
          _settingsTile(
            icon: Icons.description_outlined,
            title: 'Conditions d\'utilisation',
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
  // Danger zone
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

  Widget _buildDeleteAccountButton() {
    return SizedBox(
      width: double.infinity,
      child: TextButton.icon(
        onPressed: _handleDeleteAccount,
        icon: const Icon(Icons.delete_forever, size: 18),
        label: const Text('Supprimer mon compte'),
        style: TextButton.styleFrom(
          foregroundColor: const Color(0xFFCBD5E1),
          padding: const EdgeInsets.symmetric(vertical: 10),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Reusable widgets
  // ---------------------------------------------------------------------------

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 10,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }

  Widget _settingsTile({
    required IconData icon,
    required String title,
    String subtitle = '',
    String trailing = '',
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
                color: Color(0xFF94A3B8,
),
                fontWeight: FontWeight.w500,
              ),
            )
          : onTap != null
              ? const Icon(Icons.chevron_right, color: Color(0xFFCBD5E1))
              : null,
      onTap: onTap,
    );
  }

  Widget _switchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      secondary: Container(
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
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
      ),
      value: value,
      activeColor: const Color(0xFF0F766E),
      onChanged: onChanged,
    );
  }
}
