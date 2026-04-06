import 'package:flutter_test/flutter_test.dart';
import 'package:cloudtolocalllm/services/avatar/memory_service.dart';
import 'package:cloudtolocalllm/database/drift_local_brain.dart';

void main() {
  group('MemoryService', () {
    test('should create service with database', () {
      // Test that service can be instantiated
      // Note: Cannot test full functionality without native plugins
      final testDatabase = LocalBrain();
      addTearDown(() async => await testDatabase.close());
      final service = MemoryService(database: testDatabase);
      expect(service, isA<MemoryService>());
      expect(service.isInitialized, false);
    });

    test('should throw error when not initialized', () {
      final testDatabase = LocalBrain();
      addTearDown(() async => await testDatabase.close());
      final service = MemoryService(database: testDatabase);

      // Methods should throw StateError when not initialized
      expect(
        () => service.storeMemory(
          conversationId: 'test-conv-1',
          content: 'Test content',
        ),
        throwsStateError,
      );

      expect(
        () => service.searchMemories('test query'),
        throwsStateError,
      );

      expect(
        () => service.getMemoriesForConversation('test-conv-1'),
        throwsStateError,
      );
    });

    test('should have correct service structure', () {
      final testDatabase = LocalBrain();
      addTearDown(() async => await testDatabase.close());
      final service = MemoryService(database: testDatabase);

      // Verify service has expected methods and properties
      expect(service.isInitialized, isA<bool>());
      expect(service.lastError, isA<String?>());
      expect(service.database, isA<LocalBrain>());
    });
  });
}
