import 'dart:io';

Future<String> readLocalThinkArtifactText(String path) {
  return File(path).readAsString();
}
