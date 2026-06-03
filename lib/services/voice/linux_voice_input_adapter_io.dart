import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:record/record.dart';

import 'voice_input_contract.dart';

VoiceInputAdapter? createLinuxVoiceInputAdapter({
  required bool isLinux,
  String? command,
  List<String>? arguments,
  String? scriptPath,
  VoiceAudioSource? audioSource,
  VoiceTranscriptTranscriber? transcriber,
  String? recorderCommandPath,
  String? transcribeCommandPath,
  Duration captureWindow = const Duration(seconds: 2),
  Duration commandTimeout = const Duration(seconds: 10),
  Directory? outputDirectory,
  List<String>? trustedRecorderPaths,
  List<String>? trustedTranscribePaths,
}) {
  if (!isLinux) {
    return null;
  }

  return LinuxVoiceInputAdapter(
    audioSource: audioSource,
    transcriber: transcriber,
    command: command,
    arguments: arguments,
    scriptPath: scriptPath,
    recorderCommandPath: recorderCommandPath,
    transcribeCommandPath: transcribeCommandPath,
    captureWindow: captureWindow,
    commandTimeout: commandTimeout,
    outputDirectory: outputDirectory,
    trustedRecorderPaths: trustedRecorderPaths,
    trustedTranscribePaths: trustedTranscribePaths,
    isLinux: isLinux,
  );
}

bool _shouldUseCommandPipeline({
  String? recorderCommandPath,
  String? transcribeCommandPath,
  List<String>? trustedRecorderPaths,
  List<String>? trustedTranscribePaths,
}) {
  return recorderCommandPath != null ||
      transcribeCommandPath != null ||
      trustedRecorderPaths != null ||
      trustedTranscribePaths != null;
}

abstract class VoiceAudioSource {
  Future<bool> hasPermission({bool request = true});
  Future<Stream<List<int>>> start();
  Future<void> stop();
  Future<void> dispose();
}

class RecordVoiceAudioSource implements VoiceAudioSource {
  RecordVoiceAudioSource({AudioRecorder? recorder})
      : _recorder = recorder ?? AudioRecorder();

  final AudioRecorder _recorder;

  @override
  Future<bool> hasPermission({bool request = true}) {
    return _recorder.hasPermission(request: request);
  }

  @override
  Future<Stream<List<int>>> start() async {
    final stream = await _recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000,
        numChannels: 1,
      ),
    );
    return stream;
  }

  @override
  Future<void> stop() async {
    await _recorder.stop();
  }

  @override
  Future<void> dispose() async {
    await _recorder.dispose();
  }
}

typedef ProcessRunner = Future<ProcessResult> Function(
  String executable,
  List<String> arguments, {
  Map<String, String>? environment,
});

abstract class VoiceTranscriptTranscriber {
  Future<String?> transcribe(File audioFile);
}

class CommandVoiceTranscriptTranscriber implements VoiceTranscriptTranscriber {
  CommandVoiceTranscriptTranscriber({
    required this.command,
    required this.arguments,
    this.environment,
    ProcessRunner? processRunner,
  }) : _processRunner = processRunner ?? Process.run;

  factory CommandVoiceTranscriptTranscriber.fromEnvironment({
    String? command,
    List<String>? arguments,
    String? scriptPath,
    ProcessRunner? processRunner,
  }) {
    final resolvedCommand =
        command ?? Platform.environment['CLOUDTOLOCALLLM_VOICE_TRANSCRIBE_COMMAND'] ?? 'bash';
    final resolvedScriptPath = scriptPath ??
        Platform.environment['CLOUDTOLOCALLLM_VOICE_TRANSCRIBE_SCRIPT'] ??
        'scripts/voice_transcribe.sh';
    final resolvedArguments = arguments ?? [resolvedScriptPath];
    return CommandVoiceTranscriptTranscriber(
      command: resolvedCommand,
      arguments: resolvedArguments,
      processRunner: processRunner,
    );
  }

  final String command;
  final List<String> arguments;
  final Map<String, String>? environment;
  final ProcessRunner _processRunner;

  @override
  Future<String?> transcribe(File audioFile) async {
    final result = await _processRunner(
      command,
      [...arguments, audioFile.path],
      environment: environment,
    );

    final stdoutText = result.stdout.toString().trim();
    final stderrText = result.stderr.toString().trim();
    if (result.exitCode != 0) {
      throw ProcessException(
        command,
        [...arguments, audioFile.path],
        stderrText.isEmpty ? stdoutText : stderrText,
      );
    }

    if (stdoutText.isEmpty) {
      return null;
    }
    return stdoutText;
  }
}

class LinuxVoiceInputAdapter implements VoiceInputAdapter {
  LinuxVoiceInputAdapter({
    VoiceAudioSource? audioSource,
    VoiceTranscriptTranscriber? transcriber,
    ProcessRunner? processRunner,
    String? command,
    List<String>? arguments,
    String? scriptPath,
    String? recorderCommandPath,
    String? transcribeCommandPath,
    Duration captureWindow = const Duration(seconds: 2),
    Duration commandTimeout = const Duration(seconds: 10),
    Directory? outputDirectory,
    List<String>? trustedRecorderPaths,
    List<String>? trustedTranscribePaths,
    bool isLinux = true,
  })  : _isLinux = isLinux,
        _useCommandPipeline = _shouldUseCommandPipeline(
          recorderCommandPath: recorderCommandPath,
          transcribeCommandPath: transcribeCommandPath,
          trustedRecorderPaths: trustedRecorderPaths,
          trustedTranscribePaths: trustedTranscribePaths,
        ),
        _processRunner = processRunner ?? Process.run,
        _audioSource = _shouldUseCommandPipeline(
          recorderCommandPath: recorderCommandPath,
          transcribeCommandPath: transcribeCommandPath,
          trustedRecorderPaths: trustedRecorderPaths,
          trustedTranscribePaths: trustedTranscribePaths,
        )
            ? audioSource
            : (audioSource ?? RecordVoiceAudioSource()),
        _transcriber = transcriber ??
            CommandVoiceTranscriptTranscriber.fromEnvironment(
              command: command,
              arguments: arguments,
              scriptPath: scriptPath,
              processRunner: processRunner,
            ),
        _recorderCommandPath = recorderCommandPath,
        _transcribeCommandPath = transcribeCommandPath,
        _captureWindow = captureWindow,
        _commandTimeout = commandTimeout,
        _outputDirectory = outputDirectory,
        _trustedRecorderPaths = trustedRecorderPaths,
        _trustedTranscribePaths = trustedTranscribePaths;

  final bool _isLinux;
  final bool _useCommandPipeline;
  final ProcessRunner _processRunner;
  final VoiceAudioSource? _audioSource;
  final VoiceTranscriptTranscriber _transcriber;
  final String? _recorderCommandPath;
  final String? _transcribeCommandPath;
  final Duration _captureWindow;
  final Duration _commandTimeout;
  final Directory? _outputDirectory;
  final List<String>? _trustedRecorderPaths;
  final List<String>? _trustedTranscribePaths;

  final StreamController<VoiceInputTranscriptEvent> _transcriptsController =
      StreamController<VoiceInputTranscriptEvent>.broadcast();
  final BytesBuilder _buffer = BytesBuilder(copy: false);

  StreamSubscription<List<int>>? _audioSubscription;
  Timer? _flushTimer;
  Future<void> _pendingFlush = Future<void>.value();
  Future<void> _commandLoop = Future<void>.value();
  bool _isRunning = false;
  bool _disposed = false;
  bool _audioStarted = false;

  @override
  Stream<VoiceInputTranscriptEvent> get transcripts =>
      _transcriptsController.stream;

  @override
  bool get isSupported {
    if (_disposed || !_isLinux) {
      return false;
    }

    if (!_useCommandPipeline) {
      return true;
    }

    final recorderPath = _recorderCommandPath;
    final transcribePath = _transcribeCommandPath;
    if (recorderPath == null || transcribePath == null) {
      return false;
    }

    return File(recorderPath).existsSync() &&
        File(transcribePath).existsSync() &&
        _isTrusted(recorderPath, _trustedRecorderPaths) &&
        _isTrusted(transcribePath, _trustedTranscribePaths);
  }

  @override
  bool get isRunning => _isRunning;

  @override
  Future<void> start() async {
    if (_disposed || _isRunning || !isSupported) {
      return;
    }

    _isRunning = true;
    if (_useCommandPipeline) {
      _commandLoop = _runCommandCaptureLoop();
      return;
    }

    final audioSource = _audioSource;
    if (audioSource == null) {
      _isRunning = false;
      throw StateError('A microphone audio source is required for streaming Linux voice input.');
    }

    final hasPermission = await audioSource.hasPermission(request: true);
    if (!hasPermission) {
      _isRunning = false;
      throw StateError('Microphone permission is required for Linux voice input.');
    }

    final stream = await audioSource.start();
    _audioStarted = true;
    _audioSubscription = stream.listen(
      _handleAudioChunk,
      onError: _transcriptsController.addError,
    );
    _flushTimer = Timer.periodic(_captureWindow, (_) {
      unawaited(_flushBuffer());
    });
  }

  @override
  Future<void> stop() async {
    if (_disposed) {
      return;
    }

    _isRunning = false;
    _flushTimer?.cancel();
    _flushTimer = null;
    await _audioSubscription?.cancel();
    _audioSubscription = null;
    await _flushBuffer();
    await _pendingFlush;
    await _commandLoop;
    if (_audioStarted) {
      await _audioSource?.stop();
      _audioStarted = false;
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    await stop();
    await _audioSource?.dispose();
    await _transcriptsController.close();
  }

  void _handleAudioChunk(List<int> chunk) {
    if (_disposed || !_isRunning || chunk.isEmpty) {
      return;
    }

    _buffer.add(chunk);
    if (_buffer.length > _minimumChunkBytes) {
      unawaited(_flushBuffer());
    }
  }

  int get _minimumChunkBytes => 16000 * 2 * 1 * _captureWindow.inSeconds;

  Future<void> _flushBuffer() async {
    if (_disposed) {
      return;
    }

    if (_buffer.isEmpty) {
      return;
    }

    final pcmBytes = _buffer.takeBytes();
    if (pcmBytes.isEmpty) {
      return;
    }

    _pendingFlush = _pendingFlush.then((_) => _transcribeChunk(pcmBytes));
    await _pendingFlush;
  }

  Future<void> _transcribeChunk(List<int> pcmBytes) async {
    final wavFile = await _writeTempWavFile(Uint8List.fromList(pcmBytes));
    try {
      final transcript = await _transcriber.transcribe(wavFile);
      final cleaned = transcript == null
          ? ''
          : transcript.replaceAll(RegExp(r'\s+'), ' ').trim();
      if (cleaned.isEmpty) {
        return;
      }
      _transcriptsController.add(
        VoiceInputTranscriptEvent(
          text: cleaned,
          isFinal: true,
          source: VoiceInputSource.native,
        ),
      );
    } finally {
      if (await wavFile.exists()) {
        await wavFile.delete();
      }
    }
  }

  Future<void> _runCommandCaptureLoop() async {
    while (_isRunning && !_disposed) {
      try {
        await _captureAndTranscribeOnce();
      } catch (error, stackTrace) {
        if (!_disposed) {
          _transcriptsController.addError(error, stackTrace);
        }
      }
      if (!_isRunning || _disposed) {
        break;
      }
      await Future<void>.delayed(_captureWindow);
    }
  }

  Future<void> _captureAndTranscribeOnce() async {
    final recorderPath = _recorderCommandPath;
    final transcribePath = _transcribeCommandPath;
    if (recorderPath == null || transcribePath == null) {
      return;
    }

    final outputDirectory =
        _outputDirectory ?? await Directory.systemTemp.createTemp('paperclip-voice-');
    await outputDirectory.create(recursive: true);
    final audioFile = File(
      _joinPath(
        outputDirectory.path,
        'chunk-${DateTime.now().microsecondsSinceEpoch}.wav',
      ),
    );
    final transcriptionBase = _basenameWithoutExtension(audioFile.path);

    await _runProcess(
      recorderPath,
      [audioFile.path],
      timeout: _commandTimeout,
    );
    await _runProcess(
      transcribePath,
      [audioFile.path, '--output_dir', outputDirectory.path],
      timeout: _commandTimeout,
    );

    String transcriptText = '';
    final transcriptFile = File(
      _joinPath(outputDirectory.path, '$transcriptionBase.txt'),
    );
    if (await transcriptFile.exists()) {
      transcriptText = await transcriptFile.readAsString();
    }

    transcriptText = cleanVoiceTranscript(transcriptText);
    if (transcriptText.isEmpty) {
      return;
    }

    _transcriptsController.add(
      VoiceInputTranscriptEvent(
        text: transcriptText,
        isFinal: true,
        source: VoiceInputSource.native,
      ),
    );
  }

  Future<ProcessResult> _runProcess(
    String executable,
    List<String> arguments, {
    required Duration timeout,
  }) async {
    final future = _processRunner(
      executable,
      arguments,
      environment: null,
    );
    return future.timeout(timeout);
  }

  Future<File> _writeTempWavFile(Uint8List pcmBytes) async {
    final tempDir = await Directory.systemTemp.createTemp('paperclip-voice-');
    final file = File(
      _joinPath(
        tempDir.path,
        'chunk-${DateTime.now().microsecondsSinceEpoch}.wav',
      ),
    );
    final wavBytes = _buildWavBytes(pcmBytes);
    await file.writeAsBytes(wavBytes, flush: true);
    return file;
  }

  Uint8List _buildWavBytes(Uint8List pcmBytes) {
    const sampleRate = 16000;
    const channels = 1;
    const bitsPerSample = 16;
    const bytesPerSample = bitsPerSample ~/ 8;
    final byteRate = sampleRate * channels * bytesPerSample;
    final blockAlign = channels * bytesPerSample;
    final dataLength = pcmBytes.length;
    final totalLength = 44 + dataLength;
    final buffer = Uint8List(totalLength);
    final bytes = ByteData.sublistView(buffer);

    void writeAscii(int offset, String value) {
      for (var i = 0; i < value.length; i++) {
        buffer[offset + i] = value.codeUnitAt(i);
      }
    }

    writeAscii(0, 'RIFF');
    bytes.setUint32(4, 36 + dataLength, Endian.little);
    writeAscii(8, 'WAVE');
    writeAscii(12, 'fmt ');
    bytes.setUint32(16, 16, Endian.little);
    bytes.setUint16(20, 1, Endian.little);
    bytes.setUint16(22, channels, Endian.little);
    bytes.setUint32(24, sampleRate, Endian.little);
    bytes.setUint32(28, byteRate, Endian.little);
    bytes.setUint16(32, blockAlign, Endian.little);
    bytes.setUint16(34, bitsPerSample, Endian.little);
    writeAscii(36, 'data');
    bytes.setUint32(40, dataLength, Endian.little);
    buffer.setRange(44, 44 + dataLength, pcmBytes);
    return buffer;
  }

  bool _isTrusted(String path, List<String>? trustedPaths) {
    if (trustedPaths == null || trustedPaths.isEmpty) {
      return true;
    }
    return trustedPaths.contains(path);
  }

  String _joinPath(String left, String right) {
    if (left.endsWith(Platform.pathSeparator)) {
      return '$left$right';
    }
    return '$left${Platform.pathSeparator}$right';
  }

  String _basenameWithoutExtension(String path) {
    final fileName = path.split(Platform.pathSeparator).last;
    final dotIndex = fileName.lastIndexOf('.');
    if (dotIndex == -1) {
      return fileName;
    }
    return fileName.substring(0, dotIndex);
  }
}
