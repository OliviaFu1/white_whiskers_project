import 'package:flutter/material.dart';
import '../../services/medication_api.dart';

class MedicationLogPage extends StatefulWidget {
  final int medicationId;
  final String drugName;

  const MedicationLogPage({
    super.key,
    required this.medicationId,
    required this.drugName,
  });

  @override
  State<MedicationLogPage> createState() => _MedicationLogPageState();
}

class _MedicationLogPageState extends State<MedicationLogPage> {
  static const bg         = Color(0xFFFBF2EB);
  static const titleColor = Color(0xFFD88442);
  static const muted      = Color(0xFF676767);
  static const accent     = Color(0xFF917869);

  static const _statusColors = {
    "active":    Color(0xFF4CAF50),
    "paused":    Color(0xFFFF9800),
    "stopped":   Color(0xFFE53935),
    "completed": Color(0xFF2196F3),
  };

  List<Map<String, dynamic>>? _logs;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final logs = await MedicationApi.listLogs(
        medicationId: widget.medicationId,
      );
      if (mounted) setState(() { _logs = logs; _error = null; });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        leading: const BackButton(color: muted),
        title: Text(
          "${widget.drugName} — History",
          style: const TextStyle(
            color: titleColor,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return ListView(
        children: [
          const SizedBox(height: 80),
          Center(
            child: Text(_error!, style: const TextStyle(color: muted)),
          ),
        ],
      );
    }

    if (_logs == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_logs!.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 80),
          Center(
            child: Text(
              "No history yet",
              style: TextStyle(color: muted, fontSize: 16),
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 40),
      itemCount: _logs!.length,
      separatorBuilder: (_, __) => const SizedBox(height: 0),
      itemBuilder: (context, index) => _buildEntry(_logs![index], index),
    );
  }

  Widget _buildEntry(Map<String, dynamic> entry, int index) {
    final eventType = (entry["event_type"] ?? "").toString();
    final newStatus = (entry["new_status"] ?? "").toString();
    final notes = (entry["notes"] ?? "").toString().trim();
    final dateStr = entry["event_date"]?.toString().isNotEmpty == true
        ? _formatDate(entry["event_date"].toString())
        : _formatDate(entry["timestamp"]?.toString() ?? "");

    final isLast = index == _logs!.length - 1;
    final canHaveNotes = eventType == "status_change" &&
        (newStatus == "paused" || newStatus == "stopped");

    Widget icon;
    String label;

    if (eventType == "refill") {
      icon = Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.refresh, size: 20, color: accent),
      );
      label = "Refill used";
    } else {
      // status_change
      final color = _statusColors[newStatus] ?? muted;
      icon = Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
        ),
      );
      label = _capitalize(newStatus);
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline column
          SizedBox(
            width: 36,
            child: Column(
              children: [
                icon,
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: const Color(0xFFE8DDD5),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          // Content
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 6),
                        Text(
                          label,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: muted,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          dateStr,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF9E9E9E),
                          ),
                        ),
                        if (notes.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            notes,
                            style: const TextStyle(
                              fontSize: 13,
                              color: muted,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  // Edit notes (only for paused/stopped entries)
                  if (canHaveNotes)
                    IconButton(
                      icon: Icon(
                        notes.isNotEmpty ? Icons.edit_outlined : Icons.add_comment_outlined,
                        size: 18,
                      ),
                      color: const Color(0xFFBBB3AC),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      visualDensity: VisualDensity.compact,
                      tooltip: notes.isNotEmpty ? "Edit note" : "Add note",
                      onPressed: () => _editNotes(entry, index),
                    ),
                  if (canHaveNotes) const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    color: const Color(0xFFBBB3AC),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    visualDensity: VisualDensity.compact,
                    tooltip: "Delete entry",
                    onPressed: () => _confirmDelete(entry),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editNotes(Map<String, dynamic> entry, int index) async {
    final id = entry["id"] as int?;
    if (id == null) return;

    final current = (entry["notes"] ?? "").toString().trim();
    final controller = TextEditingController(text: current);

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: bg,
        title: const Text(
          "Edit note",
          style: TextStyle(color: muted, fontWeight: FontWeight.w700, fontSize: 17),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            hintText: "Add a note…",
            hintStyle: const TextStyle(color: Color(0xFFBBB3AC)),
            filled: true,
            fillColor: const Color(0xFFF5EDE6),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text("Cancel", style: TextStyle(color: muted)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text(
              "Save",
              style: TextStyle(color: titleColor, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
    if (result == null || !mounted) return;

    try {
      final updated = await MedicationApi.updateLog(logId: id, notes: result);
      if (!mounted) return;
      setState(() {
        _logs![index] = {...entry, "notes": updated["notes"] ?? result};
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  Future<void> _confirmDelete(Map<String, dynamic> entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: bg,
        title: const Text(
          "Delete entry?",
          style: TextStyle(color: muted, fontWeight: FontWeight.w700),
        ),
        content: const Text(
          "This history entry will be permanently removed. It will not affect the prescription supply.",
          style: TextStyle(color: muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text("Cancel", style: TextStyle(color: muted)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              "Delete",
              style: TextStyle(color: Color(0xFFE53935), fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final id = entry["id"] as int?;
    if (id == null) return;

    try {
      await MedicationApi.deleteLog(id);
      if (!mounted) return;
      setState(() => _logs!.removeWhere((e) => e["id"] == id));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  String _formatDate(String raw) {
    try {
      final dt = DateTime.parse(raw);
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ];
      return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
    } catch (_) {
      return raw;
    }
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}
