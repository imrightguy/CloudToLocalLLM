import 'main_chat_timeline_record.dart';
import 'main_chat_timeline_sync_envelope.dart';
import 'main_chat_timeline_trust_store.dart';

class MainChatTimelinePairedDeviceDestination {
  final String deviceId;
  final String publicKey;
  final int? lastAcceptedSequence;
  final Set<String> approvedScopes;

  const MainChatTimelinePairedDeviceDestination({
    required this.deviceId,
    required this.publicKey,
    required this.lastAcceptedSequence,
    required this.approvedScopes,
  });

  bool allowsScope(String scope) {
    return approvedScopes.isEmpty || approvedScopes.contains(scope.trim());
  }
}

class MainChatTimelineDestinationSelector {
  final MainChatTimelineTrustStore trustStore;
  final String requiredScope;

  const MainChatTimelineDestinationSelector({
    required this.trustStore,
    this.requiredScope = 'main-chat-timeline-sync',
  });

  List<MainChatTimelinePairedDeviceDestination> selectDestinations({
    String? sourceDeviceId,
  }) {
    final normalizedSourceDeviceId = sourceDeviceId?.trim();
    final destinations = <MainChatTimelinePairedDeviceDestination>[];

    for (final device in trustStore.devices) {
      if (device.revoked || device.publicKey.trim().isEmpty) {
        continue;
      }
      if (normalizedSourceDeviceId != null &&
          normalizedSourceDeviceId.isNotEmpty &&
          device.deviceId == normalizedSourceDeviceId) {
        continue;
      }
      if (device.approvedScopes.isNotEmpty &&
          !device.approvedScopes.contains(requiredScope)) {
        continue;
      }
      destinations.add(
        MainChatTimelinePairedDeviceDestination(
          deviceId: device.deviceId,
          publicKey: device.publicKey,
          lastAcceptedSequence: device.lastAcceptedSequence,
          approvedScopes: device.approvedScopes,
        ),
      );
    }

    destinations.sort((left, right) => left.deviceId.compareTo(right.deviceId));
    return destinations;
  }
}

class MainChatTimelineSyncSenderContract {
  final MainChatTimelineTrustStore trustStore;
  final MainChatTimelineDestinationSelector destinationSelector;

  const MainChatTimelineSyncSenderContract({
    required this.trustStore,
    required this.destinationSelector,
  });

  List<MainChatTimelinePairedDeviceDestination> selectDestinations({
    required String sourceDeviceId,
  }) {
    _requireTrustedSourceDevice(sourceDeviceId);
    return destinationSelector.selectDestinations(sourceDeviceId: sourceDeviceId);
  }

  Future<MainChatTimelineSyncEnvelope> buildEnvelope({
    required String sourceDeviceId,
    required int sourceSequence,
    required MainChatTimelineSyncSigner signer,
    required Iterable<MainChatTimelineRecord> records,
    DateTime? createdAtUtc,
    int envelopeVersion = MainChatTimelineSyncEnvelope.currentEnvelopeVersion,
  }) async {
    _requireTrustedSourceDevice(sourceDeviceId);
    return MainChatTimelineSyncEnvelope.buildFromRecords(
      sourceDeviceId: sourceDeviceId,
      sourceSequence: sourceSequence,
      authorization: MainChatTimelineSyncAuthorization.pairedDevice(
        deviceId: sourceDeviceId,
      ),
      records: records,
      signer: signer,
      createdAtUtc: createdAtUtc,
      envelopeVersion: envelopeVersion,
    );
  }

  void _requireTrustedSourceDevice(String sourceDeviceId) {
    if (!trustStore.isTrusted(sourceDeviceId)) {
      throw const MainChatTimelineSyncException(
        'unpaired device cannot authorize sync writes',
      );
    }
  }
}
