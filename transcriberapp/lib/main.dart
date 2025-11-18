import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    print("Warning: .env file not found. Please add your API key.");
  }
  runApp(const MyApp());
}

enum AppState {
  initial,
  fileShared,
  uploading,
  transcribing,
  success,
  error,
  liveRecording,
  liveTranscribing
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Audio Transcriber',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E88E5),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F7FA),
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0),
            side: BorderSide(color: Colors.grey.shade200, width: 1),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 32),
            textStyle: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16.0),
            ),
          ),
        ),
      ),
      home: const AudioTranscriberPage(),
    );
  }
}

class AudioTranscriberPage extends StatefulWidget {
  const AudioTranscriberPage({Key? key}) : super(key: key);

  @override
  State<AudioTranscriberPage> createState() => _AudioTranscriberPageState();
}

class _AudioTranscriberPageState extends State<AudioTranscriberPage> {
  String? _geminiApiKey;

  AppState _appState = AppState.initial;
  String? _sharedFilePath;
  String? _sharedFileMimeType;
  String? _transcribedText;
  String? _errorMessage;
  String _statusMessage = "";
  bool _isAccidentalRecording = false;

  // Live recording variables
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  String? _recordingPath;
  Timer? _recordingTimer;
  int _recordingDuration = 0;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Load API key safely
    try {
      await dotenv.load(fileName: ".env");
      _geminiApiKey = dotenv.env['GEMINI_API_KEY'];
      
      if (_geminiApiKey == null || _geminiApiKey!.isEmpty) {
        setState(() {
          _errorMessage = "API key not found. Please add GEMINI_API_KEY to your .env file";
          _appState = AppState.error;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Failed to load configuration: ${e.toString()}";
        _appState = AppState.error;
      });
    }

    _initSharingListener();
  }

  void _initSharingListener() {
    ReceiveSharingIntent.instance
        .getMediaStream()
        .listen((List<SharedMediaFile> value) {
      if (value.isNotEmpty) {
        _handleNewFile(value.first.path, value.first.mimeType);
      }
    });

    ReceiveSharingIntent.instance
        .getInitialMedia()
        .then((List<SharedMediaFile> value) {
      if (value.isNotEmpty) {
        _handleNewFile(value.first.path, value.first.mimeType);
      }
    });
  }

  void _handleNewFile(String path, String? mimeType) {
    setState(() {
      _sharedFilePath = path;
      _sharedFileMimeType = mimeType;
      _appState = AppState.fileShared;
      _transcribedText = null;
      _errorMessage = null;
      _statusMessage = "";
      _isAccidentalRecording = false;
    });
  }

  Future<void> _startTranscriptionProcess() async {
    if (_sharedFilePath == null) return;

    if (_geminiApiKey == null || _geminiApiKey!.isEmpty) {
      setState(() {
        _errorMessage = "Please add your Gemini API key to the .env file";
        _appState = AppState.error;
      });
      return;
    }

    File audioFile = File(_sharedFilePath!);
    String? mimeType = _sharedFileMimeType;

    if (mimeType == null || !mimeType.startsWith('audio/')) {
      setState(() {
        _errorMessage = "Invalid file type. Please share an audio file.";
        _appState = AppState.error;
      });
      return;
    }

    setState(() {
      _appState = AppState.uploading;
      _statusMessage = "Uploading your audio file...";
    });

    try {
      final uploadResponse = await _uploadFile(audioFile, mimeType);

      setState(() {
        _appState = AppState.transcribing;
        _statusMessage = "Transcribing your audio...";
      });

      final transcribeResponse = await _generateContent(
        uploadResponse['uri'],
        uploadResponse['mimeType'],
      );

      setState(() {
        _transcribedText = transcribeResponse;
        _appState = AppState.success;
      });
    } catch (e) {
      setState(() {
        if (e.toString().contains("GARBAGE_AUDIO")) {
          _isAccidentalRecording = true;
          _errorMessage = "⚠️ Accidental Voice Message Detected\n\nThis appears to be an accidental recording with no clear speech. The sender may have recorded this by mistake.";
        } else if (e.toString().contains("BLOCKED")) {
          _errorMessage = "Unable to transcribe: The audio content was blocked by safety filters.";
        } else {
          _errorMessage = "Error: ${e.toString()}";
        }
        _appState = AppState.error;
      });
    }
  }

  Future<Map<String, dynamic>> _uploadFile(File file, String mimeType) async {
    if (_geminiApiKey == null || _geminiApiKey!.isEmpty) {
      throw Exception("API key not initialized");
    }

    final uri = Uri.parse(
        "https://generativelanguage.googleapis.com/upload/v1beta/files?key=$_geminiApiKey");

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

  Future<String> _generateContent(String fileUri, String mimeType) async {
    if (_geminiApiKey == null || _geminiApiKey!.isEmpty) {
      throw Exception("API key not initialized");
    }

    final uri = Uri.parse(
        "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$_geminiApiKey");

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

  // Live Recording Functions
  Future<void> _startLiveRecording() async {
    // Request microphone permission
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      setState(() {
        _errorMessage = "Microphone permission is required for live recording";
        _appState = AppState.error;
      });
      return;
    }

    if (_geminiApiKey == null || _geminiApiKey!.isEmpty) {
      setState(() {
        _errorMessage = "Please add your Gemini API key to the .env file";
        _appState = AppState.error;
      });
      return;
    }

    try {
      final directory = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      _recordingPath = '${directory.path}/recording_$timestamp.m4a';

      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: _recordingPath!,
      );

      setState(() {
        _isRecording = true;
        _appState = AppState.liveRecording;
        _recordingDuration = 0;
      });

      // Start timer
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() {
          _recordingDuration++;
        });
      });
    } catch (e) {
      setState(() {
        _errorMessage = "Failed to start recording: ${e.toString()}";
        _appState = AppState.error;
      });
    }
  }

  Future<void> _stopLiveRecording() async {
    _recordingTimer?.cancel();
    _recordingTimer = null;

    final path = await _audioRecorder.stop();
    
    setState(() {
      _isRecording = false;
      _appState = AppState.liveTranscribing;
      _statusMessage = "Processing your recording...";
    });

    if (path != null && await File(path).exists()) {
      try {
        File audioFile = File(path);
        
        setState(() {
          _statusMessage = "Uploading...";
        });

        final uploadResponse = await _uploadFile(audioFile, 'audio/m4a');

        setState(() {
          _statusMessage = "Transcribing...";
        });

        final transcribeResponse = await _generateContent(
          uploadResponse['uri'],
          uploadResponse['mimeType'],
        );

        setState(() {
          _transcribedText = transcribeResponse;
          _appState = AppState.success;
        });

        // Clean up temporary file
        await audioFile.delete();
      } catch (e) {
        setState(() {
          if (e.toString().contains("GARBAGE_AUDIO")) {
            _isAccidentalRecording = true;
            _errorMessage = "⚠️ No Clear Speech Detected\n\nYour recording doesn't contain clear speech. Please try recording again in a quieter environment.";
          } else {
            _errorMessage = "Error: ${e.toString()}";
          }
          _appState = AppState.error;
        });
      }
    }
  }

  void _copyToClipboard() {
    if (_transcribedText != null && _transcribedText!.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: _transcribedText!));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white, size: 20),
              SizedBox(width: 12),
              Text("Copied to clipboard!", style: TextStyle(fontSize: 16)),
            ],
          ),
          backgroundColor: Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  void _resetApp() {
    setState(() {
      _appState = AppState.initial;
      _sharedFilePath = null;
      _sharedFileMimeType = null;
      _transcribedText = null;
      _errorMessage = null;
      _statusMessage = "";
      _isAccidentalRecording = false;
      _recordingDuration = 0;
    });
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _audioRecorder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Audio Transcriber',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: isTablet ? 24 : 22,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxWidth = constraints.maxWidth > 700 ? 700.0 : constraints.maxWidth;
            final horizontalPadding = constraints.maxWidth > 600 ? 32.0 : 20.0;

            return Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                  vertical: 24.0,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: _buildStatusUI(context),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildStatusUI(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      switchInCurve: Curves.easeInOut,
      switchOutCurve: Curves.easeInOut,
      child: switch (_appState) {
        AppState.initial => _buildInitialUI(context),
        AppState.fileShared => _buildFileSharedUI(context),
        AppState.uploading || AppState.transcribing || AppState.liveTranscribing => _buildLoadingUI(context),
        AppState.success => _buildSuccessUI(context),
        AppState.error => _buildErrorUI(context),
        AppState.liveRecording => _buildLiveRecordingUI(context),
      },
    );
  }

  Widget _buildInitialUI(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;

    return Card(
      key: const ValueKey('initial'),
      color: Colors.white,
      child: Padding(
        padding: EdgeInsets.symmetric(
          vertical: isSmallScreen ? 48.0 : 64.0,
          horizontal: isSmallScreen ? 20.0 : 32.0,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(isSmallScreen ? 20 : 28),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.mic_rounded,
                size: isSmallScreen ? 56 : 72,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            SizedBox(height: isSmallScreen ? 24 : 32),
            Text(
              "Ready to Transcribe",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: isSmallScreen ? 24 : 28,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              "Share an audio file or record live to get started",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: isSmallScreen ? 16 : 18,
                color: Colors.grey.shade600,
                height: 1.4,
              ),
            ),
            SizedBox(height: isSmallScreen ? 32 : 40),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _startLiveRecording,
                icon: const Icon(Icons.mic, size: 24),
                label: Text(
                  "Start Live Recording",
                  style: TextStyle(fontSize: isSmallScreen ? 16 : 18),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  minimumSize: Size(double.infinity, isSmallScreen ? 56 : 64),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileSharedUI(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;

    return Column(
      key: const ValueKey('fileShared'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          color: Colors.white,
          child: Padding(
            padding: EdgeInsets.all(isSmallScreen ? 16.0 : 20.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.all(isSmallScreen ? 10 : 14),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.audio_file_rounded,
                    color: Colors.green.shade600,
                    size: isSmallScreen ? 28 : 36,
                  ),
                ),
                const SizedBox(width: 16),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _sharedFilePath!.split('/').last,
                        style: TextStyle(
                          fontSize: isSmallScreen ? 16 : 18,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "Ready to transcribe",
                        style: TextStyle(
                          fontSize: isSmallScreen ? 14 : 16,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: _startTranscriptionProcess,
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Colors.white,
            minimumSize: Size(double.infinity, isSmallScreen ? 56 : 64),
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.transcribe_rounded, size: 24),
              const SizedBox(width: 12),
              Text(
                "Start Transcription",
                style: TextStyle(fontSize: isSmallScreen ? 16 : 18),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLiveRecordingUI(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;

    return Card(
      key: const ValueKey('liveRecording'),
      color: Colors.red.shade50,
      child: Padding(
        padding: EdgeInsets.symmetric(
          vertical: isSmallScreen ? 48.0 : 60.0,
          horizontal: isSmallScreen ? 20.0 : 32.0,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: isSmallScreen ? 100 : 120,
                  height: isSmallScreen ? 100 : 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.red.shade100,
                  ),
                ),
                Icon(
                  Icons.mic,
                  size: isSmallScreen ? 48 : 56,
                  color: Colors.red.shade700,
                ),
                Positioned(
                  top: isSmallScreen ? 8 : 10,
                  right: isSmallScreen ? 8 : 10,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: isSmallScreen ? 24 : 32),
            Text(
              "Recording...",
              style: TextStyle(
                fontSize: isSmallScreen ? 24 : 28,
                fontWeight: FontWeight.bold,
                color: Colors.red.shade900,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _formatDuration(_recordingDuration),
              style: TextStyle(
                fontSize: isSmallScreen ? 32 : 40,
                fontWeight: FontWeight.w300,
                color: Colors.red.shade800,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            SizedBox(height: isSmallScreen ? 32 : 40),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _stopLiveRecording,
                icon: const Icon(Icons.stop, size: 24),
                label: Text(
                  "Stop & Transcribe",
                  style: TextStyle(fontSize: isSmallScreen ? 16 : 18),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade700,
                  foregroundColor: Colors.white,
                  minimumSize: Size(double.infinity, isSmallScreen ? 56 : 64),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingUI(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;

    return Card(
      key: const ValueKey('loading'),
      color: Colors.white,
      child: Padding(
        padding: EdgeInsets.symmetric(
          vertical: isSmallScreen ? 48.0 : 60.0,
          horizontal: isSmallScreen ? 20.0 : 32.0,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: isSmallScreen ? 56 : 72,
              height: isSmallScreen ? 56 : 72,
              child: CircularProgressIndicator(
                strokeWidth: 6,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            SizedBox(height: isSmallScreen ? 24 : 32),
            Text(
              _statusMessage,
              style: TextStyle(
                fontSize: isSmallScreen ? 18 : 22,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              "This may take a few moments",
              style: TextStyle(
                fontSize: isSmallScreen ? 14 : 16,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessUI(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;

    return Column(
      key: const ValueKey('success'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          color: Colors.white,
          child: Padding(
            padding: EdgeInsets.all(isSmallScreen ? 20.0 : 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: EdgeInsets.all(isSmallScreen ? 8 : 10),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.check_circle,
                        color: Colors.green.shade600,
                        size: isSmallScreen ? 24 : 28,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "Transcription Complete",
                        style: TextStyle(
                          fontSize: isSmallScreen ? 20 : 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy_rounded),
                      tooltip: "Copy to clipboard",
                      onPressed: _copyToClipboard,
                      iconSize: isSmallScreen ? 22 : 24,
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.grey.shade100,
                        padding: const EdgeInsets.all(12),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: isSmallScreen ? 16 : 20),
                Container(
                  padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: SelectableText(
                    _transcribedText ?? "No text found.",
                    style: TextStyle(
                      fontSize: isSmallScreen ? 16 : 18,
                      height: 1.6,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: isSmallScreen ? 16 : 20),
        OutlinedButton.icon(
          onPressed: _resetApp,
          icon: const Icon(Icons.refresh_rounded, size: 24),
          label: Text(
            "Transcribe Another",
            style: TextStyle(fontSize: isSmallScreen ? 16 : 18),
          ),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            side: BorderSide(color: Colors.grey.shade300, width: 1.5),
            minimumSize: Size(double.infinity, isSmallScreen ? 56 : 64),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorUI(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    final isAccidental = _isAccidentalRecording;

    return Column(
      key: const ValueKey('error'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          color: isAccidental ? Colors.orange.shade50 : Colors.red.shade50,
          child: Padding(
            padding: EdgeInsets.all(isSmallScreen ? 20.0 : 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: EdgeInsets.all(isSmallScreen ? 8 : 10),
                      decoration: BoxDecoration(
                        color: isAccidental 
                            ? Colors.orange.shade100 
                            : Colors.red.shade100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        isAccidental 
                            ? Icons.warning_amber_rounded 
                            : Icons.error_outline_rounded,
                        color: isAccidental 
                            ? Colors.orange.shade700 
                            : Colors.red.shade700,
                        size: isSmallScreen ? 24 : 28,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        isAccidental 
                            ? "Accidental Recording" 
                            : "Error Occurred",
                        style: TextStyle(
                          fontSize: isSmallScreen ? 20 : 24,
                          fontWeight: FontWeight.bold,
                          color: isAccidental 
                              ? Colors.orange.shade900 
                              : Colors.red.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: isSmallScreen ? 16 : 20),
                Container(
                  padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: SelectableText(
                    _errorMessage ?? "An unknown error occurred.",
                    style: TextStyle(
                      fontSize: isSmallScreen ? 15 : 17,
                      height: 1.6,
                      color: isAccidental 
                          ? Colors.orange.shade900 
                          : Colors.red.shade800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: isSmallScreen ? 16 : 20),
        ElevatedButton.icon(
          onPressed: _resetApp,
          icon: const Icon(Icons.refresh_rounded, size: 24),
          label: Text(
            "Try Again",
            style: TextStyle(fontSize: isSmallScreen ? 16 : 18),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Colors.white,
            minimumSize: Size(double.infinity, isSmallScreen ? 56 : 64),
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      ],
    );
  }
}