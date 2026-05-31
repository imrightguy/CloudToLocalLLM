import 'dart:io';

import 'package:cloudtolocalllm/services/gateway_command_resolver.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('gateway_command_resolver', () {
    test('accepts a trusted absolute configured command path', () {
      final command = p.normalize('/usr/local/bin/hermes-agent');

      final resolved = validateTrustedGatewayCommand(
        commandName: 'hermes-agent',
        allowedExecutableNames: const {'hermes-agent', 'hermes-agent.exe'},
        configuredCommand: command,
      );

      expect(resolved, command);
    });

    test('rejects a relative configured command path', () {
      expect(
        () => validateTrustedGatewayCommand(
          commandName: 'hermes-agent',
          allowedExecutableNames: const {'hermes-agent', 'hermes-agent.exe'},
          configuredCommand: 'hermes-agent',
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('rejects executable names outside the trusted allowlist', () {
      final command = p.normalize('/usr/local/bin/not-hermes');

      expect(
        () => validateTrustedGatewayCommand(
          commandName: 'hermes-agent',
          allowedExecutableNames: const {'hermes-agent', 'hermes-agent.exe'},
          configuredCommand: command,
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('prefers the first existing trusted default command path', () async {
      final commandDir = await Directory.systemTemp.createTemp(
        'hermes-command-resolver-test-',
      );
      addTearDown(() async {
        if (commandDir.existsSync()) {
          await commandDir.delete(recursive: true);
        }
      });

      final trustedCommand =
          File('${commandDir.path}${Platform.pathSeparator}hermes-agent')
            ..createSync();

      final resolved = resolveRequiredTrustedGatewayCommand(
        commandName: 'hermes-agent',
        commandEnvVar: 'CLOUDTOLOCALLLM_HERMES_AGENT_COMMAND_PATH',
        allowedExecutableNames: const {'hermes-agent', 'hermes-agent.exe'},
        configuredCommandPath: '/usr/local/bin/hermes-agent',
        trustedDefaultCommandPaths: <String>[
          trustedCommand.path,
          '/opt/hermes-agent/bin/hermes-agent',
        ],
      );

      expect(resolved, trustedCommand.path);
    });

    test('throws when no trusted command path can be resolved', () {
      expect(
        () => resolveRequiredTrustedGatewayCommand(
          commandName: 'hermes-agent',
          commandEnvVar: 'CLOUDTOLOCALLLM_HERMES_AGENT_COMMAND_PATH',
          allowedExecutableNames: const {'hermes-agent', 'hermes-agent.exe'},
          configuredCommandPath: null,
          trustedDefaultCommandPaths: const <String>[],
        ),
        throwsA(isA<StateError>()),
      );
    });
  });
}
