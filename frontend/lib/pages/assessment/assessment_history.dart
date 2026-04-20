import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../services/assessment_api.dart';
import 'assessment_results.dart';

class AssessmentHistoryPage extends StatefulWidget {
  final int petId;
  final String petName;

  const AssessmentHistoryPage({
    super.key,
    required this.petId,
    required this.petName,
  });

  @override
  State<AssessmentHistoryPage> createState() => _AssessmentHistoryPageState();
}

class _AssessmentHistoryPageState extends State<AssessmentHistoryPage> {
  static const bg = Color(0xFFFBF2EB);
  static const accent = Color(0xFF917869);
  static const titleColor = Color(0xFFD88442);
  static const muted = Color(0xFF676767);

  bool isLoading = true;
  String? errorText;
  List<Map<String, dynamic>> assessments = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      isLoading = true;
      errorText = null;
    });

    try {
      final result = await AssessmentApi.listAssessments(petId: widget.petId);

      if (!mounted) return;

      result.sort((a, b) {
        final aTime = DateTime.tryParse((a["submitted_at"] ?? "").toString());
        final bTime = DateTime.tryParse((b["submitted_at"] ?? "").toString());

        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        return bTime.compareTo(aTime);
      });

      setState(() {
        assessments = result;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorText = e.toString();
        isLoading = false;
      });
    }
  }

  String? _assessmentAuthor(Map<String, dynamic> assessment) {
    final ownerName = (assessment["owner_name"] ?? "").toString().trim();
    if (ownerName.isEmpty) return null;
    return ownerName;
  }

  int _readScore(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  Map<String, dynamic>? _assessmentAnswers(Map<String, dynamic>? assessment) {
    if (assessment == null) return null;
    final raw = assessment["answers"];
    if (raw is Map<String, dynamic>) return raw;
    return null;
  }

  List<AssessmentScaleScore> _buildScaleScores(
    Map<String, dynamic>? assessment,
  ) {
    final answers = _assessmentAnswers(assessment);
    if (answers == null) return const [];

    final fields = <MapEntry<String, String>>[
      const MapEntry("Appetite", "appetite_score"),
      const MapEntry("Hydration", "hydration_score"),
      const MapEntry("Cleanliness", "cleanliness_score"),
      const MapEntry("Mobility", "mobility_score"),
      const MapEntry("Physical Comfort", "physical_score"),
      const MapEntry("State of Mind", "state_of_mind_score"),
      const MapEntry("Owner State", "owner_state_score"),
    ];

    return fields
        .map(
          (e) => AssessmentScaleScore(
            label: e.key,
            score: _readScore(answers[e.value]),
          ),
        )
        .toList();
  }

  bool _hasSignificantlyChallengedFlag(Map<String, dynamic>? assessment) {
    final value = assessment?["significantly_challenged"];
    if (value is bool) return value;
    if (value is String) return value.toLowerCase() == "true";
    if (value is int) return value == 1;
    return false;
  }

  String _formatShortDate(dynamic raw) {
    if (raw == null) return "—";
    try {
      final dt = DateTime.parse(raw.toString()).toLocal();
      const months = [
        "Jan",
        "Feb",
        "Mar",
        "Apr",
        "May",
        "Jun",
        "Jul",
        "Aug",
        "Sep",
        "Oct",
        "Nov",
        "Dec",
      ];
      return "${months[dt.month - 1]} ${dt.day}, ${dt.year}";
    } catch (_) {
      return "—";
    }
  }

  String _formatAxisDate(dynamic raw) {
    if (raw == null) return "";
    try {
      final dt = DateTime.parse(raw.toString()).toLocal();
      return "${dt.month}/${dt.day}";
    } catch (_) {
      return "";
    }
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      boxShadow: const [
        BoxShadow(
          blurRadius: 12,
          offset: Offset(0, 6),
          color: Color(0x22000000),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: muted),
        title: Text(
          "${widget.petName} Assessment History",
          style: const TextStyle(
            color: titleColor,
            fontWeight: FontWeight.w700,
            fontSize: 22,
          ),
        ),
      ),
      body: SafeArea(
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : errorText != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    errorText!,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            : assessments.isEmpty
            ? const Center(
                child: Text(
                  "No assessment history yet.",
                  style: TextStyle(color: muted, fontSize: 16),
                ),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                children: [
                  _TrendSection(
                    assessments: assessments,
                    formatAxisDate: _formatAxisDate,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "Previous assessments",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: accent,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...assessments.map(_buildAssessmentCard),
                ],
              ),
      ),
    );
  }

  Widget _buildAssessmentCard(Map<String, dynamic> assessment) {
    final heartScore = _readScore(assessment["heart_score"]);
    final conditionScore = _readScore(assessment["condition_score"]);
    final dateText = _formatShortDate(assessment["submitted_at"]);
    final authorText = _assessmentAuthor(assessment);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => AssessmentResultsPage(
                petId: widget.petId,
                assessmentId: _readScore(assessment["id"]),
                petName: widget.petName,
                doneByName: _assessmentAuthor(assessment) ?? "Owner",
                completedAt: assessment["submitted_at"],
                heartScore: heartScore,
                conditionScore: conditionScore,
                significantlyChallenged: _hasSignificantlyChallengedFlag(
                  assessment,
                ),
                scaleScores: _buildScaleScores(assessment),
                onDone: () {
                  Navigator.of(context).pop();
                },
              ),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: _cardDecoration(),
          child: Row(
            children: [
              SizedBox(
                width: 115,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      dateText,
                      style: const TextStyle(
                        color: muted,
                        fontSize: 15,
                        height: 1.2,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (authorText != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        "By $authorText",
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: muted,
                          fontSize: 12.5,
                          height: 1.2,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  children: [
                    Row(
                      children: const [
                        Expanded(
                          child: Text(
                            "heart",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: muted,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            "condition",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: muted,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            heartScore.toString(),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: muted,
                              fontSize: 34,
                              fontWeight: FontWeight.w800,
                              height: 1,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            conditionScore.toString(),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: muted,
                              fontSize: 34,
                              fontWeight: FontWeight.w800,
                              height: 1,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, color: muted, size: 28),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrendSection extends StatelessWidget {
  final List<Map<String, dynamic>> assessments;
  final String Function(dynamic raw) formatAxisDate;

  static const heartColor = Color(0xFFD88442);
  static const conditionColor = Color(0xFF917869);
  static const muted = Color(0xFF676767);

  const _TrendSection({
    required this.assessments,
    required this.formatAxisDate,
  });

  int _readScore(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final chronological = [...assessments.reversed].toList();

    final heartScores = chronological
        .map((e) => _readScore(e["heart_score"]).toDouble())
        .toList();

    final conditionScores = chronological
        .map((e) => _readScore(e["condition_score"]).toDouble())
        .toList();

    final labels = chronological
        .map((e) => formatAxisDate(e["submitted_at"]))
        .toList();

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
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
          const Text(
            "Score trends",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: muted,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 220,
            child: LayoutBuilder(
              builder: (context, constraints) {
                const leftAxisWidth = 20.0;
                const rightAxisWidth = 30.0;
                const visibleCount = 6;
                const pointSpacing = 56.0;
                const plotHeight = 210.0;

                final viewportWidth =
                    constraints.maxWidth - leftAxisWidth - rightAxisWidth;

                final minPlotWidth = visibleCount * pointSpacing;

                final plotWidth = math.max(
                  math.max(viewportWidth, minPlotWidth),
                  labels.length <= 1
                      ? viewportWidth
                      : (labels.length - 1) * pointSpacing,
                );

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: leftAxisWidth,
                      height: plotHeight,
                      child: const CustomPaint(painter: _LeftAxisPainter()),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(
                          width: plotWidth,
                          height: plotHeight,
                          child: CustomPaint(
                            painter: _ScrollableTrendPlotPainter(
                              heartScores: heartScores,
                              conditionScores: conditionScores,
                              labels: labels,
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: rightAxisWidth,
                      height: plotHeight,
                      child: const CustomPaint(painter: _RightAxisPainter()),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 6),
          const Row(
            children: [
              _LegendDot(color: heartColor),
              SizedBox(width: 6),
              Text(
                "Heart score",
                style: TextStyle(color: muted, fontWeight: FontWeight.w600),
              ),
              SizedBox(width: 18),
              _LegendDot(color: conditionColor),
              SizedBox(width: 6),
              Text(
                "Condition score",
                style: TextStyle(color: muted, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;

  const _LegendDot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _LeftAxisPainter extends CustomPainter {
  static const heartColor = Color(0xFFD88442);

  const _LeftAxisPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const topPad = 14.0;
    const bottomPad = 30.0;
    final chartHeight = size.height - topPad - bottomPad;

    const textStyle = TextStyle(
      color: heartColor,
      fontSize: 10,
      fontWeight: FontWeight.w600,
    );

    const fractions = [0.0, 0.2, 0.4, 0.6, 0.8, 1.0];

    final titlePainter = TextPainter(
      text: const TextSpan(
        text: "Heart",
        style: TextStyle(
          color: heartColor,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    titlePainter.paint(canvas, const Offset(0, -8));

    for (final frac in fractions) {
      final dy = topPad + chartHeight - frac * chartHeight;
      final value = (frac * 10).round();

      final tp = TextPainter(
        text: TextSpan(text: value.toString(), style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();

      tp.paint(canvas, Offset(size.width - tp.width - 4, dy - tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _RightAxisPainter extends CustomPainter {
  static const conditionColor = Color(0xFF917869);

  const _RightAxisPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const topPad = 14.0;
    const bottomPad = 30.0;
    final chartHeight = size.height - topPad - bottomPad;

    const textStyle = TextStyle(
      color: conditionColor,
      fontSize: 10,
      fontWeight: FontWeight.w600,
    );

    const fractions = [0.0, 0.2, 0.4, 0.6, 0.8, 1.0];

    final titlePainter = TextPainter(
      text: const TextSpan(
        text: "Condition",
        style: TextStyle(
          color: conditionColor,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    titlePainter.paint(canvas, const Offset(-20, -8));

    for (final frac in fractions) {
      final dy = topPad + chartHeight - frac * chartHeight;
      final value = (frac * 100).round();

      final tp = TextPainter(
        text: TextSpan(text: value.toString(), style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();

      tp.paint(canvas, Offset(4, dy - tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ScrollableTrendPlotPainter extends CustomPainter {
  final List<double> heartScores;
  final List<double> conditionScores;
  final List<String> labels;

  static const heartColor = Color(0xFFD88442);
  static const conditionColor = Color(0xFF917869);
  static const gridColor = Color(0xFFE8DED6);
  static const axisColor = Color(0xFF676767);

  _ScrollableTrendPlotPainter({
    required this.heartScores,
    required this.conditionScores,
    required this.labels,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const topPad = 14.0;
    const bottomPad = 30.0;

    final chartRect = Rect.fromLTWH(
      18,
      topPad,
      size.width - 18 * 2,
      size.height - topPad - bottomPad,
    );

    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;

    const fractions = [0.0, 0.2, 0.4, 0.6, 0.8, 1.0];

    for (final frac in fractions) {
      final dy = chartRect.bottom - frac * chartRect.height;
      canvas.drawLine(
        Offset(chartRect.left, dy),
        Offset(chartRect.right, dy),
        gridPaint,
      );
    }

    if (labels.isEmpty) return;

    final count = labels.length;
    final stepX = count == 1 ? 0.0 : chartRect.width / (count - 1);

    List<Offset> buildPoints(List<double> values, double maxValue) {
      return List.generate(values.length, (i) {
        final x = chartRect.left + stepX * i;
        final normalized = values[i].clamp(0, maxValue) / maxValue;
        final y = chartRect.bottom - normalized * chartRect.height;
        return Offset(x, y);
      });
    }

    final heartPoints = buildPoints(heartScores, 10);
    final conditionPoints = buildPoints(conditionScores, 100);

    void drawSeries(List<Offset> points, Color color) {
      if (points.isEmpty) return;

      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (int i = 1; i < points.length; i++) {
        path.lineTo(points[i].dx, points[i].dy);
      }

      final linePaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      final dotPaint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;

      canvas.drawPath(path, linePaint);

      for (final p in points) {
        canvas.drawCircle(p, 4.5, dotPaint);
      }
    }

    drawSeries(heartPoints, heartColor);
    drawSeries(conditionPoints, conditionColor);

    const axisTextStyle = TextStyle(
      color: axisColor,
      fontSize: 10,
      fontWeight: FontWeight.w500,
    );

    for (int i = 0; i < labels.length; i++) {
      final tp = TextPainter(
        text: TextSpan(text: labels[i], style: axisTextStyle),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 40);

      final dx = (chartRect.left + stepX * i) - tp.width / 2;
      tp.paint(canvas, Offset(dx, chartRect.bottom + 8));
    }
  }

  @override
  bool shouldRepaint(covariant _ScrollableTrendPlotPainter oldDelegate) {
    return oldDelegate.heartScores != heartScores ||
        oldDelegate.conditionScores != conditionScores ||
        oldDelegate.labels != labels;
  }
}
