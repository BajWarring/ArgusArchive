import 'dart:io';
import 'package:flutter/material.dart';

class CodeEditor extends StatefulWidget {
  final String path;
  const CodeEditor({super.key, required this.path});

  @override
  State<CodeEditor> createState() => _CodeEditorState();
}

class _CodeEditorState extends State<CodeEditor> {
  late TextEditingController _controller;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    final content = File(widget.path).readAsStringSync();
    _controller = TextEditingController(text: content);
    _controller.addListener(() => setState(() => _dirty = true));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await File(widget.path).writeAsString(_controller.text);
    if (mounted) setState(() => _dirty = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.path.split('/').last),
        actions: [
          if (_dirty)
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _save,
            ),
        ],
      ),
      body: TextField(
        controller: _controller,
        maxLines: null,
        expands: true,
        style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
        decoration: const InputDecoration(
          contentPadding: EdgeInsets.all(12),
          border: InputBorder.none,
        ),
      ),
    );
  }
}
