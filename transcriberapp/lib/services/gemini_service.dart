import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

class GeminiService {
  final String baseUrl;
  final String apiSecret;

  GeminiService(this.baseUrl, this.apiSecret);

  /// Sends audio to our Python Backend and waits for the result.
  Future<String> transcribeAudio(File file, String mimeType) async {
    // 1. Prepare the Endpoint URL
    final uri = Uri.parse("$baseUrl/transcribe");

    // 2. Prepare the Multipart Request
    var request = http.MultipartRequest('POST', uri);
    request.headers['x-app-secret'] = apiSecret;
    
    // 3. Attach the File
    request.files.add(await http.MultipartFile.fromPath(
      'file',
      file.path,
      contentType: MediaType.parse(mimeType),
    ));

    try {
      // 4. Send the Request with timeout
      final streamedResponse = await request.send().timeout(
        const Duration(minutes: 3),
        onTimeout: () {
          throw TimeoutException('Server took too long to respond. Please try again.');
        },
      );
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        // 5. Success! Parse the JSON
        final data = jsonDecode(response.body);
        
        if (data['status'] == 'success') {
          return data['transcription'];
        } else {
          throw Exception(data['message'] ?? "Unknown backend error");
        }
      } else if (response.statusCode == 503) {
        throw Exception("Server is overloaded. Please try again in a moment.");
      } else if (response.statusCode >= 500) {
        throw Exception("Server error. Please try again later.");
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        throw Exception("Authentication failed. Please check app configuration.");
      } else {
        throw Exception("Server Error (${response.statusCode}): ${response.body}");
      }
    } on SocketException {
      throw Exception("No internet connection. Please check your network.");
    } on TimeoutException catch (e) {
      throw Exception(e.message ?? 'Request timeout');
    } catch (e) {
      if (e.toString().contains('Failed host lookup')) {
        throw Exception("Cannot reach server. Please check your internet connection.");
      }
      throw Exception("Connection failed: $e");
    }
  }
  
  // NOTE: The old 'uploadFile' and 'generateContent' methods are deleted.
  // The backend handles the 2-step process now.
}