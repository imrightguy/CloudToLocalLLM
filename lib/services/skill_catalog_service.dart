import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

/// Represents a discovered, locally managed skill package.
class ManagedSkill {
  final String id;
  final String name;
  final String description;
  final String category;
  final String? version;
  final bool enabled;
  final String sourcePath;
  final String sourceScope;
  final DateTime lastModified;
  final List<String> tags;

  const ManagedSkill({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.enabled,
    required this.sourcePath,
    required this.sourceScope,
    required this.lastModified,
    this.version,
    this.tags = const [],
  });

  ManagedSkill copyWith({
    String? id,
    String? name,
    String? description,
    String? category,
    String? version,
    bool? enabled,
    String? sourcePath,
    String? sourceScope,
    DateTime? lastModified,
    List<String>? tags,
  }) {
    return ManagedSkill(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      category: category ?? this.category,
      version: version ?? this.version,
      enabled: enabled ?? this.enabled,
      sourcePath: sourcePath ?? this.sourcePath,
      sourceScope: sourceScope ?? this.sourceScope,
      lastModified: lastModified ?? this.lastModified,
      tags: tags ?? this.tags,
    );
  }
}

/// Service that discovers skill packages from local skill roots and tracks
/// whether they are enabled in the local operator cockpit.
class SkillCatalogService {
  static const String _enabledPrefix = 'skill_catalog.enabled.';
  final List<String> _scanRoots;
  final SharedPreferences? _sharedPreferences;

  SkillCatalogService({
    List<String>? scanRoots,
    SharedPreferences? sharedPreferences,
  })  : _scanRoots = scanRoots ?? _defaultScanRoots(),
        _sharedPreferences = sharedPreferences;

  static List<String> _defaultScanRoots() {
    final roots = <String>[];

    final home = Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        Platform.environment['HOMEPATH'];

    if (home != null && home.isNotEmpty) {
      roots.addAll([
        p.join(home, '.openclaw', 'skills'),
        p.join(home, '.config', 'openclaw', 'skills'),
        p.join(home, 'AppData', 'Roaming', 'openclaw', 'skills'),
      ]);
    }

    // Development workspace fallback so the cockpit can surface the in-repo
    // skill package when launched from source.
    roots.add('/paperclip/CloudToLocalLLM/services/openclaw-skills');

    return roots.toSet().toList(growable: false);
  }

  Future<SharedPreferences> get _prefs async {
    return _sharedPreferences ?? SharedPreferences.getInstance();
  }

  String _enabledKey(String skillId) => '$_enabledPrefix$skillId';

  Future<List<ManagedSkill>> listSkills() async {
    final prefs = await _prefs;
    final skills = <ManagedSkill>[];
    final seenIds = <String>{};

    for (final root in _scanRoots) {
      final directory = Directory(root);
      if (!directory.existsSync()) {
        continue;
      }

      final candidates = directory
          .listSync(recursive: true, followLinks: false)
          .whereType<File>()
          .where((file) => p.basename(file.path) == 'SKILL.md');

      for (final file in candidates) {
        final skill = await _readSkillFile(file, prefs);
        if (skill == null || seenIds.contains(skill.id)) {
          continue;
        }
        seenIds.add(skill.id);
        skills.add(skill);
      }
    }

    skills.sort((a, b) {
      final categoryCompare = a.category.compareTo(b.category);
      if (categoryCompare != 0) return categoryCompare;
      return a.name.compareTo(b.name);
    });

    return skills;
  }

  Future<void> setSkillEnabled(String skillId, bool enabled) async {
    final prefs = await _prefs;
    await prefs.setBool(_enabledKey(skillId), enabled);
  }

  Future<Map<String, int>> categoryCounts() async {
    final skills = await listSkills();
    final counts = <String, int>{};
    for (final skill in skills) {
      counts[skill.category] = (counts[skill.category] ?? 0) + 1;
    }
    return counts;
  }

  Future<ManagedSkill?> _readSkillFile(
      File file, SharedPreferences prefs) async {
    try {
      final content = await file.readAsString();
      final metadata = _parseFrontmatter(content);
      final name = metadata['name'] ??
          _titleFromContent(content) ??
          p.basename(p.dirname(file.path));
      final description = metadata['description'] ??
          _descriptionFromContent(content) ??
          'No description provided';
      final category = metadata['category'] ?? _categoryFromPath(file.path);
      final version = metadata['version'];
      final tags = _parseTags(metadata['tags']);
      final skillId = _skillIdFromPath(file.path, metadata['id']);
      final sourceScope = _sourceScopeFromPath(file.path);
      final enabled = prefs.getBool(_enabledKey(skillId)) ?? true;
      final lastModified = await file.lastModified();

      return ManagedSkill(
        id: skillId,
        name: name,
        description: description,
        category: category,
        version: version,
        enabled: enabled,
        sourcePath: file.parent.path,
        sourceScope: sourceScope,
        lastModified: lastModified,
        tags: tags,
      );
    } catch (e) {
      debugPrint('[SkillCatalogService] Failed to read ${file.path}: $e');
      return null;
    }
  }

  Map<String, String> _parseFrontmatter(String content) {
    final lines = content.split('\n');
    if (lines.isEmpty || lines.first.trim() != '---') {
      return const {};
    }

    final metadata = <String, String>{};
    var index = 1;
    while (index < lines.length) {
      final line = lines[index].trimRight();
      if (line.trim() == '---') {
        break;
      }

      final colonIndex = line.indexOf(':');
      if (colonIndex != -1) {
        final key = line.substring(0, colonIndex).trim();
        final rawValue = line.substring(colonIndex + 1).trim();
        if (key.isNotEmpty) {
          metadata[key] = rawValue;
        }
      }
      index += 1;
    }

    return metadata;
  }

  List<String> _parseTags(String? rawTags) {
    if (rawTags == null || rawTags.isEmpty) {
      return const [];
    }

    final trimmed = rawTags.trim();
    if (trimmed.startsWith('[') && trimmed.endsWith(']')) {
      final inner = trimmed.substring(1, trimmed.length - 1);
      return inner
          .split(',')
          .map((tag) {
            final cleaned = tag.trim();
            if (cleaned.length >= 2) {
              final first = cleaned.codeUnitAt(0);
              final last = cleaned.codeUnitAt(cleaned.length - 1);
              if ((first == 34 && last == 34) || (first == 39 && last == 39)) {
                return cleaned.substring(1, cleaned.length - 1);
              }
            }
            return cleaned;
          })
          .where((tag) => tag.isNotEmpty)
          .toList(growable: false);
    }

    return trimmed
        .split(',')
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toList(growable: false);
  }

  String _skillIdFromPath(String filePath, String? metadataId) {
    if (metadataId != null && metadataId.trim().isNotEmpty) {
      return metadataId.trim();
    }
    return p.basename(p.dirname(filePath));
  }

  String _categoryFromPath(String filePath) {
    final parent = p.basename(p.dirname(filePath));
    final grandparent = p.basename(p.dirname(p.dirname(filePath)));
    if (parent.isNotEmpty && parent.toLowerCase() != 'skills') {
      return parent;
    }
    if (grandparent.isNotEmpty) {
      return grandparent;
    }
    return 'General';
  }

  String _sourceScopeFromPath(String filePath) {
    final normalized = filePath.toLowerCase();
    if (normalized.contains('.openclaw') ||
        normalized.contains('appdata/roaming/openclaw') ||
        normalized.contains('.config/openclaw')) {
      return 'runtime';
    }
    if (normalized.contains('services/openclaw-skills')) {
      return 'repository';
    }
    return 'discovered';
  }

  String? _titleFromContent(String content) {
    final match = RegExp(r'^#\s+(.+)$', multiLine: true).firstMatch(content);
    return match?.group(1)?.trim();
  }

  String? _descriptionFromContent(String content) {
    final lines = content
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);

    for (final line in lines) {
      if (line.startsWith('#') || line == '---') {
        continue;
      }
      if (line.startsWith('- ')) {
        return line.substring(2).trim();
      }
      return line;
    }

    return null;
  }
}
