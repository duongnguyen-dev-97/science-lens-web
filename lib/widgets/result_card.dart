import 'package:flutter/material.dart';

class ResultCard extends StatelessWidget {
  final String text;
  const ResultCard({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SelectableText(text),
      ),
    );
  }
}
