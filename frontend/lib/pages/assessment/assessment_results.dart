import 'package:flutter/material.dart';
import 'assessment_radar_chart.dart';
import 'share_assessment_page.dart';

class AssessmentScaleScore {
  final String label;
  final int score; // 1-10

  const AssessmentScaleScore({required this.label, required this.score});
}

class AssessmentResultsPage extends StatelessWidget {
  final int petId;
  final int assessmentId;
  final String petName;
  final String doneByName;
  final DateTime completedAt;

  final int heartScore;
  final int conditionScore;
  final bool significantlyChallenged;
  final List<AssessmentScaleScore> scaleScores;
  final VoidCallback? onDone;
  final bool canShare;

  static const bg = Color(0xFFFBF2EB);
  static const accent = Color(0xFF917869);
  static const titleColor = Color(0xFFD88442);
  static const muted = Color(0xFF676767);

  const AssessmentResultsPage({
    super.key,
    required this.petId,
    required this.assessmentId,
    required this.petName,
    required this.doneByName,
    required this.completedAt,
    required this.heartScore,
    required this.conditionScore,
    required this.significantlyChallenged,
    required this.scaleScores,
    required this.canShare,
    this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        surfaceTintColor: bg,
        foregroundColor: muted,
        title: const Text(
          "Assessment Results",
          style: TextStyle(color: titleColor, fontWeight: FontWeight.w700),
        ),
        actions: [
          if (canShare)
            IconButton(
              icon: const Icon(Icons.share_outlined),
              tooltip: "Share",
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ShareAssessmentPage(
                      petId: petId,
                      assessmentId: assessmentId,
                      petName: petName,
                      doneByName: doneByName,
                      completedAt: completedAt,
                      heartScore: heartScore,
                      conditionScore: conditionScore,
                    ),
                  ),
                );
              },
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _scoreSummaryCard(),

              const SizedBox(height: 12),
              _assessmentRadarCard(),

              const SizedBox(height: 18),
              _heartScaleCard(),
              const SizedBox(height: 12),
              _sectionCard(
                title: _heartScoreRangeTitle(heartScore),
                child: Text(
                  _heartScoreRangeText(heartScore),
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.5,
                    color: muted,
                  ),
                ),
              ),

              const SizedBox(height: 18),
              _conditionScaleCard(),
              const SizedBox(height: 12),
              _sectionCard(
                title: _conditionScoreRangeTitle(conditionScore),
                child: Text(
                  _conditionScoreRangeText(conditionScore),
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.5,
                    color: muted,
                  ),
                ),
              ),

              const SizedBox(height: 24),
              Row(
                children: [
                  if (canShare) ...[
                    Expanded(
                      child: SizedBox(
                        height: 52,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => ShareAssessmentPage(
                                  petId: petId,
                                  assessmentId: assessmentId,
                                  petName: petName,
                                  doneByName: doneByName,
                                  completedAt: completedAt,
                                  heartScore: heartScore,
                                  conditionScore: conditionScore,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.share_outlined),
                          label: const Text(
                            "Share",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: accent,
                            side: const BorderSide(color: accent),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: onDone ?? () => Navigator.of(context).pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          "Done",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _assessmentRadarCard() {
    return _sectionCard(
      title: "Individual Scores",
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (scaleScores.isNotEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 8),
                child: AssessmentRadarChart(
                  scores: scaleScores
                      .map((e) => e.score.toDouble().clamp(1.0, 10.0))
                      .toList(),
                  labels: scaleScores.map((e) => e.label).toList(),
                  size: 320,
                ),
              ),
            ),
          const SizedBox(height: 8),
          _radarLegend(),
        ],
      ),
    );
  }

  Widget _radarLegend() {
    return Wrap(
      spacing: 10,
      runSpacing: 8,
      children: [
        _legendChip("1–3", Colors.red.shade300),
        _legendChip("4–6", accent),
        _legendChip("7–10", Colors.green.shade600),
      ],
    );
  }

  Widget _legendChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _scoreSummaryCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          Expanded(
            child: _topScoreBlock(
              title: "Heart Score",
              score: heartScore.toString(),
              scoreColor: _heartScoreColor(heartScore),
              rangeLabel: _heartScoreShortLabel(heartScore),
            ),
          ),
          Container(width: 1, height: 92, color: Colors.grey.shade300),
          Expanded(
            child: _topScoreBlock(
              title: "Condition Score",
              score: conditionScore.toString(),
              scoreColor: _conditionScoreColor(conditionScore),
              rangeLabel: _conditionScoreShortLabel(conditionScore),
            ),
          ),
        ],
      ),
    );
  }

  Widget _topScoreBlock({
    required String title,
    required String score,
    required Color scoreColor,
    required String rangeLabel,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: muted,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          score,
          style: TextStyle(
            fontSize: 46,
            fontWeight: FontWeight.w800,
            color: scoreColor,
            height: 1,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          rangeLabel,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: accent,
          ),
        ),
      ],
    );
  }

  Widget _heartScaleCard() {
    return _sectionCard(
      title: "Heart Score Scale",
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "The Heart Score reflects whether there may still be meaningful options to pursue for improving this stage of your pet’s life.",
            style: TextStyle(fontSize: 14, height: 1.45, color: muted),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _rangePill(
                  label: "0–2",
                  selected: heartScore <= 2,
                  selectedColor: Colors.red.shade400,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _rangePill(
                  label: "3–5",
                  selected: heartScore >= 3 && heartScore <= 5,
                  selectedColor: accent,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _rangePill(
                  label: "6–10",
                  selected: heartScore >= 6,
                  selectedColor: Colors.green.shade600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _conditionScaleCard() {
    final challenged =
        conditionScore >= 30 && conditionScore <= 90 && significantlyChallenged;

    return _sectionCard(
      title: "Condition Score Scale",
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "The Condition Score reflects your pet’s current day-to-day quality of life based on the concerns highlighted in your responses.",
            style: TextStyle(fontSize: 14, height: 1.45, color: muted),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _rangePill(
                  label: "<30",
                  selected: conditionScore < 30,
                  selectedColor: Colors.red.shade400,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _rangePill(
                  label: "30–60",
                  selected:
                      conditionScore >= 30 &&
                      conditionScore <= 60 &&
                      !challenged,
                  selectedColor: accent,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _rangePill(
                  label: ">60",
                  selected: conditionScore > 60 && !challenged,
                  selectedColor: Colors.green.shade600,
                ),
              ),
            ],
          ),
          if (challenged) ...[
            const SizedBox(height: 10),
            _rangePill(
              label: "30–90, but significantly challenged",
              selected: true,
              selectedColor: Colors.red.shade400,
              fullWidth: true,
            ),
          ],
        ],
      ),
    );
  }

  Widget _rangePill({
    required String label,
    required bool selected,
    required Color selectedColor,
    bool fullWidth = false,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: fullWidth ? double.infinity : null,
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: selected ? selectedColor : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: selected ? selectedColor : Colors.grey.shade300,
          width: 1.2,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : muted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
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

  Color _heartScoreColor(int? score) {
    if (score == null) return muted;
    if (score <= 2) return Colors.red.shade400;
    if (score <= 5) return accent;
    return Colors.green.shade600;
  }

  Color _conditionScoreColor(int? score) {
    if (score == null) return muted;
    if (score < 30) return Colors.red.shade400;
    if (score <= 60) return accent;
    return Colors.green.shade600;
  }

  String _heartScoreShortLabel(int score) {
    if (score >= 6) return "Range 6–10";
    if (score >= 3) return "Range 3–5";
    return "Range 0–2";
  }

  String _conditionScoreShortLabel(int score) {
    final challenged = score >= 30 && score <= 90 && significantlyChallenged;

    if (score < 30) return "Range <30";
    if (challenged) return "Significantly challenged";
    if (score > 60) return "Range >60";
    return "Range 30–60";
  }

  String _heartScoreRangeTitle(int score) {
    if (score >= 6) return "Heart Score Range: 6-10";
    if (score >= 3) return "Heart Score Range: 3-5";
    return "Heart Score Range: 0-2";
  }

  String _heartScoreRangeText(int score) {
    if (score >= 6) {
      return "We have tools in our toolbox to help slow and mitigate some of the changes associated with age or some forms of disease, even if we don't have any that completely stop those processes.\n\n"
          "Based on your responses, $petName may be a candidate for the pursuit of additional lines of treatment to improve the quality of this stage of their life. That doesn't mean that every situation is appropriate to pursue new avenues of care, but under the guidance of your White Whiskers Care Team, there may be more that we can do for $petName.";
    }
    if (score >= 3) {
      return "We have tools in our toolbox to help slow and mitigate some of the changes associated with age or some forms of disease, even if we don't have any that completely stop those processes.\n\n"
          "Based on your responses, with some creativity, there may be some options for $petName that haven't yet been considered. At this score, we want to focus on comfort for both you and $petName with the understanding that a measured approach is a better fit for your family. We want to never lose sight of our mission to make things as good as they can be for each family's situation.";
    }
    return "Based on your responses, the pursuit of treatment for $petName isn't feasible at this time. This is often the case for our animals who consider the treatment to be as bad if not worse than the disease. We can also reach a point as care givers where we don't have the resources to give more than we already have.\n\n"
        "Each situation is unique. Each animal and owner have their own path forward. We will help you find yours and help to ensure that this time with $petName is as good as it can be.";
  }

  String _conditionScoreRangeTitle(int score) {
    final challenged = score >= 30 && score <= 90 && significantlyChallenged;

    if (score < 30) return "Condition Score Range: <30";
    if (challenged) {
      return "Condition Score Range: 30-90, but significantly challenged";
    }
    if (score > 60) return "Condition Score Range: >60";
    return "Condition Score Range: 30-60";
  }

  String _conditionScoreRangeText(int score) {
    final challenged = score >= 30 && score <= 90 && significantlyChallenged;

    if (score < 30) {
      return "We are never ready to say goodbye and we never want to rob them of those good days. It's important, however, that we not hold on so tightly that we cross the threshold of distress with them.\n\n"
          "$petName is nearing that time when our options are few and our time is likely limited. As hard as it is to let them go, know that helping them pass with tranquility and peace is an act of love. When the time is right, we can help you give $petName that gift.\n\n"
          "None of us at White Whiskers have ever had the honor to call ourselves $petName's owners, but we have all loved and lost our own special friends. We understand how hard this time is and we're here to help.";
    }

    if (challenged) {
      return "In a perfect world, our aging pets pass seamlessly in their sleep from a failing mind and body after a good day of play and love and all of their favorite things. All too often, that's not the case and it's only one system that's failing while others are still trucking along.\n\n"
          "Within at least one of your answers, you selected a 1 or a 2 score which means that somewhere along the line you pin pointed something that is causing you or $petName significant distress. Sometimes it's not a whole picture. It's just one incompatible problem that we need to address. Sometimes that problem can be fixed. Sometimes it can't. In either case we can help you better contextualize that problem, see if there are options to address it that work for your family, or help you understand that just one '1' score on this list can be enough to offer them release.\n\n"
          "We're here to help.";
    }

    if (score > 60) {
      return "Not every scoring system is perfect, but your score suggests that we still have options to improve $petName's quality of life and to give you more good days to share with your friend.";
    }

    return "In spite of the challenges $petName is facing, there may be adjustments we can make to improve their quality of life to a point where you can have more time with them.\n\n"
        "Your score places you in a grey zone that is best aided by a physical examination. Contact us today to schedule a Crossroads Visit with our doctor who will help you to be the best advocate for $petName as you can be.";
  }
}
