// lib/main.dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

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
  // Use the page's own origin (e.g., https://science-lens-api.vercel.app)
  // This avoids CORS and preview-URL problems once UI is hosted on same Vercel project.
  final String _apiBase = Uri.base.origin;
  late final ApiClient api = ApiClient(baseUrl: _apiBase);

  String? _filename;
  String? _imageBase64;
  String? _analysis;
  bool _loading = false;

  final _promptCtrl = TextEditingController(
    text:
        'Identify what this is, explain the science behind it, and suggest a safe mini-experiment to verify.',
  );
  final _followCtrl = TextEditingController();

  // ---- IMAGE UTILITIES ------------------------------------------------------

  // Compress to keep payload well under Vercel's body limit.
  // Downscales longest edge to ~1280px and encodes as JPEG @ quality 75.
  Future<String> _compressToBase64(Uint8List bytes) async {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return base64Encode(bytes);

    final bool widthIsLonger = decoded.width >= decoded.height;
    final resized = img.copyResize(
      decoded,
      width: widthIsLonger ? 1280 : null,
      height: widthIsLonger ? null : 1280,
    );

    final jpg = img.encodeJpg(resized, quality: 75);
    return base64Encode(Uint8List.fromList(jpg));
  }

  // Pick an image and pre-compress it for upload.
  Future<void> _pickFile() async {
    final result =
        await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
    if (result == null || result.files.single.bytes == null) return;

    final file = result.files.single;
    final compressedB64 = await _compressToBase64(file.bytes!);

    setState(() {
      _filename = file.name;
      _imageBase64 = compressedB64;
      _analysis = null;
    });
  }

  // ---- API CALLS ------------------------------------------------------------

  Future<void> _analyze() async {
    if (_imageBase64 == null) return;
    setState(() => _loading = true);
    try {
      final mime = (_filename ?? '').toLowerCase().endsWith('.png')
          ? 'image/png'
          : 'image/jpeg';

      final out = await api.analyzeBase64(
        imageBase64: _imageBase64!,
        mime: mime,
        prompt: _promptCtrl.text,
      );

      setState(() {
        _analysis = out['text'] as String? ?? 'No text returned.';
      });
    } catch (e) {
      setState(() {
        _analysis = 'Error: $e';
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _askFollowUp() async {
    if (_analysis == null || _followCtrl.text.trim().isEmpty) return;
    setState(() => _loading = true);
    try {
      final answer = await api.followUp(
        priorText: _analysis!,
        question: _followCtrl.text.trim(),
      );
      setState(() {
        _analysis =
            '$_analysis\n\n— Follow-up —\nQ: ${_followCtrl.text}\nA: $answer';
        _followCtrl.clear();
      });
    } catch (e) {
      setState(() {
        _analysis = '$_analysis\n\nFollow-up error: $e';
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  // ---- UI -------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final canAnalyze = _imageBase64 != null && !_loading;

    return Scaffold(
      appBar: AppBar(
        title: const Text('ScienceLens (Web)'),
        actions: [
          Tooltip(
            message: 'API: $_apiBase',
            child: const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Icon(Icons.cloud_done_outlined),
            ),
          )
        ],
      ),
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
                if (_filename != null)
                  Expanded(child: Text(_filename!, overflow: TextOverflow.ellipsis)),
              ]),
              const SizedBox(height: 12),
              TextField(
                controller: _promptCtrl,
                decoration: const InputDecoration(
                  labelText: 'Instruction to the AI',
                  border: OutlineInputBorder(),
                ),
                minLines: 1,
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: canAnalyze ? _analyze : null,
                icon: _loading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
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
                        labelText:
                            'Ask a follow-up (e.g., “how to tell calcite from quartz?”)',
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
                ]),
              ],
              const Spacer(),
              const Center(
                child: Text(
                  'Tip: start with a small image; large photos are auto-compressed.',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
