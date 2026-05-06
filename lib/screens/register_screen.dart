import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/api_service.dart';
import 'login_screen.dart';
import 'home_screen.dart';
import '../theme/app_colors.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _AccountExistsNotice extends StatelessWidget {
  const _AccountExistsNotice({
    required this.message,
    required this.onSignIn,
  });

  final String message;
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  color: Colors.orange,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    message,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onSignIn,
                icon: const Icon(Icons.login_rounded),
                label: const Text('Se connecter'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _accountExistsMessage;

  @override
  void initState() {
    super.initState();
    void clearNotice() {
      if (!mounted || _accountExistsMessage == null) return;
      setState(() => _accountExistsMessage = null);
    }

    _firstNameController.addListener(clearNotice);
    _lastNameController.addListener(clearNotice);
    _emailController.addListener(clearNotice);
    _passwordController.addListener(clearNotice);
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await AuthNotifier.instance.register(
        _firstNameController.text.trim(),
        _lastNameController.text.trim(),
        _emailController.text.trim(),
        _passwordController.text,
      );

      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const HomeScreen()),
        (route) => false,
      );
    } on ApiException catch (e) {
      if (!mounted) return;

      if (e.isDuplicateAccount) {
        setState(() {
          _accountExistsMessage = e.userFacingMessage;
        });
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.userFacingMessage),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Une erreur inattendue est survenue'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth >= 900;
            return Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: isDesktop ? 32 : 24,
                  vertical: isDesktop ? 24 : 8,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: isDesktop ? 720 : 400,
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.08),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.person_add_rounded,
                            size: 44,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Créer un compte',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Rejoignez ImmoGestion',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 28),

                        Row(
                          children: [
                            Expanded(child: _buildLabel('Prénom')),
                            const SizedBox(width: 16),
                            Expanded(child: _buildLabel('Nom')),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _firstNameController,
                                textInputAction: TextInputAction.next,
                                textCapitalization: TextCapitalization.words,
                                autofillHints: const [AutofillHints.givenName],
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                                cursorColor: AppColors.textPrimary,
                                validator: (v) => (v == null || v.trim().isEmpty)
                                    ? 'Requis'
                                    : null,
                                decoration: _inputDecoration(
                                  hintText: 'Simon',
                                  prefixIcon: Icons.person_outline_rounded,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _lastNameController,
                                textInputAction: TextInputAction.next,
                                textCapitalization: TextCapitalization.words,
                                autofillHints: const [AutofillHints.familyName],
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                                cursorColor: AppColors.textPrimary,
                                validator: (v) => (v == null || v.trim().isEmpty)
                                    ? 'Requis'
                                    : null,
                                decoration: _inputDecoration(
                                  hintText: 'Tremblay',
                                  prefixIcon: Icons.person_outline_rounded,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        _buildLabel('Adresse courriel'),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.username, AutofillHints.email],
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          cursorColor: AppColors.textPrimary,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Veuillez entrer votre courriel';
                            }
                            final emailRegex =
                                RegExp(r'^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$');
                            if (!emailRegex.hasMatch(value.trim())) {
                              return 'Format invalide';
                            }
                            return null;
                          },
                          decoration: _inputDecoration(
                            hintText: 'nom@exemple.com',
                            prefixIcon: Icons.mail_outline_rounded,
                          ),
                        ),
                        const SizedBox(height: 20),

                        _buildLabel('Mot de passe'),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _handleRegister(),
                          autofillHints: const [AutofillHints.newPassword],
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          cursorColor: AppColors.textPrimary,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Veuillez entrer un mot de passe';
                            }
                            if (value.length < 6) {
                              return 'Minimum 6 caractères';
                            }
                            return null;
                          },
                          decoration: _inputDecoration(
                            hintText: '••••••••',
                            prefixIcon: Icons.lock_outline_rounded,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: AppColors.textMuted,
                              ),
                              onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword),
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),

                        if (_accountExistsMessage != null) ...[
                          _AccountExistsNotice(
                            message: _accountExistsMessage!,
                            onSignIn: () {
                              Navigator.of(context).pushAndRemoveUntil(
                                MaterialPageRoute<void>(
                                  builder: (_) => const LoginScreen(),
                                ),
                                (route) => false,
                              );
                            },
                          ),
                          const SizedBox(height: 16),
                        ],

                        SizedBox(
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _handleRegister,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor:
                                  AppColors.primary.withValues(alpha: 0.5),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              elevation: 0,
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: AppColors.surface,
                                    ),
                                  )
                                : const Text(
                                    'Créer mon compte',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute<void>(
                                builder: (_) => const LoginScreen(),
                              ),
                              (route) => route.isFirst,
                            );
                          },
                          child: RichText(
                            text: const TextSpan(
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 14,
                              ),
                              children: [
                                TextSpan(text: 'Déjà un compte? '),
                                TextSpan(
                                  text: 'Se connecter',
                                  style: TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: AppColors.label,
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hintText,
    required IconData prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(
        color: AppColors.label,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      prefixIcon: Icon(prefixIcon, color: AppColors.label, size: 20),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
      ),
    );
  }
}
