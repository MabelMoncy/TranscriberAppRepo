import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:record/record.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/app_state.dart';
import '../services/gemini_service.dart';
import '../widgets/initial_view.dart';
import '../widgets/file_shared_view.dart';
import '../widgets/recording_view.dart';
import '../widgets/loading_view.dart';
import '../widgets/success_view.dart';
import '../widgets/error_view.dart';
import 'history_page.dart';
import '../models/transcription_record.dart';
import '../services/database_service.dart';
import '../services/network_helper.dart';
import 'package:path/path.dart' as p;

class AudioTranscriberPage extends StatefulWidget {
  const AudioTranscriberPage({Key? key}) : super(key: key);

  @override
  State<AudioTranscriberPage> createState() => _AudioTranscriberPageState();
}

class _AudioTranscriberPageState extends State<AudioTranscriberPage> {
  GeminiService? _geminiService;

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
    final serverUrl = dotenv.env['SERVER_URL'] ?? 'http://10.0.2.2:8000';
    final apiSecret = dotenv.env['API_SECRET'] ?? '';

    if (serverUrl.isEmpty || apiSecret.isEmpty) {
      setState(() {
        _errorMessage = "Configuration error. Please set up your .env file with SERVER_URL and API_SECRET.";
        _appState = AppState.error;
      });
      return;
    }

    setState(() {
      _geminiService = GeminiService(serverUrl, apiSecret);
    });

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

    // Check internet connectivity
    if (!await NetworkHelper.hasInternetConnection()) {
      setState(() {
        _errorMessage = NetworkHelper.getNetworkErrorMessage();
        _appState = AppState.error;
      });
      return;
    }

    File audioFile = File(_sharedFilePath!);
    String? mimeType = _sharedFileMimeType ?? 'audio/m4a';

    setState(() {
      _appState = AppState.transcribing;
      _statusMessage = "Processing...";
    });

    try {
      final transcribeResponse = await _geminiService!.transcribeAudio(audioFile, mimeType);

      final cleanText = transcribeResponse.trim();
      final lowerText = cleanText.toLowerCase();
      
      if (lowerText.contains("[garbage_audio]") || 
          lowerText.contains("[no audio]") || 
          lowerText.contains("no audio detected") ||
          lowerText.contains("no speech") ||
          lowerText.contains("no clear speech") ||
          lowerText.contains("nothing")) {
        
        setState(() {
          _isAccidentalRecording = true;
          _errorMessage = "⚠️ No Clear Speech Detected\n\nThe audio appears to be empty or just background noise.";
          _appState = AppState.error;
        });
        return;
      }

      // --- DATABASE LOGIC ---
      final originalName = _sharedFilePath!.split('/').last;
      final safeName = "${DateTime.now().millisecondsSinceEpoch}_$originalName";

      // Move shared file to safe storage
      final permanentPath = await _saveAudioPermanently(File(_sharedFilePath!), safeName);

      final record = TranscriptionRecord(
        fileName: originalName,
        filePath: permanentPath,
        transcription: transcribeResponse,
        dateCreated: DateTime.now(),
        isAccidental: false,
      );

      await DatabaseService.instance.create(record);

      setState(() {
        _transcribedText = transcribeResponse;
        _appState = AppState.success;
      });
    } catch (e) {
      setState(() {
        _errorMessage = "Error: ${e.toString()}";
        _appState = AppState.error;
      });
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

    if (_geminiService == null) {
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

  Future<String> _saveAudioPermanently(File tempFile, String fileName) async {
    final appDir = await getApplicationDocumentsDirectory();
    final newPath = p.join(appDir.path, 'recordings', fileName);
    
    final savedFile = File(newPath);
    if (!await savedFile.parent.exists()) {
      await savedFile.parent.create(recursive: true);
    }

    await tempFile.copy(newPath);
    await tempFile.delete(); 

    return newPath;
  }


  Future<void> _stopLiveRecording() async {
    _recordingTimer?.cancel();
    _recordingTimer = null;

    final path = await _audioRecorder.stop();
    
    setState(() {
      _isRecording = false;
      _appState = AppState.liveTranscribing;
      _statusMessage = "Sending audio..."; // Updated status
    });

    if (path != null && await File(path).exists()) {
      // Check internet connectivity
      if (!await NetworkHelper.hasInternetConnection()) {
        setState(() {
          _errorMessage = NetworkHelper.getNetworkErrorMessage();
          _appState = AppState.error;
        });
        return;
      }

      try {
        File audioFile = File(path);
        
        final transcribeResponse = await _geminiService!.transcribeAudio(audioFile, 'audio/m4a');

        final cleanText = transcribeResponse.trim();
        final lowerText = cleanText.toLowerCase();
        
        if (lowerText.contains("[garbage_audio]") || 
            lowerText.contains("[no audio]") || 
            lowerText.contains("no audio detected") ||
            lowerText.contains("no speech") ||
            lowerText.contains("no clear speech")) {
          
          // Delete the junk file so it doesn't clutter storage
          await audioFile.delete(); 

          setState(() {
            _isAccidentalRecording = true;
            _errorMessage = "⚠️ No Clear Speech Detected\n\nYour recording didn't capture any clear voice data.";
            _appState = AppState.error;
          });
          return; 
        }
        // --- DATABASE LOGIC (Kept exactly the same) ---
        final fileName = "recording_${DateTime.now().millisecondsSinceEpoch}.m4a";
        
        // Move file to permanent storage
        final permanentPath = await _saveAudioPermanently(File(path), fileName);
        
        // Save to Database
        final now = DateTime.now();
        final timeStr = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
        final record = TranscriptionRecord(
          fileName: "Voice Note $timeStr",
          filePath: permanentPath, 
          transcription: transcribeResponse, 
          dateCreated: now,
          isAccidental: false,
        );

        await DatabaseService.instance.create(record);

        setState(() {
          _transcribedText = transcribeResponse;
          _appState = AppState.success;
        });
      } catch (e) {
        setState(() {
          // Simplified error handling since the backend handles specific logic
          _errorMessage = "Error: ${e.toString()}";
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
        actions:[
          IconButton(
            icon: const Icon(Icons.history_rounded),
            tooltip: "View history",
            onPressed: (){
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const HistoryPage())
              );
            }
          ),
          const SizedBox(width: 8),
        ]
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
        AppState.initial => InitialView(onStartRecording: _startLiveRecording),
        AppState.fileShared => FileSharedView(
            fileName: _sharedFilePath!.split('/').last,
            onStartTranscription: _startTranscriptionProcess,
          ),
        AppState.uploading || AppState.transcribing || AppState.liveTranscribing => 
          LoadingView(statusMessage: _statusMessage),
        AppState.success => SuccessView(
            transcribedText: _transcribedText,
            onReset: _resetApp,
            onCopy: _copyToClipboard,
          ),
        AppState.error => ErrorView(
            errorMessage: _errorMessage,
            isAccidental: _isAccidentalRecording,
            onRetry: _resetApp,
          ),
        AppState.liveRecording => RecordingView(
            duration: _recordingDuration,
            onStopRecording: _stopLiveRecording,
          ),
      },
    );
  }
}
