import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:immogestion/models.dart';
import 'package:immogestion/services/property_photo_service.dart';
import 'package:immogestion/widgets/property_photo_upload_sheet.dart';

class _CapturingClient extends http.BaseClient {
  http.BaseRequest? lastRequest;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    lastRequest = request;
    final body = jsonEncode({
      'success': true,
      'data': {
        'id': 'photo-1',
        'url': 'https://example.com/photo-1.jpg',
      },
    });
    return http.StreamedResponse(
      Stream<List<int>>.value(utf8.encode(body)),
      201,
      headers: const {'content-type': 'application/json'},
      request: request,
    );
  }
}

class _FakeContextSource implements PropertyPhotoContextSource {
  @override
  Future<List<BuildingItem>> getBuildings() async {
    return [
      const BuildingItem(
        id: 'building-1',
        name: 'Place Du Parc',
        address: '123 rue des Pins',
        city: 'Montréal',
        totalUnits: 10,
        occupiedUnits: 8,
        monthlyRevenue: 12345,
        units: [],
      ),
    ];
  }

  @override
  Future<List<UnitItem>> getUnitsByBuilding(String buildingId) async {
    return [
      const UnitItem(
        id: 'unit-1',
        buildingId: 'building-1',
        number: '304',
        type: '3 1/2',
        bedrooms: 1,
        bathrooms: 1,
        rent: 145000,
        status: 'vacant',
        leaseEnd: '',
      ),
    ];
  }
}

class _FakeUploader implements PropertyPhotoUploader {
  Map<String, dynamic>? lastPayload;

  @override
  Future<Map<String, dynamic>> uploadPhoto({
    required String companyId,
    required String buildingId,
    required Uint8List fileBytes,
    required String fileName,
    required String fileType,
    String? unitId,
    String? roomContext,
    required String useCase,
    int displayOrder = 0,
    String? documentRefId,
    DateTime? capturedAt,
    Map<String, dynamic> metadata = const {},
  }) async {
    lastPayload = {
      'companyId': companyId,
      'buildingId': buildingId,
      'unitId': unitId,
      'fileBytes': fileBytes,
      'fileName': fileName,
      'fileType': fileType,
      'roomContext': roomContext,
      'useCase': useCase,
      'displayOrder': displayOrder,
      'documentRefId': documentRefId,
      'capturedAt': capturedAt,
      'metadata': metadata,
    };
    return {'id': 'photo-1'};
  }
}

class _FakePhotoPicker implements PhotoPicker {
  @override
  Future<PickedPhoto?> pickPhoto() async {
    return PickedPhoto(
      fileName: 'photo-salon.jpg',
      fileType: 'image/jpeg',
      bytes: Uint8List.fromList(<int>[1, 2, 3, 4]),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('ApiPropertyPhotoUploader sends multipart photo metadata to the backend', () async {
    final client = _CapturingClient();
    final uploader = ApiPropertyPhotoUploader(client: client);

    final response = await uploader.uploadPhoto(
      companyId: 'company-1',
      buildingId: 'building-1',
      unitId: 'unit-1',
      roomContext: 'Cuisine',
      useCase: 'maintenance',
      displayOrder: 2,
      capturedAt: DateTime.utc(2026, 5, 7, 4, 59, 0),
      fileName: 'photo.jpg',
      fileType: 'image/jpeg',
      fileBytes: Uint8List.fromList(<int>[9, 8, 7]),
      metadata: const {
        'source': 'frontend_operator',
        'surface': 'renovation_ops',
      },
    );

    expect(response['id'], 'photo-1');
    final request = client.lastRequest as http.MultipartRequest;
    expect(request.url.toString(), contains('/api/companies/company-1/photos/upload'));
    expect(request.fields['buildingId'], 'building-1');
    expect(request.fields['unitId'], 'unit-1');
    expect(request.fields['roomContext'], 'Cuisine');
    expect(request.fields['useCase'], 'maintenance');
    expect(request.fields['displayOrder'], '2');
    expect(request.fields['capturedAt'], '2026-05-07T04:59:00.000Z');
    expect(request.fields['metadata'], jsonEncode(const {
      'source': 'frontend_operator',
      'surface': 'renovation_ops',
    }));
    expect(request.files.single.filename, 'photo.jpg');
    expect(request.files.single.contentType.toString(), 'image/jpeg');
  });

  testWidgets('PropertyPhotoUploadSheet submits a property-scoped photo upload', (tester) async {
    final contextSource = _FakeContextSource();
    final uploader = _FakeUploader();
    final picker = _FakePhotoPicker();

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () {
                    showModalBottomSheet<bool>(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => PropertyPhotoUploadSheet(
                        initialBuildingName: 'Place Du Parc',
                        initialUnitLabel: '304',
                        apartmentLabel: 'Logement 304',
                        contextSource: contextSource,
                        photoUploader: uploader,
                        photoPicker: picker,
                      ),
                    );
                  },
                  child: const Text('Ouvrir'),
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Choisir une photo'));
    await tester.tap(find.text('Choisir une photo'));
    await tester.pumpAndSettle();

    expect(find.text('photo-salon.jpg'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(0), 'Cuisine');
    await tester.enterText(find.byType(TextField).at(1), '5');
    await tester.tap(find.text('Téléverser la photo'));
    await tester.pumpAndSettle();

    expect(uploader.lastPayload, isNotNull);
    expect(uploader.lastPayload!['companyId'], propertyPhotoCompanyId);
    expect(uploader.lastPayload!['buildingId'], 'building-1');
    expect(uploader.lastPayload!['unitId'], 'unit-1');
    expect(uploader.lastPayload!['roomContext'], 'Cuisine');
    expect(uploader.lastPayload!['useCase'], 'maintenance');
    expect(uploader.lastPayload!['displayOrder'], 5);
    expect(uploader.lastPayload!['metadata'], containsPair('surface', 'renovation_ops'));
    expect(find.text('Téléverser la photo'), findsNothing);
  });
}
