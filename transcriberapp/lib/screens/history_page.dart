import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // Ensure you added intl to pubspec.yaml
import '../models/transcription_record.dart';
import '../services/database_service.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({Key? key}) : super(key: key);

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  // This is the "Promise" of data we are waiting for
  late Future<List<TranscriptionRecord>> _historyList;

  @override
  void initState() {
    super.initState();
    _refreshHistory();
  }

  // Reloads data from the database
  void _refreshHistory() {
    setState(() {
      _historyList = DatabaseService.instance.readAllHistory();
    });
  }

  // Deletes a record and refreshes the UI
  Future<void> _deleteRecord(int id) async {
    await DatabaseService.instance.delete(id);
    _refreshHistory(); // Reload the list to show it's gone
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("History"),
        centerTitle: true,
      ),
      // The "Async UI" Builder
      body: FutureBuilder<List<TranscriptionRecord>>(
        future: _historyList,
        builder: (context, snapshot) {
          // STATE 1: Loading
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // STATE 3: Error
          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }

          // STATE 2: Done (But empty?)
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text("No history yet."));
          }

          // STATE 2: Done (With Data)
          final records = snapshot.data!;
          
          return ListView.builder(
            itemCount: records.length,
            padding: const EdgeInsets.all(12),
            itemBuilder: (context, index) {
              final record = records[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: record.isAccidental 
                        ? Colors.orange.shade100 
                        : Colors.blue.shade100,
                    child: Icon(
                      record.isAccidental 
                          ? Icons.warning_amber_rounded 
                          : Icons.description_rounded,
                      color: record.isAccidental 
                          ? Colors.orange.shade700 
                          : Colors.blue.shade700,
                    ),
                  ),
                  title: Text(
                    record.fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(
                        // Format: "Nov 20, 2025 • 2:30 PM"
                        DateFormat.yMMMd().add_jm().format(record.dateCreated),
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        record.transcription,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _deleteRecord(record.id!),
                  ),
                  // When tapped, show the full text dialog
                  onTap: () => _showFullTranscription(context, record),
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
          child: SelectableText(record.transcription),
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