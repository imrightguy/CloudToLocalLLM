import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;

import '../models.dart';
import 'api_service.dart';
import 'unit_service.dart';

const String propertyPhotoCompanyId = '388be569-9d9d-46e2-b548-7bf0167cb11b';

abstract class PropertyPhotoContextSource {
  Future<List<BuildingItem>> getBuildings();
  Future<List<UnitItem>> getUnitsByBuilding(String buildingId);
}

class ApiPropertyPhotoContextSource implements PropertyPhotoContextSource {
  const ApiPropertyPhotoContextSource();

  @override
  Future<List<BuildingItem>> getBuildings() => UnitService.instance.getBuildings();

  @override
  Future<List<UnitItem>> getUnitsByBuilding(String buildingId) =>
      UnitService.instance.getUnitsByBuilding(buildingId);
}

abstract class PropertyPhotoUploader {
  Future<Map<String, dynamic>> uploadPhoto({
    required String companyId,
    required String buildingId,
    required Uint8List fileBytes,
    required String fileName,
    required String fileType,
    String? unitId,
    String? roomContext,
    required String useCase,
    int displayOrder,
    String? documentRefId,
    DateTime? capturedAt,
    Map<String, dynamic> metadata = const {},
  });
}

class ApiPropertyPhotoUploader implements PropertyPhotoUploader {
  ApiPropertyPhotoUploader({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

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
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${ApiService.baseUrl}/companies/$companyId/photos/upload'),
    );

    final token = ApiService.instance.accessToken;
    if (token.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        fileBytes,
        filename: fileName,
        contentType: http.MediaType.parse(fileType),
      ),
    );

    request.fields['buildingId'] = buildingId;
    request.fields['useCase'] = useCase;
    request.fields['displayOrder'] = displayOrder.toString();
    if (unitId != null && unitId.isNotEmpty) {
      request.fields['unitId'] = unitId;
    }
    if (roomContext != null && roomContext.isNotEmpty) {
      request.fields['roomContext'] = roomContext;
    }
    if (documentRefId != null && documentRefId.isNotEmpty) {
      request.fields['documentRefId'] = documentRefId;
    }
    if (capturedAt != null) {
      request.fields['capturedAt'] = capturedAt.toIso8601String();
    }
    if (metadata.isNotEmpty) {
      request.fields['metadata'] = jsonEncode(metadata);
    }

    final streamedResponse = await _client.send(request);
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 401) {
      throw const ApiException('Session expirée — veuillez vous reconnecter', statusCode: 401);
    }

    Map<String, dynamic> payload;
    try {
      payload = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw ApiException('Réponse invalide du serveur', statusCode: response.statusCode);
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final errorPayload = payload['error'];
      final message = errorPayload is Map
          ? errorPayload['message']?.toString() ?? 'Erreur ${response.statusCode}'
          : payload['message']?.toString() ?? 'Erreur ${response.statusCode}';
      final code = errorPayload is Map ? errorPayload['code']?.toString() : payload['code']?.toString();
      throw ApiException(message, statusCode: response.statusCode, code: code);
    }

    final data = payload['data'];
    if (data is Map<String, dynamic>) {
      return data;
    }
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    return payload;
  }
}

abstract class PhotoPicker {
  Future<PickedPhoto?> pickPhoto();
}

class FilePickerPhotoPicker implements PhotoPicker {
  const FilePickerPhotoPicker();

  @override
  Future<PickedPhoto?> pickPhoto() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
      allowMultiple: false,
    );
    final file = result?.files.isNotEmpty == true ? result!.files.first : null;
    if (file == null || file.bytes == null || file.bytes!.isEmpty) {
      return null;
    }

    final extension = (file.extension ?? '').toLowerCase();
    return PickedPhoto(
      fileName: file.name,
      fileType: _mimeTypeForExtension(extension),
      bytes: file.bytes!,
    );
  }
}

String _mimeTypeForExtension(String extension) {
  switch (extension) {
    case 'jpg':
    case 'jpeg':
      return 'image/jpeg';
    case 'png':
      return 'image/png';
    case 'webp':
      return 'image/webp';
    case 'gif':
      return 'image/gif';
    case 'heic':
      return 'image/heic';
    case 'heif':
      return 'image/heif';
    default:
      return 'application/octet-stream';
  }
}

class PickedPhoto {
  const PickedPhoto({
    required this.fileName,
    required this.fileType,
    required this.bytes,
  });

  final String fileName;
  final String fileType;
  final Uint8List bytes;
}
