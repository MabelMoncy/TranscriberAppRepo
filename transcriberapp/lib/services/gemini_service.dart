import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

class GeminiService {
  // We no longer need the API Key here! The server handles it.
  // We only need the Server URL.
  final String baseUrl;

  GeminiService(this.baseUrl);

  /// Sends audio to our Python Backend and waits for the result.
  Future<String> transcribeAudio(File file, String mimeType) async {
    // 1. Prepare the Endpoint URL
    // Note: ensure baseUrl does NOT end with a slash
    final uri = Uri.parse("$baseUrl/transcribe");

    // 2. Prepare the Multipart Request (The Envelope)
    var request = http.MultipartRequest('POST', uri);
    
    // 3. Attach the File
    request.files.add(await http.MultipartFile.fromPath(
      'file',
      file.path,
      contentType: MediaType.parse(mimeType),
    ));

    try {
      print("🚀 Sending to backend: $uri");
      
      // 4. Send the Request (The "Ack")
      // Use streamed response to handle long waits better
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      print("📩 Server Status: ${response.statusCode}");

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
      } else {
        throw Exception("Server Error (${response.statusCode}): ${response.body}");
      }
    } catch (e) {
      throw Exception("Connection failed: $e");
    }
  }
  
  // NOTE: The old 'uploadFile' and 'generateContent' methods are deleted.
  // The backend handles the 2-step process now.
}