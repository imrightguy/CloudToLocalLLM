import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Elegant error state with user-friendly message and retry action.
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

  int? get _statusCode {
    if (error is ApiException) return (error as ApiException).statusCode;
    return null;
  }

  String get _friendlyTitle {
    if (title != null) return title!;
    switch (_statusCode) {
      case 503: return 'Service temporairement indisponible';
      case 502: return 'Passerelle inaccessible';
      case 504: return 'Délai dépassé';
      case 401:
      case 403: return 'Accès refusé';
      case 404: return 'Ressource introuvable';
      case 500: return 'Erreur serveur';
      case null: return 'Erreur de connexion';
      default: return 'Une erreur est survenue';
    }
  }

  String get _friendlyDescription {
    switch (_statusCode) {
      case 503: return 'Nos serveurs sont en maintenance. Réessayez dans quelques instants.';
      case 502: return 'Impossible de joindre le serveur. Vérifiez votre connexion.';
      case 504: return 'Le serveur a mis trop de temps à répondre. Réessayez.';
      case 401: return 'Votre session a expiré. Veuillez vous reconnecter.';
      case 403: return 'Vous n\'avez pas les droits pour accéder à cette ressource.';
      case 404: return 'La ressource demandée n\'existe pas ou a été supprimée.';
      case 500: return 'Une erreur interne est survenue. Notre équipe a été notifiée.';
      case null: return 'Vérifiez votre connexion internet et réessayez.';
      default:
        final msg = error is ApiException ? (error as ApiException).message : error.toString();
        return msg.length > 200 ? 'Erreur inattendue du serveur.' : msg;
    }
  }

  IconData get _icon {
    switch (_statusCode) {
      case 503: case 502: case 504: return Icons.cloud_off_rounded;
      case 401: case 403: return Icons.lock_outline_rounded;
      case 404: return Icons.search_off_rounded;
      case 500: return Icons.bug_report_outlined;
      case null: return Icons.wifi_off_rounded;
      default: return Icons.error_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (compact) {
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
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(width: 80, height: 80, decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(20)),
              child: Icon(_icon, size: 40, color: AppColors.error)),
            const SizedBox(height: AppSpacing.xl),
            Text(_friendlyTitle, style: AppTypography.sectionHeader.copyWith(color: AppColors.textPrimary), textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.sm),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(_friendlyDescription, style: AppTypography.body.copyWith(color: AppColors.textSecondary, height: 1.45), textAlign: TextAlign.center)),
            if (showDiagnostic) ...[
              const SizedBox(height: AppSpacing.md),
              Container(margin: const EdgeInsets.symmetric(horizontal: 24), padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(color: AppColors.surfaceVariant, borderRadius: BorderRadius.circular(AppSpacing.radiusSm)),
                child: Text(error.toString(), style: AppTypography.caption.copyWith(color: AppColors.textMuted, fontFamily: 'monospace'))),
            ],
            if (onRetry != null) ...[
              const SizedBox(height: AppSpacing.xl),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 20),
                label: const Text('Réessayer'),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.md),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusControl))),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
