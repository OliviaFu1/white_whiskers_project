import 'package:flutter/material.dart';
import '../../services/assessment_api.dart';
import '../../services/calendar_api.dart';

class ShareAssessmentPage extends StatefulWidget {
  final int petId;
  final int assessmentId;
  final String petName;
  final String doneByName;
  final DateTime completedAt;
  final int heartScore;
  final int conditionScore;

  const ShareAssessmentPage({
    super.key,
    required this.petId,
    required this.assessmentId,
    required this.petName,
    required this.doneByName,
    required this.completedAt,
    required this.heartScore,
    required this.conditionScore,
  });

  @override
  State<ShareAssessmentPage> createState() => _ShareAssessmentPageState();
}

class _ShareAssessmentPageState extends State<ShareAssessmentPage> {
  static const bg = Color(0xFFFBF2EB);
  static const accent = Color(0xFF917869);
  static const titleColor = Color(0xFFD88442);
  static const muted = Color(0xFF676767);

  final TextEditingController _commentController = TextEditingController();

  bool _loading = true;
  bool _sending = false;
  String? _error;

  List<Map<String, dynamic>> _recipients = [];
  Map<String, dynamic>? _selectedRecipient;

  Map<DateTime, _DayStatus> _statusByDay = {};

  @override
  void initState() {
    super.initState();
    _loadPageData();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadPageData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final recipients = await AssessmentApi.listShareRecipients();

      final checkins = await CalendarApi.listDailyCheckins(
        petId: widget.petId,
        mineOnly: true,
      );

      final statusMap = <DateTime, _DayStatus>{};

      for (final c in checkins) {
        final dateStr = (c["checkin_date"] ?? "").toString();
        if (dateStr.isEmpty) continue;

        final d = _parseYyyyMmDd(dateStr);
        final rating = (c["day_rating"] ?? "neutral").toString();
        final s = _toDayStatus(rating);

        statusMap[d] = _combineDayStatus(statusMap[d], s);
      }

      if (!mounted) return;

      setState(() {
        _recipients = recipients;
        _selectedRecipient = recipients.isNotEmpty ? recipients.first : null;
        _statusByDay = statusMap;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _send() async {
    if (_selectedRecipient == null || _sending) return;

    setState(() {
      _sending = true;
    });

    try {
      final today = _dateOnly(DateTime.now());

      final (allPct, allN) = _computeGoodPctRange(
        endDayInclusive: today,
        daysBack: 0,
      );
      final (pct28, n28) = _computeGoodPctRange(
        endDayInclusive: today,
        daysBack: 28,
      );
      final (pct7, n7) = _computeGoodPctRange(
        endDayInclusive: today,
        daysBack: 7,
      );

      await AssessmentApi.shareAssessment(
        assessmentId: widget.assessmentId,
        body: {
          "recipient_id": _selectedRecipient!["id"],
          "recipient_type": _selectedRecipient!["type"],
          "questions_comments": _commentController.text.trim(),
          "all_time_good_pct": allPct.round(),
          "past_28_days_good_pct": n28 >= 15 ? pct28.round() : null,
          "past_7_days_good_pct": n7 >= 4 ? pct7.round() : null,
        },
      );

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Assessment shared.")));
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Failed to share assessment: $e")));
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final today = _dateOnly(DateTime.now());
    final (allPct, allN) = _computeGoodPctRange(
      endDayInclusive: today,
      daysBack: 0,
    );
    final (pct28, n28) = _computeGoodPctRange(
      endDayInclusive: today,
      daysBack: 28,
    );
    final (pct7, n7) = _computeGoodPctRange(
      endDayInclusive: today,
      daysBack: 7,
    );

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        surfaceTintColor: bg,
        foregroundColor: muted,
        title: const Text(
          "Share Assessment",
          style: TextStyle(color: titleColor, fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_error != null) ...[
                      _sectionCard(
                        title: "Unable to load",
                        child: Text(
                          _error!,
                          style: const TextStyle(
                            fontSize: 14,
                            height: 1.45,
                            color: Colors.redAccent,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    _sectionCard(
                      title: "Share with",
                      child: _recipients.isEmpty
                          ? const Text(
                              "No primary vet or specialist with an email address is available for this pet yet.",
                              style: TextStyle(
                                fontSize: 14,
                                height: 1.45,
                                color: muted,
                              ),
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                DropdownButtonFormField<Map<String, dynamic>>(
                                  initialValue: _selectedRecipient,
                                  isExpanded: true,
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: const Color(0xFFF8F3EF),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 14,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                  items: _recipients.map((recipient) {
                                    return DropdownMenuItem<
                                      Map<String, dynamic>
                                    >(
                                      value: recipient,
                                      child: Text(
                                        (recipient["label"] ?? "").toString(),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedRecipient = value;
                                    });
                                  },
                                ),
                                if (_selectedRecipient != null &&
                                    ((_selectedRecipient!["email"] ?? "")
                                        .toString()
                                        .trim()
                                        .isNotEmpty)) ...[
                                  const SizedBox(height: 10),
                                  Text(
                                    (_selectedRecipient!["email"] ?? "")
                                        .toString(),
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: muted,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                    ),

                    const SizedBox(height: 12),

                    _sectionCard(
                      title: "Good day / bad day summary",
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _summaryLine(
                            "All-time",
                            allN > 0
                                ? "${allPct.toStringAsFixed(0)}% good"
                                : "—",
                          ),
                          const SizedBox(height: 8),
                          _summaryLine(
                            "Past 28 days",
                            n28 >= 15
                                ? "${pct28.toStringAsFixed(0)}% good"
                                : "—",
                            trailingNote: n28 >= 15
                                ? null
                                : "Need at least 15 check-ins",
                          ),
                          const SizedBox(height: 8),
                          _summaryLine(
                            "Past 7 days",
                            n7 >= 4 ? "${pct7.toStringAsFixed(0)}% good" : "—",
                            trailingNote: n7 >= 4
                                ? null
                                : "Need at least 4 check-ins",
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    _sectionCard(
                      title: "Questions / Comments",
                      child: TextField(
                        controller: _commentController,
                        minLines: 2,
                        maxLines: 4,
                        decoration: InputDecoration(
                          hintText:
                              "Add any questions or comments to include in the email...",
                          filled: true,
                          fillColor: const Color(0xFFF8F3EF),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.all(14),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    _sectionCard(
                      title: "Assessment to share",
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _infoRow("Pet", widget.petName),
                          const SizedBox(height: 8),
                          _infoRow("Date", _formatDate(widget.completedAt)),
                          const SizedBox(height: 8),
                          _infoRow("Done by", widget.doneByName),
                          const SizedBox(height: 8),
                          _infoRow("Heart Score", widget.heartScore.toString()),
                          const SizedBox(height: 8),
                          _infoRow(
                            "Condition Score",
                            widget.conditionScore.toString(),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: (_selectedRecipient == null || _sending)
                            ? null
                            : _send,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accent,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.grey.shade300,
                          disabledForegroundColor: Colors.grey.shade600,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child: _sending
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : const Text(
                                "Send",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _sectionCard({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            blurRadius: 12,
            offset: Offset(0, 6),
            color: Color(0x22000000),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: accent,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _summaryLine(String label, String value, {String? trailingNote}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            "$label: $value",
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: muted,
            ),
          ),
        ),
        if (trailingNote != null)
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Text(
              trailingNote,
              style: const TextStyle(fontSize: 12, color: muted),
            ),
          ),
      ],
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 150,
          child: Text(
            "$label:",
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: muted,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 14, height: 1.4, color: muted),
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime dt) {
    final mm = dt.month.toString().padLeft(2, '0');
    final dd = dt.day.toString().padLeft(2, '0');
    final yyyy = dt.year.toString();
    return "$mm/$dd/$yyyy";
  }

  (double pct, int n) _computeGoodPctRange({
    required DateTime endDayInclusive,
    required int daysBack,
  }) {
    int good = 0;
    int total = 0;

    if (daysBack == 0) {
      for (final s in _statusByDay.values) {
        total++;
        if (s == _DayStatus.good) good++;
      }
      return (total == 0 ? 0.0 : 100.0 * good / total, total);
    }

    final end = _dateOnly(endDayInclusive);
    final start = _dateOnly(end.subtract(Duration(days: daysBack - 1)));

    for (final entry in _statusByDay.entries) {
      final d = entry.key;
      if (d.isBefore(start) || d.isAfter(end)) continue;
      total++;
      if (entry.value == _DayStatus.good) good++;
    }

    return (total == 0 ? 0.0 : 100.0 * good / total, total);
  }

  _DayStatus _toDayStatus(String dayRating) {
    switch (dayRating) {
      case "good":
        return _DayStatus.good;
      case "bad":
        return _DayStatus.bad;
      default:
        return _DayStatus.neutral;
    }
  }

  _DayStatus _combineDayStatus(_DayStatus? existing, _DayStatus incoming) {
    if (existing == null) return incoming;
    if (existing == _DayStatus.bad || incoming == _DayStatus.bad) {
      return _DayStatus.bad;
    }
    if (existing == _DayStatus.neutral || incoming == _DayStatus.neutral) {
      return _DayStatus.neutral;
    }
    return _DayStatus.good;
  }

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  DateTime _parseYyyyMmDd(String s) {
    final parts = s.split("-");
    return DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  }
}

enum _DayStatus { good, bad, neutral }
