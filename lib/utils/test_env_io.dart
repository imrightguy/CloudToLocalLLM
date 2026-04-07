import 'dart:io';

bool isFlutterTestEnvironment() =>
    Platform.environment.containsKey('FLUTTER_TEST');
