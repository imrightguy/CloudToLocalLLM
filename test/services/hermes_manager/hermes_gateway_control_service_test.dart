import 'dart:io';

import 'package:cloudtolocalllm/services/hermes_manager/hermes_gateway_control_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _HermesCommandCall {
  _HermesCommandCall({
    required this.executable,
    required this.arguments,
    required this.runInShell,
  });

  final String executable;
  final List<String> arguments;
  final bool runInShell;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HermesGatewayControlService', () {
    test('constructs without command path before gateway actions are invoked',
        () {
      expect(
        () => HermesGatewayControlService(
          null,
          (executable, arguments, {runInShell = false}) async {
            return HermesGatewayProcessHandle(
              pid: 1234,
              exitCode: Future<int>.value(0),
              stdout: const Stream<List<int>>.empty(),
              stderr: const Stream<List<int>>.empty(),
              kill: ([ProcessSignal signal = ProcessSignal.sigterm]) => true,
            );
          },
        ),
        returnsNormally,
      );
    });

    test('starts with trusted command path using explicit args and no shell',
        () async {
      final calls = <_HermesCommandCall>[];
      bool? killedSigint;

      final service = HermesGatewayControlService(
        null,
        (executable, arguments, {runInShell = false}) async {
          calls.add(
            _HermesCommandCall(
              executable: executable,
              arguments: List<String>.from(arguments),
              runInShell: runInShell,
            ),
          );

          return HermesGatewayProcessHandle(
            pid: 1234,
            exitCode: Future<int>.value(0),
            stdout: const Stream<List<int>>.empty(),
            stderr: const Stream<List<int>>.empty(),
            kill: ([ProcessSignal signal = ProcessSignal.sigterm]) {
              if (signal == ProcessSignal.sigint) {
                killedSigint = true;
              }
              return true;
            },
          );
        },
        '/usr/local/bin/hermes-agent',
      );

      final started = await service.start();
      expect(started, isTrue);
      expect(service.isRunning, isTrue);
      final runningStatus = service.getStatus();
      expect(runningStatus['running'], isTrue);
      expect(runningStatus['pid'], 1234);

      final stopped = await service.stop();
      expect(stopped, isTrue);
      expect(service.isRunning, isFalse);
      final stoppedStatus = service.getStatus();
      expect(stoppedStatus['running'], isFalse);
      expect(stoppedStatus['pid'], isNull);
      expect(calls, hasLength(1));
      expect(calls[0].executable, '/usr/local/bin/hermes-agent');
      expect(calls[0].arguments, ['gateway', 'start', '--json']);
      expect(calls[0].runInShell, isFalse);
      expect(killedSigint, isTrue);
    });

    test('returns false when the start command exits with a failure code',
        () async {
      final calls = <_HermesCommandCall>[];
      final service = HermesGatewayControlService(
        null,
        (executable, arguments, {runInShell = false}) async {
          calls.add(
            _HermesCommandCall(
              executable: executable,
              arguments: List<String>.from(arguments),
              runInShell: runInShell,
            ),
          );

          return HermesGatewayProcessHandle(
            pid: 1234,
            exitCode: Future<int>.value(1),
            stdout: const Stream<List<int>>.empty(),
            stderr: const Stream<List<int>>.empty(),
            kill: ([ProcessSignal signal = ProcessSignal.sigterm]) => true,
          );
        },
        '/usr/local/bin/hermes-agent',
      );

      final started = await service.start();

      expect(started, isFalse);
      expect(service.isRunning, isFalse);
      final status = service.getStatus();
      expect(status['running'], isFalse);
      expect(status['pid'], isNull);
      expect(calls, hasLength(1));
      expect(calls.single.executable, '/usr/local/bin/hermes-agent');
      expect(calls.single.arguments, ['gateway', 'start', '--json']);
      expect(calls.single.runInShell, isFalse);
    });

    test('returns false when no trusted command path can be resolved', () async {
      final calls = <_HermesCommandCall>[];
      final service = HermesGatewayControlService(
        null,
        (executable, arguments, {runInShell = false}) async {
          calls.add(
            _HermesCommandCall(
              executable: executable,
              arguments: List<String>.from(arguments),
              runInShell: runInShell,
            ),
          );

          return HermesGatewayProcessHandle(
            pid: 1234,
            exitCode: Future<int>.value(0),
            stdout: const Stream<List<int>>.empty(),
            stderr: const Stream<List<int>>.empty(),
            kill: ([ProcessSignal signal = ProcessSignal.sigterm]) => true,
          );
        },
        null,
        const <String>[],
      );

      final started = await service.start();

      expect(started, isFalse);
      expect(service.isRunning, isFalse);
      final status = service.getStatus();
      expect(status['running'], isFalse);
      expect(status['pid'], isNull);
      expect(calls, isEmpty);
    });

    test('uses trusted default command path when no override is configured',
        () async {
      final commandDir =
          await Directory.systemTemp.createTemp('hermes-command-test-');
      addTearDown(() async {
        if (commandDir.existsSync()) {
          await commandDir.delete(recursive: true);
        }
      });
      final command =
          File('${commandDir.path}${Platform.pathSeparator}hermes-agent')
            ..createSync();
      final calls = <_HermesCommandCall>[];

      final service = HermesGatewayControlService(
        null,
        (executable, arguments, {runInShell = false}) async {
          calls.add(
            _HermesCommandCall(
              executable: executable,
              arguments: List<String>.from(arguments),
              runInShell: runInShell,
            ),
          );

          return HermesGatewayProcessHandle(
            pid: 1234,
            exitCode: Future<int>.value(0),
            stdout: const Stream<List<int>>.empty(),
            stderr: const Stream<List<int>>.empty(),
            kill: ([ProcessSignal signal = ProcessSignal.sigterm]) => true,
          );
        },
        null,
        [command.path],
      );

      final started = await service.start();

      expect(started, isTrue);
      final status = service.getStatus();
      expect(status['running'], isTrue);
      expect(status['pid'], 1234);
      expect(calls, hasLength(1));
      expect(calls.single.executable, command.path);
      expect(calls.single.arguments, ['gateway', 'start', '--json']);
      expect(calls.single.runInShell, isFalse);
    });

    test('rejects a relative command path to avoid PATH lookup', () {
      expect(
        () => HermesGatewayControlService(
          null,
          (executable, arguments, {runInShell = false}) async {
            return HermesGatewayProcessHandle(
              pid: 1234,
              exitCode: Future<int>.value(0),
              stdout: const Stream<List<int>>.empty(),
              stderr: const Stream<List<int>>.empty(),
              kill: ([ProcessSignal signal = ProcessSignal.sigterm]) => true,
            );
          },
          'hermes-agent',
        ),
        throwsA(isA<StateError>()),
      );
    });
  });
}
