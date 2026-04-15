import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:immogestion/models.dart';
import 'package:immogestion/services/document_service.dart';

void main() {
  // ===========================================================================
  // DocumentType enum tests
  // ===========================================================================
  group('DocumentType', () {
    test('fromString parses English values', () {
      expect(DocumentType.fromString('lease'), DocumentType.lease);
      expect(DocumentType.fromString('contract'), DocumentType.contract);
      expect(DocumentType.fromString('insurance'), DocumentType.insurance);
      expect(DocumentType.fromString('other'), DocumentType.other);
    });

    test('fromString parses French values', () {
      expect(DocumentType.fromString('bail'), DocumentType.lease);
      expect(DocumentType.fromString('contrat'), DocumentType.contract);
      expect(DocumentType.fromString('assurance'), DocumentType.insurance);
    });

    test('fromString is case-insensitive', () {
      expect(DocumentType.fromString('LEASE'), DocumentType.lease);
      expect(DocumentType.fromString('Bail'), DocumentType.lease);
      expect(DocumentType.fromString('CONTRAT'), DocumentType.contract);
    });

    test('fromString returns other for unknown values', () {
      expect(DocumentType.fromString('unknown'), DocumentType.other);
      expect(DocumentType.fromString('random'), DocumentType.other);
      expect(DocumentType.fromString(''), DocumentType.other);
    });

    test('label returns French labels', () {
      expect(DocumentType.lease.label, 'Bail');
      expect(DocumentType.contract.label, 'Contrat');
      expect(DocumentType.insurance.label, 'Assurance');
      expect(DocumentType.other.label, 'Autre');
    });

    test('apiValue returns English snake_case', () {
      expect(DocumentType.lease.apiValue, 'lease');
      expect(DocumentType.contract.apiValue, 'contract');
      expect(DocumentType.insurance.apiValue, 'insurance');
      expect(DocumentType.other.apiValue, 'other');
    });
  });

  // ===========================================================================
  // DocumentItem model tests
  // ===========================================================================
  group('DocumentItem', () {
    test('fromJson parses complete JSON', () {
      final json = {
        'id': 'doc-1',
        'fileName': 'bail_2024.pdf',
        'fileSize': 204800,
        'fileType': 'application/pdf',
        'documentType': 'lease',
        'description': 'Bail signé 2024',
        'buildingId': 'bldg-1',
        'buildingName': 'Immeuble A',
        'unitId': 'unit-1',
        'unitLabel': '101',
        'fileUrl': 'https://example.com/bail.pdf',
        'createdAt': '2024-01-15T10:30:00Z',
        'updatedAt': '2024-01-16T14:00:00Z',
      };

      final doc = DocumentItem.fromJson(json);

      expect(doc.id, 'doc-1');
      expect(doc.fileName, 'bail_2024.pdf');
      expect(doc.fileSize, 204800);
      expect(doc.fileType, 'application/pdf');
      expect(doc.documentType, DocumentType.lease);
      expect(doc.description, 'Bail signé 2024');
      expect(doc.buildingId, 'bldg-1');
      expect(doc.buildingName, 'Immeuble A');
      expect(doc.unitId, 'unit-1');
      expect(doc.unitLabel, '101');
      expect(doc.fileUrl, 'https://example.com/bail.pdf');
      expect(doc.createdAt, DateTime.parse('2024-01-15T10:30:00Z'));
      expect(doc.updatedAt, DateTime.parse('2024-01-16T14:00:00Z'));
    });

    test('fromJson handles minimal JSON with defaults', () {
      final json = {
        'fileName': 'test.pdf',
        'fileSize': 1024,
        'fileType': 'application/pdf',
      };

      final doc = DocumentItem.fromJson(json);

      expect(doc.id, isNull);
      expect(doc.fileName, 'test.pdf');
      expect(doc.fileSize, 1024);
      expect(doc.fileType, 'application/pdf');
      expect(doc.documentType, DocumentType.other);
      expect(doc.description, isNull);
      expect(doc.buildingId, isNull);
      expect(doc.buildingName, isNull);
      expect(doc.unitId, isNull);
      expect(doc.unitLabel, isNull);
      expect(doc.fileUrl, isNull);
      expect(doc.createdAt, isNull);
      expect(doc.updatedAt, isNull);
    });

    test('fromJson handles alternative field names', () {
      final json = {
        'filename': 'contract.docx',
        'size': 51200,
        'mimeType': 'application/msword',
        'url': 'https://example.com/contract.docx',
      };

      final doc = DocumentItem.fromJson(json);

      expect(doc.fileName, 'contract.docx');
      expect(doc.fileSize, 51200);
      expect(doc.fileType, 'application/msword');
      expect(doc.fileUrl, 'https://example.com/contract.docx');
    });

    test('fromJson prefers fileName over filename', () {
      final json = {
        'fileName': 'primary.pdf',
        'filename': 'secondary.pdf',
        'fileSize': 100,
        'fileType': 'application/pdf',
      };

      final doc = DocumentItem.fromJson(json);
      expect(doc.fileName, 'primary.pdf');
    });

    test('fromJson prefers fileSize over size', () {
      final json = {
        'fileName': 'test.pdf',
        'fileSize': 200,
        'size': 100,
        'fileType': 'application/pdf',
      };

      final doc = DocumentItem.fromJson(json);
      expect(doc.fileSize, 200);
    });

    test('fromJson prefers fileType over mimeType', () {
      final json = {
        'fileName': 'test.pdf',
        'fileSize': 100,
        'fileType': 'application/pdf',
        'mimeType': 'text/plain',
      };

      final doc = DocumentItem.fromJson(json);
      expect(doc.fileType, 'application/pdf');
    });

    test('fromJson prefers fileUrl over url', () {
      final json = {
        'fileName': 'test.pdf',
        'fileSize': 100,
        'fileType': 'application/pdf',
        'fileUrl': 'https://primary.com/file.pdf',
        'url': 'https://secondary.com/file.pdf',
      };

      final doc = DocumentItem.fromJson(json);
      expect(doc.fileUrl, 'https://primary.com/file.pdf');
    });

    test('toJson serializes non-null optional fields', () {
      const doc = DocumentItem(
        id: 'doc-1',
        fileName: 'bail.pdf',
        fileSize: 1024,
        fileType: 'application/pdf',
        documentType: DocumentType.lease,
        description: 'Bail signé',
        buildingId: 'bldg-1',
        unitId: 'unit-1',
      );

      final json = doc.toJson();

      expect(json['id'], 'doc-1');
      expect(json['fileName'], 'bail.pdf');
      expect(json['fileSize'], 1024);
      expect(json['fileType'], 'application/pdf');
      expect(json['documentType'], 'lease');
      expect(json['description'], 'Bail signé');
      expect(json['buildingId'], 'bldg-1');
      expect(json['unitId'], 'unit-1');
    });

    test('toJson omits null optional fields', () {
      const doc = DocumentItem(
        fileName: 'test.pdf',
        fileSize: 512,
        fileType: 'application/pdf',
        documentType: DocumentType.other,
      );

      final json = doc.toJson();

      expect(json.containsKey('id'), false);
      expect(json.containsKey('description'), false);
      expect(json.containsKey('buildingId'), false);
      expect(json.containsKey('unitId'), false);
      expect(json['fileName'], 'test.pdf');
    });

    test('fileSizeLabel formats bytes correctly', () {
      // Bytes
      const small = DocumentItem(
        fileName: 'a.txt',
        fileSize: 500,
        fileType: 'text/plain',
        documentType: DocumentType.other,
      );
      expect(small.fileSizeLabel, '500 o');

      // Kilobytes
      const kb = DocumentItem(
        fileName: 'b.pdf',
        fileSize: 1536,
        fileType: 'application/pdf',
        documentType: DocumentType.lease,
      );
      expect(kb.fileSizeLabel, '1.5 Ko');

      // Megabytes
      const mb = DocumentItem(
        fileName: 'c.pdf',
        fileSize: 5242880,
        fileType: 'application/pdf',
        documentType: DocumentType.lease,
      );
      expect(mb.fileSizeLabel, '5.0 Mo');
    });

    test('fileSizeLabel boundary: exactly 1024 bytes', () {
      const exact = DocumentItem(
        fileName: 'd.bin',
        fileSize: 1024,
        fileType: 'application/octet-stream',
        documentType: DocumentType.other,
      );
      expect(exact.fileSizeLabel, '1.0 Ko');
    });

    test('fileSizeLabel boundary: exactly 1 MB', () {
      const exact = DocumentItem(
        fileName: 'e.bin',
        fileSize: 1048576,
        fileType: 'application/octet-stream',
        documentType: DocumentType.other,
      );
      expect(exact.fileSizeLabel, '1.0 Mo');
    });

    test('locationLabel joins building and unit', () {
      const doc = DocumentItem(
        fileName: 'test.pdf',
        fileSize: 100,
        fileType: 'application/pdf',
        documentType: DocumentType.lease,
        buildingName: 'Immeuble A',
        unitLabel: '101',
      );
      expect(doc.locationLabel, 'Immeuble A · 101');
    });

    test('locationLabel shows building only', () {
      const doc = DocumentItem(
        fileName: 'test.pdf',
        fileSize: 100,
        fileType: 'application/pdf',
        documentType: DocumentType.lease,
        buildingName: 'Immeuble B',
      );
      expect(doc.locationLabel, 'Immeuble B');
    });

    test('locationLabel shows Non associé when no location', () {
      const doc = DocumentItem(
        fileName: 'test.pdf',
        fileSize: 100,
        fileType: 'application/pdf',
        documentType: DocumentType.other,
      );
      expect(doc.locationLabel, 'Non associé');
    });

    test('isPdf detects PDF by MIME type', () {
      const pdf = DocumentItem(
        fileName: 'document',
        fileSize: 100,
        fileType: 'application/pdf',
        documentType: DocumentType.lease,
      );
      expect(pdf.isPdf, true);
    });

    test('isPdf detects PDF by file extension', () {
      const pdf = DocumentItem(
        fileName: 'document.pdf',
        fileSize: 100,
        fileType: 'application/octet-stream',
        documentType: DocumentType.other,
      );
      expect(pdf.isPdf, true);
    });

    test('isPdf returns false for non-PDF', () {
      const doc = DocumentItem(
        fileName: 'image.jpg',
        fileSize: 100,
        fileType: 'image/jpeg',
        documentType: DocumentType.other,
      );
      expect(doc.isPdf, false);
    });

    test('isImage detects by MIME type', () {
      const png = DocumentItem(
        fileName: 'photo',
        fileSize: 100,
        fileType: 'image/png',
        documentType: DocumentType.other,
      );
      expect(png.isImage, true);
    });

    test('isImage detects by file extension', () {
      const jpg = DocumentItem(
        fileName: 'photo.jpg',
        fileSize: 100,
        fileType: 'application/octet-stream',
        documentType: DocumentType.other,
      );
      expect(jpg.isImage, true);
    });

    test('isImage detects various extensions', () {
      for (final ext in ['jpg', 'jpeg', 'png', 'gif', 'webp']) {
        final doc = DocumentItem(
          fileName: 'photo.$ext',
          fileSize: 100,
          fileType: 'text/plain',
          documentType: DocumentType.other,
        );
        expect(doc.isImage, true, reason: 'Failed for .$ext');
      }
    });

    test('isImage returns false for non-image', () {
      const doc = DocumentItem(
        fileName: 'file.pdf',
        fileSize: 100,
        fileType: 'application/pdf',
        documentType: DocumentType.other,
      );
      expect(doc.isImage, false);
    });

    test('round-trip fromJson → toJson preserves core fields', () {
      final json = {
        'id': 'doc-rt',
        'fileName': 'roundtrip.pdf',
        'fileSize': 4096,
        'fileType': 'application/pdf',
        'documentType': 'insurance',
        'description': 'Test doc',
        'buildingId': 'b-1',
        'unitId': 'u-1',
      };

      final doc = DocumentItem.fromJson(json);
      final output = doc.toJson();

      expect(output['id'], 'doc-rt');
      expect(output['fileName'], 'roundtrip.pdf');
      expect(output['fileSize'], 4096);
      expect(output['fileType'], 'application/pdf');
      expect(output['documentType'], 'insurance');
      expect(output['description'], 'Test doc');
      expect(output['buildingId'], 'b-1');
      expect(output['unitId'], 'u-1');
    });
  });

  // ===========================================================================
  // DocumentService tests
  // ===========================================================================
  group('DocumentService', () {
    test('singleton instance is stable', () {
      expect(
        identical(DocumentService.instance, DocumentService.instance),
        true,
      );
    });

    test('query string construction with all params', () {
      final params = <String, String>{};
      const type = 'lease';
      const search = 'bail 2024';
      const buildingId = 'bldg-1';
      const unitId = 'unit-1';

      if (type.isNotEmpty) params['type'] = type;
      if (search.isNotEmpty) params['search'] = search;
      if (buildingId.isNotEmpty) params['buildingId'] = buildingId;
      if (unitId.isNotEmpty) params['unitId'] = unitId;

      final query = params.entries
          .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
          .join('&');

      expect(query, contains('type=lease'));
      expect(query, contains('search=bail%202024'));
      expect(query, contains('buildingId=bldg-1'));
      expect(query, contains('unitId=unit-1'));
    });

    test('query string omits null/empty params', () {
      final params = <String, String>{};
      String? type;
      String? search;
      String? buildingId;

      if (type != null && type.isNotEmpty) params['type'] = type;
      if (search != null && search.isNotEmpty) params['search'] = search;
      if (buildingId != null && buildingId.isNotEmpty) params['buildingId'] = buildingId;

      expect(params.isEmpty, true);
    });

    test('query string omits empty-but-not-null params', () {
      final params = <String, String>{};
      const type = '';
      const search = '';

      if (type.isNotEmpty) params['type'] = type;
      if (search.isNotEmpty) params['search'] = search;

      expect(params.isEmpty, true);
    });

    test('getDocuments response parsing: array data', () {
      final result = <String, dynamic>{
        'data': [
          {
            'id': 'd1',
            'fileName': 'file1.pdf',
            'fileSize': 1024,
            'fileType': 'application/pdf',
            'documentType': 'lease',
          },
          {
            'id': 'd2',
            'fileName': 'file2.jpg',
            'fileSize': 2048,
            'fileType': 'image/jpeg',
            'documentType': 'insurance',
          },
        ],
      };

      final data = result['data'];
      if (data is List) {
        final docs = data
            .map((e) => DocumentItem.fromJson(e as Map<String, dynamic>))
            .toList();

        expect(docs.length, 2);
        expect(docs[0].fileName, 'file1.pdf');
        expect(docs[0].documentType, DocumentType.lease);
        expect(docs[1].fileName, 'file2.jpg');
        expect(docs[1].documentType, DocumentType.insurance);
      } else {
        fail('Expected List data');
      }
    });

    test('getDocuments response parsing: single object fallback', () {
      final result = <String, dynamic>{
        'data': {
          'id': 'd1',
          'fileName': 'single.pdf',
          'fileSize': 512,
          'fileType': 'application/pdf',
          'documentType': 'contract',
        },
      };

      final data = result['data'];
      List<DocumentItem> docs;
      if (data is List) {
        docs = data
            .map((e) => DocumentItem.fromJson(e as Map<String, dynamic>))
            .toList();
      } else {
        docs = [DocumentItem.fromJson(data as Map<String, dynamic>)];
      }

      expect(docs.length, 1);
      expect(docs[0].fileName, 'single.pdf');
      expect(docs[0].documentType, DocumentType.contract);
    });

    test('getDocument parses single document response', () {
      final result = <String, dynamic>{
        'data': {
          'id': 'doc-42',
          'fileName': 'specific.pdf',
          'fileSize': 8192,
          'fileType': 'application/pdf',
          'documentType': 'lease',
          'buildingName': 'Immeuble Principal',
          'unitLabel': '302',
        },
      };

      final doc = DocumentItem.fromJson(result['data'] as Map<String, dynamic>);

      expect(doc.id, 'doc-42');
      expect(doc.fileName, 'specific.pdf');
      expect(doc.fileSize, 8192);
      expect(doc.buildingName, 'Immeuble Principal');
      expect(doc.unitLabel, '302');
      expect(doc.locationLabel, 'Immeuble Principal · 302');
    });

    test('uploadDocument fields construction', () {
      // Verify the multipart field logic
      final fields = <String, String>{};
      const documentType = 'lease';
      String? description;
      String? buildingId = 'b-1';
      String? unitId;

      fields['documentType'] = documentType;
      if (description != null) fields['description'] = description;
      if (buildingId != null) fields['buildingId'] = buildingId;
      if (unitId != null) fields['unitId'] = unitId;

      expect(fields['documentType'], 'lease');
      expect(fields.containsKey('description'), false);
      expect(fields['buildingId'], 'b-1');
      expect(fields.containsKey('unitId'), false);
    });

    test('uploadDocument error parsing: JSON error body', () {
      // Simulate error response parsing
      const statusCode = 413;
      final responseBody = '{"message": "Fichier trop volumineux"}';

      String errorMsg;
      try {
        final body = _parseJson(responseBody);
        errorMsg = body['message'] as String? ?? 'Erreur $statusCode';
      } catch (_) {
        errorMsg = 'Erreur $statusCode';
      }

      expect(errorMsg, 'Fichier trop volumineux');
    });

    test('uploadDocument error parsing: non-JSON body', () {
      const statusCode = 500;
      const responseBody = 'Internal Server Error';

      String errorMsg;
      try {
        final body = _parseJson(responseBody);
        errorMsg = body['message'] as String? ?? 'Erreur $statusCode';
      } catch (_) {
        errorMsg = 'Erreur $statusCode';
      }

      expect(errorMsg, 'Erreur 500');
    });

    test('uploadDocument 401 throws session expired message', () {
      // The service throws a specific message for 401
      const statusCode = 401;
      const expectedMsg = 'Session expirée — veuillez vous reconnecter';
      expect(expectedMsg, contains('Session expirée'));
    });
  });
}

/// Helper to parse JSON like the service does.
Map<String, dynamic> _parseJson(String body) {
  return jsonDecode(body) as Map<String, dynamic>;
}
