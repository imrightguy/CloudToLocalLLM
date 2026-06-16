import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Error state with distinct messages per error category.
///
/// Never shows "Vérifiez votre connexion internet" for a parsing bug.
/// Uses [ApiException.errorType] to pick the right message.
class ErrorState extends StatelessWidget {
  const ErrorState({
    super.key,
    required this.error,
    this.onRetry,
    this.title,
    this.showDiagnostic = false,
    this.compact = false,
  });

  final Object error;
  final VoidCallback? onRetry;
  final String? title;
  final bool showDiagnostic;
  final bool compact;

  // ── helpers ──

  ApiException? get _apiError => error is ApiException ? error as ApiException : null;

  ApiErrorType get _errorType => _apiError?.errorType ?? ApiErrorType.unknown;

  int? get _statusCode => _apiError?.statusCode;

  String? get _endpoint => _apiError?.endpoint;

  // ── title ──

  String get _friendlyTitle {
    if (title != null) return title!;

    switch (_errorType) {
      case ApiErrorType.network:
        return 'Aucune connexion au serveur';
      case ApiErrorType.parse:
        return 'Erreur de traitement des données';
      case ApiErrorType.server:
        return _serverTitle;
      case ApiErrorType.auth:
        return 'Session expirée';
      case ApiErrorType.unknown:
        return _fallbackTitle;
    }
  }

  String get _serverTitle {
    switch (_statusCode) {
      case 503: return 'Service temporairement indisponible';
      case 502: return 'Passerelle inaccessible';
      case 504: return 'Délai dépassé';
      case 404: return 'Ressource introuvable';
      case 500: return 'Erreur serveur';
      default: return 'Erreur serveur (${_statusCode ?? '?'})';
    }
  }

  String get _fallbackTitle {
    switch (_statusCode) {
      case 401:
      case 403: return 'Accès refusé';
      case null: return 'Une erreur est survenue';
      default: return 'Erreur $_statusCode';
    }
  }

  // ── description ──

  String get _friendlyDescription {
    switch (_errorType) {
      case ApiErrorType.network:
        return 'Impossible de contacter le serveur. Vérifiez votre connexion internet et réessayez.';
      case ApiErrorType.parse:
        return 'Les données reçues du serveur sont dans un format inattendu. '
            'Ce problème a été signalé automatiquement. Réessayez dans quelques minutes.';
      case ApiErrorType.server:
        return _serverDescription;
      case ApiErrorType.auth:
        return 'Votre session a expiré. Veuillez vous reconnecter pour continuer.';
      case ApiErrorType.unknown:
        return _fallbackDescription;
    }
  }

  String get _serverDescription {
    switch (_statusCode) {
      case 503: return 'Nos serveurs sont en maintenance. Réessayez dans quelques instants.';
      case 502: return 'Le serveur intermédiaire est inaccessible. Réessayez.';
      case 504: return 'Le serveur a mis trop de temps à répondre. Réessayez.';
      case 404: return 'La ressource demandée n\'existe pas ou a été supprimée.';
      case 500: return 'Une erreur interne est survenue. Notre équipe a été notifiée.';
      default:
        final msg = _apiError?.message ?? '';
        return msg.length > 200 ? 'Erreur inattendue du serveur.' : msg;
    }
  }

  String get _fallbackDescription {
    final msg = _apiError?.message ?? error.toString();
    return msg.length > 200 ? 'Une erreur inattendue est survenue.' : msg;
  }

  // ── icon ──

  IconData get _icon {
    switch (_errorType) {
      case ApiErrorType.network: return Icons.cloud_off_rounded;
      case ApiErrorType.parse: return Icons.data_object_rounded;
      case ApiErrorType.server:
        switch (_statusCode) {
          case 503: case 502: case 504: return Icons.cloud_off_rounded;
          case 404: return Icons.search_off_rounded;
          case 500: return Icons.bug_report_outlined;
          default: return Icons.error_outline_rounded;
        }
      case ApiErrorType.auth: return Icons.lock_outline_rounded;
      case ApiErrorType.unknown: return Icons.error_outline_rounded;
    }
  }

  // ── build ──

  @override
  Widget build(BuildContext context) {
    if (compact) return _buildCompact(context);
    return _buildFull(context);
  }

  Widget _buildCompact(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_icon, size: 32, color: AppColors.textMuted),
            const SizedBox(height: AppSpacing.sm),
            Text(_friendlyTitle,
              style: AppTypography.body.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: AppSpacing.md),
              TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Réessayer'),
                style: TextButton.styleFrom(foregroundColor: AppColors.primary),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFull(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(_icon, size: 40, color: AppColors.error),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(_friendlyTitle,
              style: AppTypography.sectionHeader.copyWith(color: AppColors.textPrimary),
              textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.sm),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(_friendlyDescription,
                style: AppTypography.body.copyWith(color: AppColors.textSecondary, height: 1.45),
                textAlign: TextAlign.center),
            ),
            // Debug info — endpoint + status code
            if (showDiagnostic && _endpoint != null) ...[
              const SizedBox(height: AppSpacing.md),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _debugRow('Endpoint', _endpoint!),
                    if (_statusCode != null) _debugRow('HTTP', '$_statusCode'),
                    if (_apiError?.code != null) _debugRow('Code', _apiError!.code!),
                    const SizedBox(height: AppSpacing.sm),
                    Text(error.toString(),
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textMuted,
                        fontFamily: 'monospace',
                      )),
                  ],
                ),
              ),
            ],
            if (onRetry != null) ...[
              const SizedBox(height: AppSpacing.xl),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 20),
                label: const Text('Réessayer'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xl,
                    vertical: AppSpacing.md,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusControl),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _debugRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label: ',
            style: AppTypography.caption.copyWith(
              color: AppColors.textMuted,
              fontWeight: FontWeight.w600,
            )),
          Flexible(
            child: Text(value,
              style: AppTypography.caption.copyWith(
                color: AppColors.textMuted,
                fontFamily: 'monospace',
              )),
          ),
        ],
      ),
    );
  }
}
