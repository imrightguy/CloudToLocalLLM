import 'dart:async';
import '../database/drift_local_brain.dart';
import 'model_tiers.dart';

/// Manages LLM rate limits and model availability using Drift database
class RateLimitManager {
  final LocalBrain db;

  RateLimitManager(this.db);

  /// Checks if a model is currently available (concurrency < limit)
  Future<bool> isAvailable(String modelId) async {
    final capacity = await db.getModelCapacity(modelId);
    if (capacity == null) return true; // Assume available if unknown

    return capacity.concurrentUsed < capacity.concurrentLimit &&
        capacity.status == 'active';
  }

  /// Gets the best available model based on requested ID and tier fallbacks
  Future<String> getAvailableModel(String requestedModelId) async {
    final chain = ModelRegistry.getFallbackChain(requestedModelId);

    for (final modelId in chain) {
      if (await isAvailable(modelId)) {
        return modelId;
      }
    }

    // If everything in chain is busy, return the requested model (let gateway handle it)
    return requestedModelId;
  }

  /// Mark the start of a request
  Future<void> startRequest(String modelId) async {
    await db.updateUsage(modelId, 1);
  }

  /// Mark the end of a request
  Future<void> endRequest(String modelId) async {
    await db.updateUsage(modelId, -1);
  }

  /// Update capacity based on actual API headers (Trust but Verify)
  Future<void> syncFromHeader(String modelId, int remaining) async {
    await db.syncUsageFromHeader(modelId, remaining);
  }

  /// Get all capacities (for UI gauges)
  Stream<List<ModelCapacityData>> watchCapacities() {
    return db.watchAllModelCapacities();
  }
}
