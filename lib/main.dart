import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'services/api_client.dart';
import 'widgets/result_card.dart';

void main() => runApp(const ScienceLensApp());

class ScienceLensApp extends StatelessWidget {
  const ScienceLensApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ScienceLens',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.teal),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // This gets injected by GitHub Actions at build time via --dart-define
  static const apiBase = String.fromEnvironment('API_BASE', defaultValue: '');
  final api = ApiClient(baseUrl: apiBase);

  String? _filename;
  String? _imageBase64;
  String? _analysis;
  bool _loading = false;

  final _promptCtrl = TextEditingController(text:
      'Identify what this is, explain the science behind it, and suggest a safe mini-experiment to verify.');
  final _followCtrl = TextEditingController();

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
    if (result != null && result.files.single.bytes != null) {
      final file = result.files.single;
      setState(() {
        _filename = file.name;
        _imageBase64 = base64Encode(file.bytes!);
        _analysis = null;
      });
    }
  }

  Future<void> _analyze() async {
    if (_imageBase64 == null || apiBase.isEmpty) return;
    setState(() => _loading = true);
    try {
      final out = await api.analyzeBase64(
        imageBase64: _imageBase64!,
        mime: _filename != null && _filename!.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg',
        prompt: _promptCtrl.text,
      );
      setState(() => _analysis = out['text'] as String? ?? 'No text returned.');
    } catch (e) {
      setState(() => _analysis = 'Error: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _askFollowUp() async {
    if (_analysis == null || _followCtrl.text.trim().isEmpty) return;
    setState(() => _loading = true);
    try {
      final answer = await api.followUp(priorText: _analysis!, question: _followCtrl.text.trim());
      setState(() => _analysis = '$_analysis\n\n— Follow-up —\nQ: ${_followCtrl.text}\nA: $answer');
      _followCtrl.clear();
    } catch (e) {
      setState(() => _analysis = '$_analysis\n\nFollow-up error: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canAnalyze = _imageBase64 != null && !_loading;
    return Scaffold(
      appBar: AppBar(title: const Text('ScienceLens (Web)')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                ElevatedButton.icon(
                  onPressed: _pickFile,
                  icon: const Icon(Icons.add_a_photo_outlined),
                  label: const Text('Choose Image'),
                ),
                const SizedBox(width: 12),
                if (_filename != null) Expanded(child: Text(_filename!, overflow: TextOverflow.ellipsis))
              ]),
              const SizedBox(height: 12),
              TextField(
                controller: _promptCtrl,
                decoration: const InputDecoration(
                  labelText: 'Instruction to the AI',
                  border: OutlineInputBorder(),
                ),
                minLines: 1, maxLines: 3,
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: canAnalyze ? _analyze : null,
                icon: _loading
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.science_outlined),
                label: const Text('Analyze'),
              ),
              if (_analysis != null) ...[
                const SizedBox(height: 12),
                ResultCard(text: _analysis!),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _followCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Ask a follow-up (e.g., “how to tell calcite from quartz?”)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: !_loading ? _askFollowUp : null,
                    icon: const Icon(Icons.question_answer_outlined),
                    label: const Text('Ask'),
                  )
                ])
              ]
            ]),
          ),
        ),
      ),
    );
  }
}
