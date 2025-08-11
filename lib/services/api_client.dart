import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiClient {
  final String baseUrl;
  ApiClient({required this.baseUrl});

  Future<Map<String, dynamic>> analyzeBase64({
    required String imageBase64,
    String mime = 'image/jpeg',
    String prompt = 'Explain this scientifically for a curious learner.'
  }) async {
    final uri = Uri.parse('$baseUrl/api/analyze');
    final r = await http.post(uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'imageBase64': imageBase64, 'mime': mime, 'prompt': prompt}));
    if (r.statusCode != 200) {
      throw Exception('Analyze failed: ${r.statusCode} ${r.body}');
    }
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  Future<String> followUp({required String priorText, required String question}) async {
    final uri = Uri.parse('$baseUrl/api/followup');
    final r = await http.post(uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'priorText': priorText, 'question': question}));
    if (r.statusCode != 200) {
      throw Exception('Follow-up failed: ${r.statusCode} ${r.body}');
    }
    final data = jsonDecode(r.body) as Map<String, dynamic>;
    return data['text'] as String;
  }
}
