import 'dart:io';

import 'package:path/path.dart' as p;

String? configuredTrustedGatewayCommand({
  required String commandName,
  required String commandEnvVar,
  required Set<String> allowedExecutableNames,
  String? providedCommand,
}) {
  final configuredCommand = (providedCommand?.trim().isNotEmpty == true)
      ? providedCommand!.trim()
      : Platform.environment[commandEnvVar]?.trim();

  if (configuredCommand == null || configuredCommand.isEmpty) {
    return null;
  }

  return validateTrustedGatewayCommand(
    commandName: commandName,
    allowedExecutableNames: allowedExecutableNames,
    configuredCommand: configuredCommand,
  );
}

String resolveRequiredTrustedGatewayCommand({
  required String commandName,
  required String commandEnvVar,
  required Set<String> allowedExecutableNames,
  required String? configuredCommandPath,
  required List<String> trustedDefaultCommandPaths,
}) {
  final defaultCommandPath = resolveTrustedDefaultGatewayCommand(
    commandName: commandName,
    allowedExecutableNames: allowedExecutableNames,
    trustedDefaultCommandPaths: trustedDefaultCommandPaths,
  );
  final commandPath = defaultCommandPath ?? configuredCommandPath;

  if (commandPath != null) {
    return commandPath;
  }

  final defaultPathHint = trustedDefaultCommandPaths.isEmpty
      ? 'no default paths are available for this platform'
      : trustedDefaultCommandPaths.join(', ');
  throw StateError(
    'Trusted command path for "$commandName" was not found. Install it under '
    'one of: $defaultPathHint, or set "$commandEnvVar" to a trusted absolute '
    'path.',
  );
}

String? resolveTrustedDefaultGatewayCommand({
  required String commandName,
  required Set<String> allowedExecutableNames,
  required List<String> trustedDefaultCommandPaths,
}) {
  for (final candidate in trustedDefaultCommandPaths) {
    final normalizedCandidate = p.normalize(candidate.trim());
    if (normalizedCandidate.isEmpty ||
        !p.isAbsolute(normalizedCandidate) ||
        !allowedExecutableNames.contains(p.basename(normalizedCandidate)) ||
        !File(normalizedCandidate).existsSync()) {
      continue;
    }

    return validateTrustedGatewayCommand(
      commandName: commandName,
      allowedExecutableNames: allowedExecutableNames,
      configuredCommand: normalizedCandidate,
    );
  }

  return null;
}

String validateTrustedGatewayCommand({
  required String commandName,
  required Set<String> allowedExecutableNames,
  required String configuredCommand,
}) {
  final normalizedCommand = p.normalize(configuredCommand);

  if (!p.isAbsolute(normalizedCommand)) {
    throw StateError(
      'Configured command for "$commandName" must be an absolute path: '
      '$normalizedCommand',
    );
  }

  final basename = p.basename(normalizedCommand);
  if (!allowedExecutableNames.contains(basename)) {
    throw StateError(
      'Invalid executable for "$commandName". Expected one of '
      '${allowedExecutableNames.join(', ')}, got "$basename".',
    );
  }

  return normalizedCommand;
}
