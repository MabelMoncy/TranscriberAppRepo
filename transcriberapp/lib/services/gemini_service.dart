import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

class GeminiService {
  final String apiKey;

  GeminiService(this.apiKey);

  Future<Map<String, dynamic>> uploadFile(File file, String mimeType) async {
    if (apiKey.isEmpty) {
      throw Exception("API key not initialized");
    }

    final uri = Uri.parse(
        "https://generativelanguage.googleapis.com/upload/v1beta/files?key=$apiKey");

    var request = http.MultipartRequest('POST', uri);
    request.headers['X-Goog-Upload-Protocol'] = 'multipart';

    final metadata = {
      "file": {"mimeType": mimeType}
    };

    request.files.add(http.MultipartFile.fromString(
      'metadata',
      jsonEncode(metadata),
      contentType: MediaType.parse('application/json'),
    ));

    request.files.add(await http.MultipartFile.fromPath(
      'file',
      file.path,
      contentType: MediaType.parse(mimeType),
    ));

    final response = await request.send();
    final responseBody = await response.stream.bytesToString();

    if (response.statusCode == 200) {
      final data = jsonDecode(responseBody);
      return {
        "uri": data['file']['uri'],
        "mimeType": data['file']['mimeType'],
      };
    } else {
      throw Exception("Upload failed (${response.statusCode}): $responseBody");
    }
  }

  Future<String> generateContent(String fileUri, String mimeType) async {
    if (apiKey.isEmpty) {
      throw Exception("API key not initialized");
    }

    final uri = Uri.parse(
        "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$apiKey");

    final prompt = """Transcribe this audio file word to word exactly accurately with proper punctuation and formatting.

IMPORTANT INSTRUCTIONS:
1. If the audio contains clear, intentional speech: Transcribe it word-for-word with correct spacing, punctuation, and paragraph breaks.

2. If the audio is an ACCIDENTAL RECORDING (pocket dial, background noise only, fumbling sounds, muffled unclear sounds, no intelligible speech), respond with ONLY this exact text:
[GARBAGE_AUDIO]

3. If the audio is mostly silent or has very brief unclear sounds, also respond with:
[GARBAGE_AUDIO]

Analyze the audio carefully and choose the appropriate response.""";

    final body = jsonEncode({
      "contents": [
        {
          "parts": [
            {
              "fileData": {"mimeType": mimeType, "fileUri": fileUri}
            },
            {"text": prompt}
          ]
        }
      ],
      "generationConfig": {
        "temperature": 0.1,
        "topK": 20,
        "topP": 0.8,
      }
    });

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: body,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['candidates'] == null || data['candidates'].isEmpty) {
        throw Exception("No transcription generated");
      }

      final transcribedText =
          data['candidates'][0]['content']['parts'][0]['text'];

      // Check for garbage audio flag
      if (transcribedText.trim() == "[GARBAGE_AUDIO]" || 
          transcribedText.trim().contains("[GARBAGE_AUDIO]")) {
        throw Exception("[GARBAGE_AUDIO]");
      }

      return transcribedText;
    } else {
      final errorData = jsonDecode(response.body);
      final errorMsg = errorData['error']?['message'] ?? response.body;
      
      // Check for blocked content
      if (errorMsg.toString().contains("SAFETY") || 
          errorMsg.toString().contains("blocked")) {
        throw Exception("[BLOCKED]");
      }
      
      throw Exception("Transcription error: $errorMsg");
    }
  }
}
