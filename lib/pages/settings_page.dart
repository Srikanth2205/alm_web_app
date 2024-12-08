import 'package:flutter/material.dart';
import '../services/logger_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _isDebugEnabled = LoggerService.isDebugEnabled;
  List<String> _logContents = [];

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    final logs = await LoggerService.getLogContents();
    setState(() {
      _logContents = logs;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Debug Mode'),
                Switch(
                  value: _isDebugEnabled,
                  onChanged: (value) async {
                    await LoggerService.setDebugEnabled(value);
                    setState(() {
                      _isDebugEnabled = value;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Logs'),
                ElevatedButton(
                  onPressed: () async {
                    await LoggerService.clearLogs();
                    _loadLogs();
                  },
                  child: const Text('Clear Logs'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                itemCount: _logContents.length,
                itemBuilder: (context, index) {
                  return Card(
                    child: ListTile(
                      title: Text(_logContents[index]),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
} 