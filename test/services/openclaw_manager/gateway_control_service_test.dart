import 'dart:async';
import 'dart:io';

import 'package:cloudtolocalllm/services/openclaw_manager/gateway_control_service.dart';
import 'package:cloudtolocalllm/services/settings_preference_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _OpenClawCommandCall {
  _OpenClawCommandCall({
    required this.executable,
    required this.arguments,
    required this.runInShell,
  });

  final String executable;
  final List<String> arguments;
  final bool runInShell;
}

class _GatewayServiceBundle {
  _GatewayServiceBundle({
    required this.service,
    required this.calls,
  });

  final GatewayControlService service;
  final List<_OpenClawCommandCall> calls;
}

_GatewayServiceBundle _createService({
  required Future<ProcessResult> Function(
    String executable,
    List<String> arguments, {
    bool runInShell,
  }) processRunner,
  String? openclawCommandPath,
  List<String>? trustedDefaultCommandPaths,
  Duration? commandTimeout,
  Duration? readinessTimeout,
  Duration? stopTimeout,
}) {
  final calls = <_OpenClawCommandCall>[];
  final service = Function.apply(
    GatewayControlService.new,
    <dynamic>[
      SettingsPreferenceService(),
      null,
      (String executable, List<String> arguments, {bool runInShell = false}) {
        calls.add(
          _OpenClawCommandCall(
            executable: executable,
            arguments: List<String>.from(arguments),
            runInShell: runInShell,
          ),
        );
        return processRunner(
          executable,
          arguments,
          runInShell: runInShell,
        );
      },
      openclawCommandPath,
      trustedDefaultCommandPaths,
      commandTimeout,
      readinessTimeout,
      stopTimeout,
    ],
    const <Symbol, dynamic>{},
  ) as GatewayControlService;

  return _GatewayServiceBundle(service: service, calls: calls);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('GatewayControlService', () {
    test('constructs without command path before gateway actions are invoked',
        () async {
      late GatewayControlService service;

      expect(
        () {
          service = GatewayControlService(
            SettingsPreferenceService(),
            null,
            (executable, arguments, {runInShell = false}) async {
              return ProcessResult(0, 0, '', '');
            },
          );
        },
        returnsNormally,
      );

      await Future<void>.delayed(Duration.zero);
      service.dispose();
    });

    test('invokes trusted command path with expected args and no shell',
        () async {
      int statusProbeCount = 0;
      final bundle = _createService(
        processRunner: (executable, arguments, {runInShell = false}) async {
          if (arguments.contains('status')) {
            statusProbeCount += 1;
            final output = statusProbeCount == 1 ? '{"status":"running"}' : '{"status":"stopped"}';
            return ProcessResult(0, 0, output, '');
          }
          return ProcessResult(0, 0, '{"started":true}', '');
        },
        openclawCommandPath: '/usr/local/bin/openclaw',
      );
      addTearDown(bundle.service.dispose);

      await bundle.service.start();
      await bundle.service.stop();
      await bundle.service.checkStatus();

      expect(bundle.calls, hasLength(5));
      expect(bundle.calls[0].executable, '/usr/local/bin/openclaw');
      expect(bundle.calls[0].arguments, ['gateway', 'start', '--json']);
      expect(bundle.calls[1].executable, '/usr/local/bin/openclaw');
      expect(bundle.calls[1].arguments, ['gateway', 'status', '--json']);
      expect(bundle.calls[2].executable, '/usr/local/bin/openclaw');
      expect(bundle.calls[2].arguments, ['gateway', 'stop', '--json']);
      expect(bundle.calls[3].executable, '/usr/local/bin/openclaw');
      expect(bundle.calls[3].arguments, ['gateway', 'status', '--json']);
      expect(bundle.calls[4].executable, '/usr/local/bin/openclaw');
      expect(bundle.calls[4].arguments, ['gateway', 'status', '--json']);
      expect(bundle.calls.every((call) => call.runInShell == false), isTrue);
    });

    test(
        'uses trusted default command path when no override is configured',
        () async {
      final commandDir =
          await Directory.systemTemp.createTemp('openclaw-command-test-');
      addTearDown(() async {
        if (commandDir.existsSync()) {
          await commandDir.delete(recursive: true);
        }
      });
      final command =
          File('${commandDir.path}${Platform.pathSeparator}openclaw')
            ..createSync();
      final bundle = _createService(
        processRunner: (executable, arguments, {runInShell = false}) async {
          final output = arguments.contains('status')
              ? '{"status":"running"}'
              : '{"started":true}';
          return ProcessResult(0, 0, output, '');
        },
        trustedDefaultCommandPaths: [command.path],
      );
      addTearDown(bundle.service.dispose);

      final started = await bundle.service.start();

      expect(started, isTrue);
      expect(bundle.calls, hasLength(2));
      expect(bundle.calls[0].executable, command.path);
      expect(bundle.calls[0].arguments, ['gateway', 'start', '--json']);
      expect(bundle.calls[1].executable, command.path);
      expect(bundle.calls[1].arguments, ['gateway', 'status', '--json']);
      expect(bundle.calls.every((call) => call.runInShell == false), isTrue);
    });

    test('starts only after a readiness probe confirms running', () async {
      final bundle = _createService(
        processRunner: (executable, arguments, {runInShell = false}) async {
          final output = arguments.contains('status')
              ? '{"status":"running"}'
              : '{"started":true}';
          return ProcessResult(0, 0, output, '');
        },
        openclawCommandPath: '/usr/local/bin/openclaw',
      );
      addTearDown(bundle.service.dispose);

      final started = await bundle.service.start();

      expect(started, isTrue);
      expect(bundle.service.isRunning, isTrue);
      expect(bundle.service.state, GatewayState.running);
      expect(bundle.service.startedAt, isNotNull);
      expect(bundle.calls, hasLength(2));
      expect(bundle.calls[0].arguments, ['gateway', 'start', '--json']);
      expect(bundle.calls[1].arguments, ['gateway', 'status', '--json']);
    });

    test('fails startup when the readiness probe never reports running',
        () async {
      final bundle = _createService(
        processRunner: (executable, arguments, {runInShell = false}) async {
          final output = arguments.contains('status')
              ? '{"status":"stopped"}'
              : '{"started":true}';
          return ProcessResult(0, 0, output, '');
        },
        openclawCommandPath: '/usr/local/bin/openclaw',
      );
      addTearDown(bundle.service.dispose);

      final started = await bundle.service.start();

      expect(started, isFalse);
      expect(bundle.service.isRunning, isFalse);
      expect(bundle.service.state, GatewayState.error);
      expect(bundle.service.errorMessage, contains('readiness'));
      expect(bundle.calls, hasLength(4));
      expect(bundle.calls[0].arguments, ['gateway', 'start', '--json']);
      expect(bundle.calls[1].arguments, ['gateway', 'status', '--json']);
      expect(bundle.calls[2].arguments, ['gateway', 'stop', '--json']);
      expect(bundle.calls[3].arguments, ['gateway', 'status', '--json']);
    });

    test('times out a hung start command before the gateway becomes running',
        () async {
      final hungCommand = Completer<ProcessResult>().future;
      final bundle = _createService(
        processRunner: (executable, arguments, {runInShell = false}) {
          return hungCommand;
        },
        openclawCommandPath: '/usr/local/bin/openclaw',
        commandTimeout: const Duration(milliseconds: 20),
        readinessTimeout: const Duration(milliseconds: 20),
      );
      addTearDown(bundle.service.dispose);

      final started = await bundle.service.start();

      expect(started, isFalse);
      expect(bundle.service.state, GatewayState.error);
      expect(bundle.service.errorMessage, contains('timed out'));
      expect(bundle.calls, hasLength(1));
      expect(bundle.calls.single.arguments, ['gateway', 'start', '--json']);
    });

    test('times out stop and performs a follow-up cleanup probe', () async {
      int statusProbeCount = 0;
      final stopCommand = Completer<ProcessResult>().future;
      final bundle = _createService(
        processRunner: (executable, arguments, {runInShell = false}) async {
          if (arguments.contains('status')) {
            statusProbeCount += 1;
            final output = statusProbeCount == 1
                ? '{"status":"running"}'
                : '{"status":"stopped"}';
            return ProcessResult(0, 0, output, '');
          }
          if (arguments.contains('stop')) {
            return stopCommand;
          }
          return ProcessResult(0, 0, '{"started":true}', '');
        },
        openclawCommandPath: '/usr/local/bin/openclaw',
        stopTimeout: const Duration(milliseconds: 20),
        readinessTimeout: const Duration(milliseconds: 20),
      );
      addTearDown(bundle.service.dispose);

      expect(await bundle.service.start(), isTrue);
      final stopped = await bundle.service.stop();

      expect(stopped, isFalse);
      expect(bundle.service.state, GatewayState.error);
      expect(bundle.service.errorMessage, contains('timed out'));
      expect(bundle.calls, hasLength(4));
      expect(bundle.calls[0].arguments, ['gateway', 'start', '--json']);
      expect(bundle.calls[1].arguments, ['gateway', 'status', '--json']);
      expect(bundle.calls[2].arguments, ['gateway', 'stop', '--json']);
      expect(bundle.calls[3].arguments, ['gateway', 'status', '--json']);
    });

    test('rejects a relative command path to avoid PATH lookup', () {
      expect(
        () => GatewayControlService(
          SettingsPreferenceService(),
          null,
          (executable, arguments, {runInShell = false}) async {
            return ProcessResult(0, 0, '', '');
          },
          'openclaw',
        ),
        throwsA(isA<StateError>()),
      );
    });
  });
}
