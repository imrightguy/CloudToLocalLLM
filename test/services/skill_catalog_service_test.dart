import 'dart:io';

import 'package:cloudtolocalllm/services/skill_catalog_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('discovers skill metadata from SKILL.md and persists enablement',
      () async {
    final tempRoot = Directory.systemTemp.createTempSync('skill_catalog_test_');
    addTearDown(() async {
      if (await tempRoot.exists()) {
        await tempRoot.delete(recursive: true);
      }
    });

    final skillDir = Directory(p.join(tempRoot.path, 'review-skill'));
    skillDir.createSync(recursive: true);
    File(p.join(skillDir.path, 'SKILL.md')).writeAsStringSync('''---
name: Review Skill
description: Reviews code for issues.
version: 1.2.3
category: Development
tags: [review, code]
---

# Review Skill

This skill reviews pull requests.
''');

    final prefs = await SharedPreferences.getInstance();
    final service = SkillCatalogService(
      scanRoots: [tempRoot.path],
      sharedPreferences: prefs,
    );

    final skills = await service.listSkills();
    expect(skills, hasLength(1));

    final skill = skills.single;
    expect(skill.id, 'review-skill');
    expect(skill.name, 'Review Skill');
    expect(skill.description, 'Reviews code for issues.');
    expect(skill.category, 'Development');
    expect(skill.version, '1.2.3');
    expect(skill.enabled, isTrue);
    expect(skill.tags, ['review', 'code']);

    await service.setSkillEnabled(skill.id, false);
    final updatedSkills = await service.listSkills();
    expect(updatedSkills.single.enabled, isFalse);
  });
}
