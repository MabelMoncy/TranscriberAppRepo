import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:io';
import '../models/transcription_record.dart';
import '../services/database_service.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({Key? key}) : super(key: key);

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  late Future<List<TranscriptionRecord>> _historyList;
  
  // --- AUDIO PLAYER STATE ---
  final AudioPlayer _audioPlayer = AudioPlayer();
  int? _playingIndex; 
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _refreshHistory();
    
    _audioPlayer.onPlayerComplete.listen((event) {
      setState(() {
        _playingIndex = null;
        _isPlaying = false;
      });
    });
  }

  @override
  void dispose() {
    _audioPlayer.stop();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _refreshHistory() {
    setState(() {
      _historyList = DatabaseService.instance.readAllHistory();
    });
  }

  Future<void> _toggleAudio(String filePath, int index) async {
    try {
      // Check if file exists before playing
      if (!await File(filePath).exists()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Audio file not found. It may have been deleted.")),
          );
        }
        return;
      }

      if (_playingIndex == index && _isPlaying) {
        await _audioPlayer.pause();
        setState(() => _isPlaying = false);
      } else {
        await _audioPlayer.stop(); 
        await _audioPlayer.play(DeviceFileSource(filePath));
        setState(() {
          _playingIndex = index;
          _isPlaying = true;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error playing audio: $e")),
        );
      }
    }
  }

  Future<void> _deleteRecord(int id, String filePath, int index) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Recording'),
        content: const Text('Are you sure you want to delete this recording? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // --- 1. AUDIO CLEANUP LOGIC ---
    if (_playingIndex == index) {
      await _audioPlayer.stop();
      setState(() {
        _playingIndex = null;
        _isPlaying = false;
      });
    } else if (_playingIndex != null && _playingIndex! > index) {
      setState(() {
        _playingIndex = _playingIndex! - 1;
      });
    }

    // --- 2. DELETE FILES ---
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      // Silent fail - file might already be deleted
    }

    // --- 3. DELETE FROM DB ---
    await DatabaseService.instance.delete(id);
    
    // --- 4. REFRESH UI ---
    _refreshHistory();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("History"),
        centerTitle: true,
      ),
      body: FutureBuilder<List<TranscriptionRecord>>(
        future: _historyList,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text("No history yet."));
          }

          final records = snapshot.data!;
          
          return ListView.builder(
            itemCount: records.length,
            padding: const EdgeInsets.all(12),
            itemBuilder: (context, index) {
              final record = records[index];
              final isThisPlaying = _playingIndex == index && _isPlaying;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Column(
                  children: [
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: CircleAvatar(
                        backgroundColor: record.isAccidental 
                            ? Colors.orange.shade100 
                            : Colors.blue.shade100,
                        child: IconButton(
                          icon: Icon(isThisPlaying ? Icons.pause : Icons.play_arrow),
                          color: record.isAccidental 
                              ? Colors.orange.shade700 
                              : Colors.blue.shade700,
                          onPressed: () => _toggleAudio(record.filePath, index),
                        ),
                      ),
                      title: Text(
                        record.fileName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      // --- UPDATED SUBTITLE WITH TEXT PREVIEW ---
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          // 1. The Date
                          Text(
                            DateFormat.yMMMd().add_jm().format(record.dateCreated),
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                          const SizedBox(height: 6),
                          // 2. The Text Preview (Restored!)
                          Text(
                            record.transcription,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14, 
                              color: Colors.black87,
                              height: 1.3
                            ),
                          ),
                        ],
                      ),
                      // ------------------------------------------
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: record.id == null 
                            ? null 
                            : () => _deleteRecord(record.id!, record.filePath, index),
                      ),
                      onTap: () => _showFullTranscription(context, record),
                    ),
                    if (isThisPlaying)
                      LinearProgressIndicator(
                        minHeight: 2,
                        backgroundColor: Colors.transparent,
                        color: Colors.blue.shade400,
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showFullTranscription(BuildContext context, TranscriptionRecord record) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(record.fileName),
        content: SingleChildScrollView(
          child: SelectableText(
            record.transcription,
            style: const TextStyle(fontSize: 16, height: 1.5),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }
}