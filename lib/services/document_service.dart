import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../models.dart';
import 'api_service.dart';

class DocumentService {
  DocumentService._();
  static final DocumentService instance = DocumentService._();

  Future<List<DocumentItem>> getDocuments({
    String? type,
    String? search,
    String? buildingId,
    String? unitId,
  }) async {
    final params = <String, String>{};
    if (type != null && type.isNotEmpty) params['type'] = type;
    if (search != null && search.isNotEmpty) params['search'] = search;
    if (buildingId != null && buildingId.isNotEmpty) params['buildingId'] = buildingId;
    if (unitId != null && unitId.isNotEmpty) params['unitId'] = unitId;

    final query = params.entries
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
        .join('&');
    final path = '/documents${query.isNotEmpty ? '?$query' : ''}';

    final result = await ApiService.instance.get(path);
    final data = result['data'];
    if (data is List) {
      return data
          .map((e) => DocumentItem.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [DocumentItem.fromJson(data as Map<String, dynamic>)];
  }

  Future<DocumentItem> getDocument(String id) async {
    final result = await ApiService.instance.get('/documents/$id');
    return DocumentItem.fromJson(result['data'] as Map<String, dynamic>);
  }

  Future<DocumentItem> uploadDocument({
    required String fileName,
    required String fileType,
    required Uint8List fileBytes,
    required String documentType,
    String? description,
    String? buildingId,
    String? unitId,
  }) async {
    final uri = Uri.parse('${ApiService.baseUrl}/documents');
    final request = http.MultipartRequest('POST', uri);

    request.headers.addAll(ApiService.instance.getHeaders());

    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        fileBytes,
        filename: fileName,
        contentType: http.MediaType.parse(fileType),
      ),
    );

    request.fields['documentType'] = documentType;
    if (description != null) request.fields['description'] = description;
    if (buildingId != null) request.fields['buildingId'] = buildingId;
    if (unitId != null) request.fields['unitId'] = unitId;

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 401) {
      throw const ApiException('Session expirée — veuillez vous reconnecter', statusCode: 401);
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      String errorMsg;
      try {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        errorMsg = body['message'] as String? ?? 'Erreur ${response.statusCode}';
      } catch (_) {
        errorMsg = 'Erreur ${response.statusCode}';
      }
      throw ApiException(errorMsg, statusCode: response.statusCode);
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return DocumentItem.fromJson(data['data'] as Map<String, dynamic>);
  }

  Future<void> deleteDocument(String id) async {
    await ApiService.instance.delete('/documents/$id');
  }
}
