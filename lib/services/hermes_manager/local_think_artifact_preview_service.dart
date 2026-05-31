import 'local_think_artifact_text_reader_stub.dart'
    if (dart.library.io) 'local_think_artifact_text_reader_io.dart';
import 'local_think_environment_stub.dart'
    if (dart.library.io) 'local_think_environment_io.dart';

typedef LocalThinkArtifactTextReader = Future<String> Function(String path);

class LocalThinkArtifactPreviewService {
  static List<String> buildDefaultAllowedPathPrefixes({
    Map<String, String>? environment,
  }) {
    final env = environment ?? localThinkEnvironment();
    final prefixes = <String>[];

    void addScopedPrefix(String? rootPath) {
      final trimmed = rootPath?.trim();
      if (trimmed == null || trimmed.isEmpty) {
        return;
      }
      final normalized = trimmed.replaceAll('\\', '/');
      final alreadyScoped = normalized.endsWith('/.hermes/local-think') ||
          normalized.endsWith('/.hermes/local-think/');
      final scoped = alreadyScoped
          ? normalized
          : '$normalized/.hermes/local-think';
      final finalPrefix = scoped.endsWith('/') ? scoped : '$scoped/';
      if (!prefixes.contains(finalPrefix)) {
        prefixes.add(finalPrefix);
      }
    }

    addScopedPrefix(env['HOME']);
    addScopedPrefix(env['USERPROFILE']);

    final homeDrive = env['HOMEDRIVE']?.trim();
    final homePath = env['HOMEPATH']?.trim();
    if (homeDrive != null &&
        homeDrive.isNotEmpty &&
        homePath != null &&
        homePath.isNotEmpty) {
      addScopedPrefix('$homeDrive$homePath');
    }

    return prefixes;
  }

  final LocalThinkArtifactTextReader _textReader;
  final int _maxChars;
  final List<String> _allowedPathPrefixes;

  LocalThinkArtifactPreviewService({
    LocalThinkArtifactTextReader? textReader,
    int maxChars = 1200,
    List<String>? allowedPathPrefixes,
  })  : _textReader = textReader ?? readLocalThinkArtifactText,
        _maxChars = maxChars,
        _allowedPathPrefixes =
            allowedPathPrefixes ?? buildDefaultAllowedPathPrefixes();

  Future<String?> previewFinalFile(String? path) async {
    final rawPath = path?.trim();
    if (rawPath == null || rawPath.isEmpty) {
      return null;
    }
    final normalizedPath = _normalizePath(rawPath);
    if (!_isAllowedFinalFile(normalizedPath)) {
      return null;
    }

    try {
      final source = await _textReader(rawPath);
      return _safePreview(source);
    } catch (_) {
      return null;
    }
  }

  bool _isAllowedFinalFile(String path) {
    if (!path.endsWith('.final.md')) {
      return false;
    }
    if (_containsParentTraversal(path)) {
      return false;
    }
    return _allowedPathPrefixes.any((prefix) {
      final normalizedPrefix = _normalizePrefix(prefix);
      return path.startsWith(normalizedPrefix);
    });
  }

  String _normalizePrefix(String prefix) {
    final normalized = _normalizePath(prefix);
    return normalized.endsWith('/') ? normalized : '$normalized/';
  }

  String _normalizePath(String path) {
    return path.replaceAll('\\', '/');
  }

  bool _containsParentTraversal(String path) {
    return path.split('/').any((segment) => segment == '..');
  }

  String? _safePreview(String source) {
    final trimmed = source.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    if (trimmed.startsWith('[SILENT]')) {
      return 'Silent wake-gate skip.';
    }

    final redacted = _redactSecrets(trimmed);
    if (redacted.length <= _maxChars) {
      return redacted;
    }
    return '${redacted.substring(0, _maxChars)}...';
  }

  String _redactSecrets(String source) {
    var redacted = source.replaceAllMapped(
      RegExp(
        r'\b(api_key|token|password)(\s*[:=]\s*)([^\s]+)',
        caseSensitive: false,
      ),
      (match) => '${match.group(1)}${match.group(2)}[REDACTED]',
    );
    redacted = redacted.replaceAllMapped(
      RegExp(r'\bBearer\s+\S+', caseSensitive: false),
      (_) => 'Bearer [REDACTED]',
    );
    return redacted;
  }
}
