import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../core/models/file_entry.dart';
import '../../core/interfaces/storage_adapter.dart';
import '../../core/utils/path_utils.dart';
import 'file_handler.dart';

class TextHandler implements FileHandler {
  static const List<String> _exts = [
    'txt','json','html','xml','csv','dart','md','jsx','js','ts','tsx',
    'py','java','kt','c','cpp','h','css','yaml','yml','toml','ini',
    'cfg','log','sh','bat','sql','php','rb','go','rs','swift','vue','mjs',
  ];

  @override
  bool canHandle(FileEntry entry) =>
      _exts.contains(PathUtils.getExtension(entry.path));

  @override
  Widget buildPreview(FileEntry entry, StorageAdapter adapter) =>
      const Icon(Icons.article, color: Colors.blueGrey);

  @override
  Future<void> open(BuildContext context, FileEntry entry, StorageAdapter adapter) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final stream = await adapter.openRead(entry.path);
      final bb = BytesBuilder();
      await for (final chunk in stream) { bb.add(chunk); }
      final content = utf8.decode(bb.takeBytes(), allowMalformed: true);
      if (context.mounted) Navigator.of(context).pop();
      if (context.mounted) {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => _TextViewerScreen(
            initialContent: content, entry: entry, adapter: adapter,
          ),
        ));
      }
    } catch (e) {
      if (context.mounted) Navigator.of(context).pop();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to open: $e')),
        );
      }
    }
  }
}

// ─── Match: line + column range ───────────────────────────────────────────────
class _Match {
  final int line, start, end;
  const _Match(this.line, this.start, this.end);
}

// ─── Viewer screen ────────────────────────────────────────────────────────────
class _TextViewerScreen extends StatefulWidget {
  final String initialContent;
  final FileEntry entry;
  final StorageAdapter adapter;
  const _TextViewerScreen({
    required this.initialContent,
    required this.entry,
    required this.adapter,
  });
  @override
  State<_TextViewerScreen> createState() => _TextViewerScreenState();
}

class _TextViewerScreenState extends State<_TextViewerScreen> {
  // ── Content ──────────────────────────────────────────────────────────────
  late String _saved;
  late List<String> _viewLines;

  // ── Edit mode ────────────────────────────────────────────────────────────
  bool _isEditing = false;
  bool _isDirty   = false;
  late TextEditingController _editCtrl;

  // ── Font size ────────────────────────────────────────────────────────────
  double _fontSize = 13.5;

  // ── Search ───────────────────────────────────────────────────────────────
  bool _showSearch = false;
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  String _searchQuery = '';
  List<_Match> _matches = [];
  Map<int, List<int>> _lineMatchMap = {}; // line -> [global match indices]
  int _matchIdx = 0;

  // ── Scroll (read view) ───────────────────────────────────────────────────
  final ScrollController _readScroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _saved = widget.initialContent;
    _viewLines = _saved.split('\n');
    _editCtrl = TextEditingController(text: _saved);
  }

  @override
  void dispose() {
    _editCtrl.dispose();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    _readScroll.dispose();
    super.dispose();
  }

  // ── Search helpers ────────────────────────────────────────────────────────
  void _runSearch(String query) {
    _searchQuery = query;
    if (query.isEmpty) {
      setState(() { _matches = []; _lineMatchMap = {}; _matchIdx = 0; });
      return;
    }
    final source = _isEditing ? _editCtrl.text : _saved;
    final lines  = source.split('\n');
    final lq     = query.toLowerCase();
    final found  = <_Match>[];
    final lmap   = <int, List<int>>{};

    for (int li = 0; li < lines.length; li++) {
      final lower = lines[li].toLowerCase();
      int pos = 0;
      while (true) {
        final idx = lower.indexOf(lq, pos);
        if (idx == -1) break;
        final globalIdx = found.length;
        found.add(_Match(li, idx, idx + query.length));
        lmap.putIfAbsent(li, () => []).add(globalIdx);
        pos = idx + 1;
      }
    }
    setState(() {
      _matches = found;
      _lineMatchMap = lmap;
      _matchIdx = 0;
    });
    if (found.isNotEmpty) _scrollToMatch(0);
  }

  void _nextMatch() {
    if (_matches.isEmpty) return;
    final n = (_matchIdx + 1) % _matches.length;
    setState(() => _matchIdx = n);
    _scrollToMatch(n);
    if (_isEditing) _selectInEditor(_matches[n]);
  }

  void _prevMatch() {
    if (_matches.isEmpty) return;
    final n = (_matchIdx - 1 + _matches.length) % _matches.length;
    setState(() => _matchIdx = n);
    _scrollToMatch(n);
    if (_isEditing) _selectInEditor(_matches[n]);
  }

  void _scrollToMatch(int idx) {
    if (_matches.isEmpty || idx >= _matches.length) return;
    if (!_readScroll.hasClients) return;
    final lineIdx    = _matches[idx].line;
    final approxH    = _fontSize * 1.48;
    final target     = (lineIdx * approxH).clamp(0.0, _readScroll.position.maxScrollExtent);
    _readScroll.animateTo(target, duration: const Duration(milliseconds: 180), curve: Curves.easeOut);
  }

  void _selectInEditor(_Match m) {
    final lines = _editCtrl.text.split('\n');
    int offset = 0;
    for (int i = 0; i < m.line && i < lines.length; i++) {
      offset += lines[i].length + 1;
    }
    _editCtrl.selection = TextSelection(
      baseOffset:   offset + m.start,
      extentOffset: offset + m.end,
    );
  }

  // ── Edit / Save ───────────────────────────────────────────────────────────
  void _toggleEdit() {
    if (_isEditing && _isDirty) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Discard changes?'),
          content: const Text('You have unsaved changes. Discard them?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Keep editing')),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () { Navigator.pop(ctx); _exitEdit(discard: true); },
              child: const Text('Discard'),
            ),
          ],
        ),
      );
    } else if (_isEditing) {
      _exitEdit();
    } else {
      setState(() {
        _isEditing = true;
        _editCtrl.text = _saved;
        _isDirty = false;
        if (_searchQuery.isNotEmpty) _runSearch(_searchQuery);
      });
    }
  }

  void _exitEdit({bool discard = false}) {
    setState(() {
      if (discard) _editCtrl.text = _saved;
      _isEditing = false;
      _isDirty   = false;
      _viewLines = _saved.split('\n');
      if (_searchQuery.isNotEmpty) _runSearch(_searchQuery);
    });
  }

  Future<void> _saveFile() async {
    try {
      final newContent = _editCtrl.text;
      final sink = await widget.adapter.openWrite(widget.entry.path);
      sink.add(utf8.encode(newContent));
      await sink.close();
      setState(() {
        _saved     = newContent;
        _viewLines = newContent.split('\n');
        _isDirty   = false;
        _isEditing = false;
        if (_searchQuery.isNotEmpty) _runSearch(_searchQuery);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('File saved'),
            backgroundColor: Colors.teal,
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF12121E),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          if (_showSearch) _buildSearchBar(),
          Expanded(child: _isEditing ? _buildEditView() : _buildReadView()),
        ],
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF1E1E2E),
      elevation: 0,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(PathUtils.getName(widget.entry.path),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          if (_isDirty)
            const Text('unsaved changes',
                style: TextStyle(fontSize: 10, color: Colors.orangeAccent)),
        ],
      ),
      actions: [
        // Font size ─────────────────────────────────────
        IconButton(
          icon: const Icon(Icons.remove, size: 18),
          tooltip: 'Smaller font',
          onPressed: () => setState(() => _fontSize = (_fontSize - 1.0).clamp(8.0, 32.0)),
        ),
        Text('${_fontSize.toInt()}',
            style: const TextStyle(fontSize: 12, color: Colors.grey)),
        IconButton(
          icon: const Icon(Icons.add, size: 18),
          tooltip: 'Larger font',
          onPressed: () => setState(() => _fontSize = (_fontSize + 1.0).clamp(8.0, 32.0)),
        ),
        // Search toggle ────────────────────────────────
        IconButton(
          icon: Icon(_showSearch ? Icons.search_off : Icons.search),
          tooltip: _showSearch ? 'Hide search' : 'Find in file',
          onPressed: () {
            setState(() {
              _showSearch = !_showSearch;
              if (!_showSearch) {
                _searchCtrl.clear();
                _searchQuery = '';
                _matches = [];
                _lineMatchMap = {};
              } else {
                WidgetsBinding.instance.addPostFrameCallback(
                    (_) => _searchFocus.requestFocus());
              }
            });
          },
        ),
        // Edit / Save / Cancel ─────────────────────────
        if (_isEditing) ...[
          IconButton(
            icon: const Icon(Icons.save_outlined, color: Colors.tealAccent),
            tooltip: 'Save',
            onPressed: _saveFile,
          ),
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Cancel',
            onPressed: _toggleEdit,
          ),
        ] else
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit',
            onPressed: _toggleEdit,
          ),
      ],
    );
  }

  // ── ZArchiver-style search bar ────────────────────────────────────────────
  Widget _buildSearchBar() {
    final total      = _matches.length;
    final hasQ       = _searchCtrl.text.isNotEmpty;
    final display    = hasQ ? (total == 0 ? '0/0' : '${_matchIdx + 1}/$total') : '';

    return Container(
      color: const Color(0xFF252538),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      child: Row(
        children: [
          const Icon(Icons.search, color: Colors.grey, size: 18),
          const SizedBox(width: 4),
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              focusNode: _searchFocus,
              style: const TextStyle(fontSize: 14, color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Find in file…',
                hintStyle: TextStyle(color: Colors.grey, fontSize: 13),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 8),
              ),
              onChanged: _runSearch,
            ),
          ),
          if (hasQ)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(display,
                  style: const TextStyle(
                      color: Colors.tealAccent, fontSize: 12, fontFamily: 'monospace')),
            ),
          _iconBtn(Icons.keyboard_arrow_up,   total > 0 ? _prevMatch : null, size: 20),
          _iconBtn(Icons.keyboard_arrow_down, total > 0 ? _nextMatch : null, size: 20),
          _iconBtn(Icons.close, () {
            setState(() {
              _showSearch   = false;
              _searchQuery  = '';
              _matches      = [];
              _lineMatchMap = {};
              _searchCtrl.clear();
            });
          }, size: 18, color: Colors.grey),
        ],
      ),
    );
  }

  Widget _iconBtn(IconData icon, VoidCallback? onTap, {double size = 22, Color? color}) {
    return IconButton(
      icon: Icon(icon, size: size),
      color: onTap != null ? (color ?? Colors.white) : Colors.grey.shade700,
      onPressed: onTap,
      constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
      padding: EdgeInsets.zero,
    );
  }

  // ── Read view: line-numbered ListView with search highlights ──────────────
  Widget _buildReadView() {
    final numDigits  = _viewLines.length.toString().length;
    final gutterW    = numDigits * _fontSize * 0.62 + 12.0;

    return ListView.builder(
      controller: _readScroll,
      padding: const EdgeInsets.only(top: 4, bottom: 24),
      itemCount: _viewLines.length,
      itemBuilder: (ctx, idx) {
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Gutter
              Container(
                width: gutterW,
                alignment: Alignment.topRight,
                padding: EdgeInsets.only(right: 8, top: _fontSize * 0.08),
                color: const Color(0xFF0E0E1C),
                child: Text(
                  '${idx + 1}',
                  style: TextStyle(
                    fontSize: _fontSize * 0.82,
                    color: Colors.grey.shade700,
                    fontFamily: 'monospace',
                    height: 1.48,
                  ),
                ),
              ),
              // Divider
              Container(width: 1, color: const Color(0xFF2A2A3A)),
              // Code
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: _buildLineWidget(idx, _viewLines[idx]),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLineWidget(int lineIdx, String line) {
    final idxList = _lineMatchMap[lineIdx];
    if (idxList == null || idxList.isEmpty) {
      return SelectableText(
        line.isEmpty ? ' ' : line,
        style: TextStyle(
          fontSize: _fontSize, color: Colors.white,
          fontFamily: 'monospace', height: 1.48,
        ),
      );
    }

    final spans = <TextSpan>[];
    int last = 0;
    for (final globalIdx in idxList) {
      final m          = _matches[globalIdx];
      final safeStart  = m.start.clamp(0, line.length);
      final safeEnd    = m.end.clamp(0, line.length);
      final isCurrent  = globalIdx == _matchIdx;

      if (safeStart > last) {
        spans.add(TextSpan(text: line.substring(last, safeStart)));
      }
      spans.add(TextSpan(
        text: line.substring(safeStart, safeEnd),
        style: TextStyle(
          backgroundColor: isCurrent ? Colors.orange : const Color(0x55FFEE58),
          color: Colors.black,
          fontWeight: FontWeight.bold,
        ),
      ));
      last = safeEnd;
    }
    if (last < line.length) spans.add(TextSpan(text: line.substring(last)));

    return SelectableText.rich(
      TextSpan(
        style: TextStyle(
          fontSize: _fontSize, color: Colors.white,
          fontFamily: 'monospace', height: 1.48,
        ),
        children: spans,
      ),
    );
  }

  // ── Edit view: full editable TextField ───────────────────────────────────
  Widget _buildEditView() {
    return TextField(
      controller: _editCtrl,
      maxLines: null,
      expands: true,
      keyboardType: TextInputType.multiline,
      style: TextStyle(
        fontSize: _fontSize,
        fontFamily: 'monospace',
        color: Colors.white,
        height: 1.48,
      ),
      decoration: const InputDecoration(
        border: InputBorder.none,
        contentPadding: EdgeInsets.fromLTRB(12, 8, 12, 16),
      ),
      onChanged: (val) {
        final dirty = val != _saved;
        if (_searchQuery.isNotEmpty) {
          _runSearch(_searchQuery); // recomputes matches on edit content
        } else {
          setState(() => _isDirty = dirty);
        }
        _isDirty = dirty;
      },
    );
  }
}
