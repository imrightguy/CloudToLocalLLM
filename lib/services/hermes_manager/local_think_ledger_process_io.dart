import 'dart:io';

Future<String> readLocalThinkLedgerFromProcess() async {
  final result = await Process.run(
    'hermes-local-think-ledger',
    <String>['list', '--json'],
  );
  if (result.exitCode != 0) {
    throw ProcessException(
      'hermes-local-think-ledger',
      const <String>['list', '--json'],
      result.stderr.toString(),
      result.exitCode,
    );
  }
  return result.stdout.toString();
}

Future<String> readLocalThinkLedgerDetailFromProcess(
  String taskIdPrefix,
) async {
  final result = await Process.run(
    'hermes-local-think-ledger',
    <String>['show', taskIdPrefix, '--json'],
  );
  if (result.exitCode != 0) {
    throw ProcessException(
      'hermes-local-think-ledger',
      <String>['show', taskIdPrefix, '--json'],
      result.stderr.toString(),
      result.exitCode,
    );
  }
  return result.stdout.toString();
}
