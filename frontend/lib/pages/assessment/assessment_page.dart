import 'package:flutter/material.dart';
import '../../services/assessment_api.dart';
import '../../state/notifiers.dart';
import '../app_shell.dart';

part 'assessment_components.dart';

class AssessmentPage extends StatefulWidget {
  final int petId;
  final String petName;
  final String ownerName;

  const AssessmentPage({
    super.key,
    required this.petId,
    required this.petName,
    required this.ownerName,
  });

  @override
  State<AssessmentPage> createState() => _AssessmentPageState();
}

class _AssessmentPageState extends State<AssessmentPage> {
  late final PageController _pageController;
  int _currentPage = 0;

  bool _isSubmitting = false;
  bool _isLoadingPrevious = true;

  Map<String, dynamic>? _previousAnswers;

  final Map<String, dynamic> _answers = {
    "favorite_pet_things": <String>["", "", ""],
    "favorite_shared_things": <String>["", ""],
    "biggest_concerns": <String>[],
    "other_concern_text": "",
    "concerns_expand": "",
    "concern_duration": "",
    "last_30_days": "",
    "boundaries": "",
    "preference_info": "",
    "which_best_describes_you": "",
    "pet_tolerance": "",
    "medicine_success": "",
    "physical_score": null,
    "physical_explanation": "",
    "appetite_score": null,
    "appetite_explanation": "",
    "food_relationship": "",
    "hydration_score": null,
    "hydration_explanation": "",
    "mobility_score": null,
    "mobility_explanation": "",
    "cleanliness_score": null,
    "cleanliness_explanation": "",
    "state_of_mind_score": null,
    "state_of_mind_explanation": "",
    "joy_items": <Map<String, dynamic>>[],
    "joy_explanation": "",
    "owner_state_score": null,
    "owner_state_explanation": "",
  };

  List<_AssessmentStep> get _steps => _buildSteps();

  // ---------------------------
  // Lifecycle & initial loading
  // ---------------------------

  @override
  void initState() {
    super.initState();
    _pageController = PageController();

    final joyItems = _answers["joy_items"] as List<Map<String, dynamic>>;
    if (joyItems.isEmpty) {
      _answers["joy_items"] = List.generate(
        5,
        (_) => {"label": "", "status": ""},
      );
    }

    _loadPreviousAssessment();
  }

  Future<void> _loadPreviousAssessment() async {
    try {
      final latest = await AssessmentApi.getLatestAssessment(
        petId: widget.petId,
      );
      final rawAnswers = latest?["answers"];

      if (rawAnswers is Map) {
        _previousAnswers = Map<String, dynamic>.from(rawAnswers);
        _prefillInitializeAnswersFromPrevious();
      }
    } catch (_) {
      // no-op
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingPrevious = false;
        });
      }
    }
  }

  void _prefillInitializeAnswersFromPrevious() {
    if (_previousAnswers == null) return;

    void copyKey(String key) {
      if (!_previousAnswers!.containsKey(key)) return;
      final value = _previousAnswers![key];

      if (value is List) {
        _answers[key] = value.map((e) => e.toString()).toList();
      } else if (value is Map) {
        _answers[key] = Map<String, dynamic>.from(value);
      } else {
        _answers[key] = value;
      }
    }

    copyKey("favorite_pet_things");
    copyKey("favorite_shared_things");
    copyKey("biggest_concerns");
    copyKey("other_concern_text");
    copyKey("concerns_expand");
    copyKey("concern_duration");
    copyKey("last_30_days");
    copyKey("boundaries");
    copyKey("preference_info");
    copyKey("which_best_describes_you");
    copyKey("pet_tolerance");
    copyKey("medicine_success");

    _syncJoyItemsFromFavorites();
  }

  // ---------------------------
  // Step definitions & grouping
  // ---------------------------

  static const List<String> _initializeStepIds = [
    "intro_favorites",
    "concerns",
    "boundaries",
    "describe_yourself",
    "describe_pet",
  ];

  static const List<String> _updateStepIds = [
    "physical_condition",
    "appetite",
    "water_intake",
    "mobility",
    "hygiene",
    "state_of_mind",
    "joy",
    "owner_state",
  ];

  static const List<String> _initializeStartKeys = [
    "favorite_pet_things",
    "favorite_shared_things",
    "biggest_concerns",
    "other_concern_text",
    "concerns_expand",
    "concern_duration",
    "last_30_days",
    "boundaries",
    "preference_info",
    "which_best_describes_you",
    "pet_tolerance",
    "medicine_success",
  ];

  static const List<String> _updateScoreKeys = [
    "physical_score",
    "appetite_score",
    "hydration_score",
    "mobility_score",
    "cleanliness_score",
    "state_of_mind_score",
    "owner_state_score",
  ];

  List<_AssessmentStep> get _initializeStepsOnly =>
      _steps.where((s) => _initializeStepIds.contains(s.id)).toList();

  List<_AssessmentStep> get _updateStepsOnly =>
      _steps.where((s) => _updateStepIds.contains(s.id)).toList();

  List<_AssessmentStep> _buildSteps() {
    return [
      _AssessmentStep(
        id: "overview",
        title: "New Assessment for ${widget.petName}",
        description: null,
        builder: _buildOverviewStep,
      ),
      _AssessmentStep(
        id: "intro_favorites",
        title: "In Your Words...",
        description: null,
        builder: _buildFavoritesStep,
      ),
      _AssessmentStep(
        id: "concerns",
        title:
            "What are your biggest concerns regarding ${widget.petName}’s health?",
        description: null,
        builder: _buildConcernsStep,
      ),
      _AssessmentStep(
        id: "boundaries",
        title: "This next question is hard, but important.",
        description:
            "We all have limits as to when our pets' quality of life has diminished to the point of hard decisions, but defining where some of those limits are isn't something we are eager to think about. However, they are important.\n\nFor some, it might be when their pet stops eating. For others it's an inability to get up on their own or a perception of their pain. There are no wrong answers, but this deep reflection greatly helps guide our discussion.",
        builder: _buildBoundariesStep,
      ),
      _AssessmentStep(
        id: "describe_yourself",
        title: "Describe yourself...",
        description:
            "This is not a judgement. Your comfort through this process is important too and understanding who you are helps us direct you towards what options are best for you and your family. Your honest answers help us give you and your pet the best experience.",
        builder: _buildDescribeYourselfStep,
      ),
      _AssessmentStep(
        id: "describe_pet",
        title: "Describe ${widget.petName}...",
        description:
            "We are their advocates and can never forget that the decisions we make on their behalf affect them directly. Not every decision is right for every animal.",
        builder: _buildDescribePetStep,
      ),
      _AssessmentStep(
        id: "physical_condition",
        title: "${widget.petName}'s Physical Condition",
        description:
            "Aging isn't a disease, but its process can challenge every aspect of the senior body.",
        builder: _buildPhysicalConditionStep,
      ),
      _AssessmentStep(
        id: "appetite",
        title: "${widget.petName}'s Appetite",
        description:
            "Our pets' appetites are some of the easiest external signals to quantify when we are trying to understand their situation. When they stop eating, it tells us that something isn't right. Likewise, a voracious change in their appetite can alert us to hidden changes as well.",
        builder: _buildAppetiteStep,
      ),
      _AssessmentStep(
        id: "water_intake",
        title: "${widget.petName}'s Water Intake",
        description:
            "Like their appetites, changes to our pets' water intake can be a signifier that important changes are taking place within their bodies. Likewise, inappropriate urination or incontinence can signal that mechanical or cognitive problems need to be addressed.",
        builder: _buildHydrationStep,
      ),
      _AssessmentStep(
        id: "mobility",
        title: "${widget.petName}'s Mobility",
        description:
            "Movement is life for our senior animals. When they hurt, their reluctance to move can result in greater degradation of their joint health which can, in turn, lead to more pain and even less movement. It can become a vicious cycle.\n\nThe good news is that some hindrances to movement can be addressed and even reversed. The sooner these factors are identified and discussed, the better our odds are that we can make meaningful adjustments for their quality of life.",
        builder: _buildMobilityStep,
      ),
      _AssessmentStep(
        id: "hygiene",
        title: "${widget.petName}'s Hygiene and Elimination",
        description:
            "An animal's ability and desire to groom often takes a back seat to discomfort or pain. Furthermore, an inability to clean oneself or to remain clean can result in skin irritation ranging from redness to open wounds. This metric becomes much more important in cases of poor mobility or difficulty with elimination.",
        builder: _buildCleanlinessStep,
      ),
      _AssessmentStep(
        id: "state_of_mind",
        title: "${widget.petName}'s State of Mind",
        description:
            "Our companion animals can undergo age-related changes to their minds and their behavior, very similar to humans can experience. These changes can be present in conjunction with physical age-related challenges or they can present completely on their own.\n\nHave you detected a behavioral change in ${widget.petName}? Some examples are increased grumpiness, getting lost in familiar places, hiding or distancing or incessant pacing. Like human dementia, the early stages of this process can be difficult to assess because symptoms can wax and wane and often lack consistency.",
        builder: _buildStateOfMindStep,
      ),
      _AssessmentStep(
        id: "joy",
        title: "${widget.petName}'s Joy of Life",
        description:
            "As our pets age, their engagement with all of the things that they loved throughout their life can change. We asked you earlier about ${widget.petName}'s favorite activities. Thinking about them now, of those 5, which does ${widget.petName} still find enjoyment in?",
        builder: _buildJoyStep,
      ),
      _AssessmentStep(
        id: "owner_state",
        title: "${widget.ownerName}'s State of Mind",
        description:
            "${widget.petName} isn't the only consideration in this equation. You and your family matter as well. Although our last years with our cherished friends can be beautiful, they can be rife with challenges as well.\n\nThere are times when our situation or ability to cope with the increasing needs of our ailing friends starts to put strain on our bond with them. There are times when changes to their condition become incompatible with their home environment. And there are times when the money to treat them simply isn't there.",
        builder: _buildOwnerStateStep,
      ),
      _AssessmentStep(
        id: "results",
        title: "Assessment Results",
        description:
            "Thank you for seeing this assessment to the end. We understand that it asks a lot during an uncertain time, but we hope that it has provided you with some clarity.\n\n"
            "Your thoughtful answers have generated two scores: a Heart Score and a Condition Score. Below are descriptions of what each score is meant to measure and what your score ranges might contextually mean for ${widget.petName}.",
        builder: _buildResultsStep,
      ),
    ];
  }

  // ---------------------------
  // Navigation & step flow
  // ---------------------------

  int _indexOfStep(String id) => _steps.indexWhere((s) => s.id == id);

  void _jumpToStep(String id) {
    final index = _indexOfStep(id);
    if (index < 0) return;
    FocusScope.of(context).unfocus();
    _pageController.jumpToPage(index);
  }

  void _goNext() {
    if (_currentPage >= _steps.length - 1) return;
    FocusScope.of(context).unfocus();
    _pageController.jumpToPage(_currentPage + 1);
  }

  void _goBack() {
    if (_currentPage <= 0) return;
    FocusScope.of(context).unfocus();
    _pageController.jumpToPage(_currentPage - 1);
  }

  String get _nextButtonLabel {
    final stepId = _steps[_currentPage].id;
    if (stepId == "overview") return "Review Results";
    if (stepId == "results") return "Save Assessment";
    return "Next";
  }

  bool get _isNextEnabled {
    if (_isSubmitting) return false;

    final stepId = _steps[_currentPage].id;
    if (stepId == "overview") return _isReadyForReview;

    return _isCurrentStepValid();
  }

  bool get _showProgressBar {
    final id = _steps[_currentPage].id;
    return id != "overview" && id != "results";
  }

  String get _currentPartTitle {
    final id = _steps[_currentPage].id;
    if (_initializeStepIds.contains(id)) return "Part 1 of 2";
    if (_updateStepIds.contains(id)) return "Part 2 of 2";
    return "";
  }

  String get _currentPartSubtitle {
    final id = _steps[_currentPage].id;
    if (_initializeStepIds.contains(id)) return "Background & Preferences";
    if (_updateStepIds.contains(id)) return "Recent Quality of Life";
    return "";
  }

  double get _partProgress {
    final id = _steps[_currentPage].id;

    if (_initializeStepIds.contains(id)) {
      final idx = _initializeStepsOnly.indexWhere((s) => s.id == id);
      if (idx < 0) return 0;
      return (idx + 1) / _initializeStepsOnly.length;
    }

    if (_updateStepIds.contains(id)) {
      final idx = _updateStepsOnly.indexWhere((s) => s.id == id);
      if (idx < 0) return 0;
      return (idx + 1) / _updateStepsOnly.length;
    }

    return 0;
  }

  String get _partProgressText {
    final id = _steps[_currentPage].id;

    if (_initializeStepIds.contains(id)) {
      final idx = _initializeStepsOnly.indexWhere((s) => s.id == id);
      if (idx < 0) return "";
      return "${idx + 1}/${_initializeStepsOnly.length}";
    }

    if (_updateStepIds.contains(id)) {
      final idx = _updateStepsOnly.indexWhere((s) => s.id == id);
      if (idx < 0) return "";
      return "${idx + 1}/${_updateStepsOnly.length}";
    }

    return "";
  }

  // ---------------------------
  // Derived state & answer helpers
  // ---------------------------

  bool get _hasPreviousInitializeData => _previousAnswers != null;

  bool get _hasStartedInitializePart {
    return _isInitializePartComplete ||
        _initializeStartKeys.any(_hasCurrentValue);
  }

  bool get _hasStartedUpdatePart {
    return _updateScoreKeys.any(_hasCurrentValue) ||
        _hasCurrentValue("food_relationship");
  }

  dynamic _prev(String key) => _previousAnswers?[key];

  String _prevText(String key) {
    final v = _prev(key);
    if (v == null) return "";
    return v.toString().trim();
  }

  int? _prevInt(String key) {
    final v = _prev(key);
    if (v is int) return v;
    if (v is num) return v.toInt();
    return null;
  }

  bool _hasCurrentValue(String key) {
    return _isNonEmptyValue(_answers[key]);
  }

  bool _isNonEmptyValue(dynamic v) {
    if (v == null) return false;
    if (v is String) return v.trim().isNotEmpty;
    if (v is Map) {
      return v.values.any((x) => _isNonEmptyValue(x));
    }
    if (v is List) {
      return v.any((e) => _isNonEmptyValue(e));
    }
    return true;
  }

  bool _hasText(String key) {
    return (_answers[key] ?? "").toString().trim().isNotEmpty;
  }

  bool _hasScore(String key) {
    return (_answers[key] as int?) != null;
  }

  List<String> _stringList(String key) {
    return (_answers[key] as List).map((e) => e.toString().trim()).toList();
  }

  bool _allFilled(List<String> values) {
    return values.every((e) => e.isNotEmpty);
  }

  bool get _joyItemsComplete {
    final joyItems = _answers["joy_items"] as List<Map<String, dynamic>>;
    return joyItems.every(
      (e) => ((e["status"] ?? "").toString().trim().isNotEmpty),
    );
  }

  String _previousScoreText(String scoreKey, String explanationKey) {
    final score = _prevInt(scoreKey);
    if (score == null) return "";

    final explanation = _prevText(explanationKey);
    if (explanation.isEmpty) return "$score / 10";

    return "$score / 10 ($explanation)";
  }

  List<String> _favoriteThingsAll() {
    final petThings = _stringList(
      "favorite_pet_things",
    ).where((e) => e.isNotEmpty).toList();

    final sharedThings = _stringList(
      "favorite_shared_things",
    ).where((e) => e.isNotEmpty).toList();

    return [...petThings, ...sharedThings];
  }

  void _syncJoyItemsFromFavorites() {
    final all = _favoriteThingsAll();
    _answers["joy_items"] = List.generate(5, (index) {
      return {"label": index < all.length ? all[index] : "", "status": ""};
    });
  }

  bool _joyConcern() {
    final joyItems = _answers["joy_items"] as List<Map<String, dynamic>>;
    if (joyItems.any((e) => ((e["status"] ?? "").toString().trim().isEmpty))) {
      return false;
    }
    final noLongerEnjoysCount = joyItems
        .where((e) => e["status"] == "No Longer Enjoys")
        .length;
    return noLongerEnjoysCount >= 3;
  }

  Widget _helperText(String text) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7F0),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE7D3C3)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          height: 1.5,
          color: Color(0xFF5F5147),
        ),
      ),
    );
  }

  Widget _buildPreviousScoreNote({
    required int? currentScore,
    required String scoreKey,
    required String explanationKey,
  }) {
    final previousScore = _prevInt(scoreKey);
    if (currentScore == null || previousScore == null) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        const SizedBox(height: 10),
        _PreviousAnswerNote(
          label: "Previous score",
          value: _previousScoreText(scoreKey, explanationKey),
        ),
      ],
    );
  }

  Widget _buildExplanationField({
    required String title,
    required String answerKey,
    String description =
        "Tell us a bit about why you gave the score you gave...",
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        _FieldTitle(title, description: description),
        const SizedBox(height: 10),
        _TextAnswerField(
          initialValue: _answers[answerKey],
          minLines: 4,
          maxLines: 6,
          onChanged: (v) => _answers[answerKey] = v,
        ),
      ],
    );
  }

  // ---------------------------
  // Score calculation & interpretation
  // ---------------------------

  int _heartScore() {
    final infoScore = _answers["preference_info"] == "More Information" ? 1 : 0;

    int pursuitScore = 0;
    switch (_answers["which_best_describes_you"]) {
      case "Do All the Things!":
        pursuitScore = 3;
        break;
      case "One Step at a Time":
        pursuitScore = 2;
        break;
      case "Wait and See":
        pursuitScore = 1;
        break;
      default:
        pursuitScore = 0;
    }

    int txScore = 0;
    switch (_answers["pet_tolerance"]) {
      case "Anything Goes":
        txScore = 3;
        break;
      case "Limited Pokes":
        txScore = 1;
        break;
      default:
        txScore = 0;
    }

    final medScore = _answers["medicine_success"] == "Not happening" ? 0 : 1;
    final foodAversionScore =
        _answers["food_relationship"] == "Eats all the food" ? 1 : 0;

    return infoScore + pursuitScore + txScore + medScore + foodAversionScore;
  }

  int _joyScore() {
    final joyItems = _answers["joy_items"] as List<Map<String, dynamic>>;
    int total = 0;
    for (final item in joyItems) {
      if ((item["status"] ?? "") == "Continues to Enjoy") total += 6;
    }
    return total;
  }

  int _conditionScore() {
    return ((_answers["physical_score"] as int?) ?? 0) +
        ((_answers["appetite_score"] as int?) ?? 0) +
        ((_answers["hydration_score"] as int?) ?? 0) +
        ((_answers["mobility_score"] as int?) ?? 0) +
        ((_answers["cleanliness_score"] as int?) ?? 0) +
        ((_answers["state_of_mind_score"] as int?) ?? 0) +
        _joyScore() +
        ((_answers["owner_state_score"] as int?) ?? 0);
  }

  bool _hasSignificantlyChallengedFlag() {
    final ratings = [
      (_answers["physical_score"] as int?) ?? 0,
      (_answers["appetite_score"] as int?) ?? 0,
      (_answers["hydration_score"] as int?) ?? 0,
      (_answers["mobility_score"] as int?) ?? 0,
      (_answers["cleanliness_score"] as int?) ?? 0,
      (_answers["state_of_mind_score"] as int?) ?? 0,
      (_answers["owner_state_score"] as int?) ?? 0,
    ];
    return ratings.any((e) => e <= 2 && e > 0);
  }

  String _heartScoreRangeTitle(int score) {
    if (score >= 6) return "Heart Score Range: 6-10";
    if (score >= 3) return "Heart Score Range: 3-5";
    return "Heart Score Range: 0-2";
  }

  String _heartScoreRangeText(int score) {
    if (score >= 6) {
      return "We have tools in our toolbox to help slow and mitigate some of the changes associated with age or some forms of disease, even if we don't have any that completely stop those processes.\n\n"
          "Based on your responses, ${widget.petName} may be a candidate for the pursuit of additional lines of treatment to improve the quality of this stage of their life. That doesn't mean that every situation is appropriate to pursue new avenues of care, but under the guidance of your White Whiskers Care Team, there may be more that we can do for ${widget.petName}.";
    }
    if (score >= 3) {
      return "We have tools in our toolbox to help slow and mitigate some of the changes associated with age or some forms of disease, even if we don't have any that completely stop those processes.\n\n"
          "Based on your responses, with some creativity, there may be some options for ${widget.petName} that haven't yet been considered. At this score, we want to focus on comfort for both you and ${widget.petName} with the understanding that a measured approach is a better fit for your family. We want to never lose sight of our mission to make things as good as they can be for each family's situation.";
    }
    return "Based on your responses, the pursuit of treatment for ${widget.petName} isn't feasible at this time. This is often the case for our animals who consider the treatment to be as bad if not worse than the disease. We can also reach a point as care givers where we don't have the resources to give more than we already have.\n\n"
        "Each situation is unique. Each animal and owner have their own path forward. We will help you find yours and help to ensure that this time with ${widget.petName} is as good as it can be.";
  }

  String _conditionScoreRangeTitle(int score) {
    final challenged =
        score >= 30 && score <= 90 && _hasSignificantlyChallengedFlag();

    if (score < 30) return "Condition Score Range: <30";
    if (challenged) {
      return "Condition Score Range: 30-90, but significantly challenged";
    }
    if (score > 60) return "Condition Score Range: >60";
    return "Condition Score Range: 30-60";
  }

  String _conditionScoreRangeText(int score) {
    final challenged =
        score >= 30 && score <= 90 && _hasSignificantlyChallengedFlag();

    if (score < 30) {
      return "We are never ready to say goodbye and we never want to rob them of those good days. It's important, however, that we not hold on so tightly that we cross the threshold of distress with them.\n\n"
          "${widget.petName} is nearing that time when our options are few and our time is likely limited. As hard as it is to let them go, know that helping them pass with tranquility and peace is an act of love. When the time is right, we can help you give ${widget.petName} that gift.\n\n"
          "None of us at White Whiskers have ever had the honor to call ourselves ${widget.petName}'s owners, but we have all loved and lost our own special friends. We understand how hard this time is and we're here to help.\n\n"
          "Call Now: (719) 799-6670";
    }

    if (challenged) {
      return "In a perfect world, our aging pets pass seamlessly in their sleep from a failing mind and body after a good day of play and love and all of their favorite things. All too often, that's not the case and it's only one system that's failing while others are still trucking along.\n\n"
          "Within at least one of your answers, you selected a 1 or a 2 score which means that somewhere along the line you pin pointed something that is causing you or ${widget.petName} significant distress. Sometimes it's not a whole picture. It's just one incompatible problem that we need to address. Sometimes that problem can be fixed. Sometimes it can't. In either case we can help you better contextualize that problem, see if there are options to address it that work for your family, or help you understand that just one '1' score on this list can be enough to offer them release.\n\n"
          "We're here to help.\n\n"
          "Call Now: (719) 799-6670";
    }

    if (score > 60) {
      return "Not every scoring system is perfect, but your score suggests that we still have options to improve ${widget.petName}'s quality of life and to give you more good days to share with your friend.\n\n"
          "Call us today for a consultation on how we can help ${widget.petName}'s golden years really shine with a Sunrise Visit.\n\n"
          "Call Now: (719) 799 - 6670";
    }

    return "In spite of the challenges ${widget.petName} is facing, there may be adjustments we can make to improve their quality of life to a point where you can have more time with them.\n\n"
        "Your score places you in a grey zone that is best aided by a physical examination. Contact us today to schedule a Crossroads Visit with our doctor who will help you to be the best advocate for ${widget.petName} as you can be.\n\n"
        "Crossroads Visits can seamlessly be converted to a Sunrise Visit for planning and treatment or to a Sunset Visit should we decide that the most loving way to help ${widget.petName} is to let them go. In either case, we will help you every step of the way to ensure that you have that critical peace of mind in your decision.\n\n"
        "Call Now: (719) 799 - 6670";
  }

  // ---------------------------
  // Validation
  // ---------------------------

  bool get _isInitializePartComplete {
    final petThings = _stringList("favorite_pet_things");
    final sharedThings = _stringList("favorite_shared_things");
    final concerns = _stringList("biggest_concerns");

    final needsOther = concerns.contains("Other");

    return _allFilled(petThings) &&
        _allFilled(sharedThings) &&
        concerns.isNotEmpty &&
        (!needsOther || _hasText("other_concern_text")) &&
        _hasText("concerns_expand") &&
        _hasText("concern_duration") &&
        _hasText("last_30_days") &&
        _hasText("boundaries") &&
        _hasText("preference_info") &&
        _hasText("which_best_describes_you") &&
        _hasText("pet_tolerance") &&
        _hasText("medicine_success");
  }

  bool get _isUpdatePartComplete {
    return _updateScoreKeys.every(_hasScore) &&
        _hasText("food_relationship") &&
        _joyItemsComplete;
  }

  bool get _isReadyForReview =>
      _isInitializePartComplete && _isUpdatePartComplete;

  bool _isCurrentStepValid() {
    final stepId = _steps[_currentPage].id;

    switch (stepId) {
      case "overview":
        return _isUpdatePartComplete;

      case "intro_favorites":
        return _allFilled(_stringList("favorite_pet_things")) &&
            _allFilled(_stringList("favorite_shared_things"));

      case "concerns":
        final selected = _stringList("biggest_concerns");
        final needsOther = selected.contains("Other");
        return selected.isNotEmpty &&
            (!needsOther || _hasText("other_concern_text")) &&
            _hasText("concerns_expand") &&
            _hasText("concern_duration") &&
            _hasText("last_30_days");

      case "boundaries":
        return _hasText("boundaries");

      case "describe_yourself":
        return _hasText("preference_info") &&
            _hasText("which_best_describes_you");

      case "describe_pet":
        return _hasText("pet_tolerance") && _hasText("medicine_success");

      case "physical_condition":
        return _hasScore("physical_score");

      case "appetite":
        return _hasScore("appetite_score") && _hasText("food_relationship");

      case "water_intake":
        return _hasScore("hydration_score");

      case "mobility":
        return _hasScore("mobility_score");

      case "hygiene":
        return _hasScore("cleanliness_score");

      case "state_of_mind":
        return _hasScore("state_of_mind_score");

      case "joy":
        return _joyItemsComplete;

      case "owner_state":
        return _hasScore("owner_state_score");

      case "results":
        return true;

      default:
        return true;
    }
  }

  // ---------------------------
  // API payload & submission
  // ---------------------------

  Map<String, dynamic> _buildAssessmentPayload() {
    return {
      "pet": widget.petId,
      "answers": {
        "favorite_pet_things": List<String>.from(
          _answers["favorite_pet_things"] as List,
        ),
        "favorite_shared_things": List<String>.from(
          _answers["favorite_shared_things"] as List,
        ),
        "biggest_concerns": List<String>.from(
          _answers["biggest_concerns"] as List,
        ),
        "other_concern_text": _answers["other_concern_text"],
        "concerns_expand": _answers["concerns_expand"],
        "concern_duration": _answers["concern_duration"],
        "last_30_days": _answers["last_30_days"],
        "boundaries": _answers["boundaries"],
        "preference_info": _answers["preference_info"],
        "which_best_describes_you": _answers["which_best_describes_you"],
        "pet_tolerance": _answers["pet_tolerance"],
        "medicine_success": _answers["medicine_success"],
        "physical_score": _answers["physical_score"],
        "physical_explanation": _answers["physical_explanation"],
        "appetite_score": _answers["appetite_score"],
        "appetite_explanation": _answers["appetite_explanation"],
        "food_relationship": _answers["food_relationship"],
        "hydration_score": _answers["hydration_score"],
        "hydration_explanation": _answers["hydration_explanation"],
        "mobility_score": _answers["mobility_score"],
        "mobility_explanation": _answers["mobility_explanation"],
        "cleanliness_score": _answers["cleanliness_score"],
        "cleanliness_explanation": _answers["cleanliness_explanation"],
        "state_of_mind_score": _answers["state_of_mind_score"],
        "state_of_mind_explanation": _answers["state_of_mind_explanation"],
        "joy_items": List<Map<String, dynamic>>.from(
          (_answers["joy_items"] as List).map(
            (e) => Map<String, dynamic>.from(e as Map),
          ),
        ),
        "joy_explanation": _answers["joy_explanation"],
        "owner_state_score": _answers["owner_state_score"],
        "owner_state_explanation": _answers["owner_state_explanation"],
      },
      "heart_score": _heartScore(),
      "condition_score": _conditionScore(),
      "significantly_challenged": _hasSignificantlyChallengedFlag(),
    };
  }

  void _goToMyPetInAppShell() {
    selectedTabNotifier.value = AppTab.myPet;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AppShell()),
      (route) => false,
    );
  }

  Future<void> _submitAssessment() async {
    if (_isSubmitting) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      await AssessmentApi.createAssessment(body: _buildAssessmentPayload());

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Assessment saved.")));

      _goToMyPetInAppShell();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Failed to save assessment: $e")));
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  // ---------------------------
  // Page scaffold
  // ---------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F5),
      appBar: AppBar(
        title: const Text("Assessment"),
        backgroundColor: const Color(0xFFFAF7F5),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_currentPage == 0) {
              Navigator.of(context).pop();
            } else {
              _jumpToStep("overview");
            }
          },
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (_showProgressBar)
              _TopProgressBar(
                progress: _partProgress,
                percentText: _partProgressText,
                partTitle: _currentPartTitle,
                partSubtitle: _currentPartSubtitle,
              ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _steps.length,
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                },
                itemBuilder: (context, index) {
                  final s = _steps[index];
                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _StepHeader(title: s.title, description: s.description),
                        const SizedBox(height: 20),
                        s.builder(context),
                      ],
                    ),
                  );
                },
              ),
            ),
            _BottomNavBar(
              canGoBack: _currentPage > 0,
              isLast: _steps[_currentPage].id == "results",
              isLoading: _isSubmitting,
              nextLabel: _nextButtonLabel,
              nextEnabled: _isNextEnabled,
              onBack: () {
                if (_steps[_currentPage].id == "results") {
                  _jumpToStep("overview");
                  return;
                }
                if (_currentPage == 0) return;
                _goBack();
              },
              onNext: () {
                final stepId = _steps[_currentPage].id;

                if (stepId == "overview") {
                  if (_isReadyForReview) {
                    _jumpToStep("results");
                  }
                  return;
                }

                if (stepId == "results") {
                  _submitAssessment();
                  return;
                }

                if (stepId == "intro_favorites") {
                  _syncJoyItemsFromFavorites();
                }

                if (stepId == "owner_state") {
                  _jumpToStep("overview");
                  return;
                }

                _goNext();
              },
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------
  // Step content builders
  // ---------------------------

  Widget _buildOverviewStep(BuildContext context) {
    if (_isLoadingPrevious) {
      return const Padding(
        padding: EdgeInsets.only(top: 40),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final backgroundSubtitle = !_hasStartedInitializePart
        ? "Needs setup"
        : (_isInitializePartComplete ? "Ready for review" : "In progress");

    final backgroundStatusColor = !_hasPreviousInitializeData
        ? (_hasStartedInitializePart
              ? (_isInitializePartComplete
                    ? const Color(0xFF2E8B57)
                    : const Color(0xFFD88442))
              : const Color(0xFF8C6F61))
        : const Color(0xFF2E8B57);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "This assessment has two parts. Background and preferences can be reviewed and edited. Recent condition and quality of life should be filled in fresh.",
          style: TextStyle(fontSize: 15, height: 1.5, color: Color(0xFF6A5B52)),
        ),
        const SizedBox(height: 24),
        _SectionCard(
          title: "Background & Preferences",
          subtitle: backgroundSubtitle,
          trailingLabel: _hasStartedInitializePart || _hasPreviousInitializeData
              ? "Edit"
              : "Start",
          statusColor: backgroundStatusColor,
          onTap: () => _jumpToStep("intro_favorites"),
        ),
        const SizedBox(height: 14),
        _SectionCard(
          title: "Recent Quality of Life",
          subtitle: _hasStartedUpdatePart
              ? (_isUpdatePartComplete ? "Ready for review" : "In progress")
              : "Needs input",
          trailingLabel: _hasStartedUpdatePart ? "Edit" : "Start",
          statusColor: _isUpdatePartComplete
              ? const Color(0xFF2E8B57)
              : _hasStartedUpdatePart
              ? const Color(0xFFD88442)
              : const Color(0xFF8C6F61),
          onTap: () => _jumpToStep("physical_condition"),
        ),
      ],
    );
  }

  Widget _buildFavoritesStep(BuildContext context) {
    final petThings = _answers["favorite_pet_things"] as List<String>;
    final sharedThings = _answers["favorite_shared_things"] as List<String>;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldTitle("What are ${widget.petName}’s 3 favorite things?"),
        const SizedBox(height: 12),
        for (int i = 0; i < 3; i++) ...[
          _TextAnswerField(
            initialValue: petThings[i],
            hintText: "Favorite thing ${i + 1}",
            onChanged: (v) => setState(() {
              petThings[i] = v;
            }),
          ),
          const SizedBox(height: 12),
        ],
        const SizedBox(height: 10),
        _FieldTitle(
          "What are your 2 favorite things you share with ${widget.petName}?",
        ),
        const SizedBox(height: 12),
        for (int i = 0; i < 2; i++) ...[
          _TextAnswerField(
            initialValue: sharedThings[i],
            hintText: "Shared favorite ${i + 1}",
            onChanged: (v) => setState(() {
              sharedThings[i] = v;
            }),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _buildConcernsStep(BuildContext context) {
    const options = [
      "Pain and Mobility",
      "Cognitive Decline",
      "Quality of Life",
      "Other",
    ];

    final selected = _answers["biggest_concerns"] as List<String>;
    final showOther = selected.contains("Other");

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _MultiChoiceGroup(
          options: options,
          selected: selected,
          onChanged: (v) => setState(() => _answers["biggest_concerns"] = v),
        ),
        if (showOther) ...[
          const SizedBox(height: 14),
          _TextAnswerField(
            initialValue: _answers["other_concern_text"],
            hintText: "Please specify",
            onChanged: (v) =>
                setState(() => _answers["other_concern_text"] = v),
          ),
        ],
        const SizedBox(height: 24),
        _FieldTitle(
          "Can you expand upon your primary concerns for ${widget.petName}?",
        ),
        const SizedBox(height: 10),
        _TextAnswerField(
          initialValue: _answers["concerns_expand"],
          minLines: 4,
          maxLines: 6,
          onChanged: (v) => setState(() => _answers["concerns_expand"] = v),
        ),
        const SizedBox(height: 24),
        _FieldTitle("How long has it been going on?"),
        const SizedBox(height: 10),
        _SingleChoiceGroup(
          value: _answers["concern_duration"],
          options: const [
            "A few days",
            "1 - 2 weeks",
            "2 - 4 weeks",
            "1 - 3 months",
            "Long enough",
            "Far too long (years)",
          ],
          onChanged: (v) => setState(() => _answers["concern_duration"] = v),
        ),
        const SizedBox(height: 24),
        _FieldTitle("In the last 30 days there have been more..."),
        const SizedBox(height: 10),
        _SingleChoiceGroup(
          value: _answers["last_30_days"],
          options: const ["Good Days", "Bad Days"],
          onChanged: (v) => setState(() => _answers["last_30_days"] = v),
        ),
      ],
    );
  }

  Widget _buildBoundariesStep(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldTitle("Where are your boundaries for ${widget.petName}?"),
        const SizedBox(height: 10),
        _TextAnswerField(
          initialValue: _answers["boundaries"],
          minLines: 6,
          maxLines: 8,
          onChanged: (v) => setState(() {
            _answers["boundaries"] = v;
          }),
        ),
      ],
    );
  }

  Widget _buildDescribeYourselfStep(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldTitle(
          "Which best describes your preference?",
          description:
              "You aren't expected to know all the things. That's our job. Information can make some people more comfortable, others less. Your comfort matters and this helps us tailor your experience to what's right for you.",
        ),
        const SizedBox(height: 10),
        _SingleChoiceGroup(
          value: _answers["preference_info"],
          options: const ["More Information", "Less Information"],
          onChanged: (v) => setState(() => _answers["preference_info"] = v),
        ),
        const SizedBox(height: 24),
        _FieldTitle("Which best describes you?"),
        const SizedBox(height: 10),
        _LongOptionCards(
          value: _answers["which_best_describes_you"],
          options: const [
            _OptionWithDescription(
              title: "Do All the Things!",
              description:
                  "You have the time and resources to build a medical team, but you need help managing and translating findings.",
            ),
            _OptionWithDescription(
              title: "One Step at a Time",
              description:
                  "You want to pursue an active approach, but there is a line too far. Let's take things one step at a time to limit the strain on both you and your pet.",
            ),
            _OptionWithDescription(
              title: "Wait and See",
              description:
                  "Running diagnostics or pursuing treatments aren't right for you in this situation, but neither you nor your pet have crossed over that line that seems to necessitate intervention yet. Still, you would like guidance to ensure that your pet doesn't struggle.",
            ),
            _OptionWithDescription(
              title: "Seeking Peace of Mind",
              description:
                  "Treatments aren't right for you or your pet and you're concerned that we've already slipped too far. You're leaning towards needing to help your pet pass on, but guidance would help give you peace of mind.",
            ),
          ],
          onChanged: (v) =>
              setState(() => _answers["which_best_describes_you"] = v),
        ),
      ],
    );
  }

  Widget _buildDescribePetStep(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldTitle("Which best describes ${widget.petName}?"),
        const SizedBox(height: 10),
        _SingleChoiceGroup(
          value: _answers["pet_tolerance"],
          options: const ["Anything Goes", "Limited Pokes", "Hands Off!"],
          onChanged: (v) => setState(() => _answers["pet_tolerance"] = v),
        ),
        const SizedBox(height: 24),
        _FieldTitle(
          "How would you rate your success in the past at giving ${widget.petName} medicines?",
        ),
        const SizedBox(height: 10),
        _SingleChoiceGroup(
          value: _answers["medicine_success"],
          options: const [
            "Not a problem",
            "Challenging, but doable",
            "Not happening",
          ],
          onChanged: (v) => setState(() => _answers["medicine_success"] = v),
        ),
      ],
    );
  }

  Widget _buildPhysicalConditionStep(BuildContext context) {
    final int? score = _answers["physical_score"] as int?;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _RatingBlock(
          prompt:
              "On a scale of 1–10, rate ${widget.petName}'s physical condition.",
          score: score,
          leftLabel: "1 (worst)",
          rightLabel: "10 (best)",
          details:
              "For reference and consideration (rated most important to least):\n- Respiration (Breathing)\n- Pain (Difficult to assess in stoic pets)\n- Tumors/Cancer\n- Wounds/Infections",
          onChanged: (v) => setState(() => _answers["physical_score"] = v),
        ),
        _buildPreviousScoreNote(
          currentScore: score,
          scoreKey: "physical_score",
          explanationKey: "physical_explanation",
        ),
        if (score != null && score <= 5)
          _helperText(
            "An inability to properly breathe should be considered a veterinary emergency. If you feel that ${widget.petName} is having labored breathing, please call us right away or reach out to your nearest emergency veterinary clinic.\n\n"
            "(719) 799-6670\n\n"
            "Many of our pets are programmed to hide their discomfort rather than communicate it to us although this can vary from pet to pet. When that discomfort has moved beyond the threshold of their ability to hide it, we are called on to form actionable plans to improve their situation. If you feel that ${widget.petName} is experiencing pain or discomfort, we may be able to help. There comes a time, however, when that discomfort outpaces our tools to control it. When that happens, it becomes time to talk about alternative forms of help.\n\n"
            "A diagnosis of a tumor, or worse, cancer, is almost always frightening. The prognosis and personal experience of having this broad category of diseases can vary wildly depending on the specific diagnosis and your animal. We can help guide you through better understanding what this diagnosis means and how we can best be an advocate for your pet.",
          ),
        _buildExplanationField(
          title: "Physical Score Explanation",
          answerKey: "physical_explanation",
        ),
      ],
    );
  }

  Widget _buildAppetiteStep(BuildContext context) {
    final int? score = _answers["appetite_score"] as int?;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _RatingBlock(
          prompt: "On a scale of 1–10, rate ${widget.petName}'s appetite.",
          score: score,
          leftLabel: "1 (abnormal)",
          rightLabel: "10 (normal)",
          details:
              "Abnormal appetite could mean excessive hunger or refusal to eat.",
          onChanged: (v) => setState(() => _answers["appetite_score"] = v),
        ),
        _buildPreviousScoreNote(
          currentScore: score,
          scoreKey: "appetite_score",
          explanationKey: "appetite_explanation",
        ),
        if (score != null)
          _helperText(
            "It's important to understand the limitations of this metric. There are animals whose food motivation transcends the greatest of discomforts and there are animals who stop eating for reasons that we may be able to address. In either case, we begin with a conversation and from there seek to give you the best guidance we can to access exactly the kind of care that ${widget.petName} needs.",
          ),
        const SizedBox(height: 24),
        _FieldTitle(
          "How would you describe ${widget.petName}'s relationship with food these days?",
        ),
        const SizedBox(height: 10),
        _SingleChoiceGroup(
          value: _answers["food_relationship"],
          options: const ["Eats all the food", "Picky and discerning"],
          onChanged: (v) => setState(() => _answers["food_relationship"] = v),
        ),
        _buildExplanationField(
          title: "Appetite Score Explanation",
          answerKey: "appetite_explanation",
        ),
      ],
    );
  }

  Widget _buildHydrationStep(BuildContext context) {
    final int? score = _answers["hydration_score"] as int?;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _RatingBlock(
          prompt:
              "On a scale of 1–10, rate ${widget.petName}'s hydration status.",
          score: score,
          leftLabel: "1 (abnormal)",
          rightLabel: "10 (normal)",
          details:
              "Abnormal water intake could mean excessive thirst or refusal to drink.",
          onChanged: (v) => setState(() => _answers["hydration_score"] = v),
        ),
        _buildPreviousScoreNote(
          currentScore: score,
          scoreKey: "hydration_score",
          explanationKey: "hydration_explanation",
        ),
        if (score != null)
          _helperText(
            "Our pets can unexpectedly start drinking excess water or very little water for a variety of reasons. Sudden changes in whether the water bowl empties too quickly or doesn't empty at all can give us hints about what's going on internally with ${widget.petName}. Likewise, sudden, consistent changes to ${widget.petName}'s urine output can give us a snapshot of their kidney health. Like with our appetite, drinking too much can be as much of a signifier that something is wrong as drinking too little. Don't worry, we'll figure it out together.",
          ),
        _buildExplanationField(
          title: "Hydration Score Explanation",
          answerKey: "hydration_explanation",
        ),
      ],
    );
  }

  Widget _buildMobilityStep(BuildContext context) {
    final int? score = _answers["mobility_score"] as int?;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _RatingBlock(
          prompt: "On a scale of 1–10, rate ${widget.petName}'s mobility.",
          score: score,
          leftLabel: "1 (worst)",
          rightLabel: "10 (best)",
          onChanged: (v) => setState(() => _answers["mobility_score"] = v),
        ),
        _buildPreviousScoreNote(
          currentScore: score,
          scoreKey: "mobility_score",
          explanationKey: "mobility_explanation",
        ),
        _buildExplanationField(
          title: "Mobility Score Explanation",
          answerKey: "mobility_explanation",
        ),
      ],
    );
  }

  Widget _buildCleanlinessStep(BuildContext context) {
    final int? score = _answers["cleanliness_score"] as int?;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _RatingBlock(
          prompt:
              "On a scale of 1–10, rate ${widget.petName}'s physical cleanliness.",
          score: score,
          leftLabel: "1 (worst)",
          rightLabel: "10 (best)",
          onChanged: (v) => setState(() => _answers["cleanliness_score"] = v),
        ),
        _buildPreviousScoreNote(
          currentScore: score,
          scoreKey: "cleanliness_score",
          explanationKey: "cleanliness_explanation",
        ),
        if (score != null && score <= 5)
          _helperText(
            "As our pets age, they can lose both physical control and sensation over their ability to eliminate. This can result in an otherwise proud and disciplined pet, eliminating in the house. Mobility or cognitive challenges can also impede a senior pet's ability to alert their owner to their needs or access proper elimination locations in a timely or successful manner. This can include litterboxes that were once accessible but no longer suitable or stairs to potty spots that are now too challenging to navigate. This isn't their fault, but the challenges that they face aren't always obvious to us at first glance. If ${widget.petName} is having difficulty with elimination or hygiene, there may be things we can do to help.",
          ),
        _buildExplanationField(
          title: "Cleanliness Score Explanation",
          answerKey: "cleanliness_explanation",
        ),
      ],
    );
  }

  Widget _buildStateOfMindStep(BuildContext context) {
    final int? score = _answers["state_of_mind_score"] as int?;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _RatingBlock(
          prompt: "On a scale of 1–10, rate ${widget.petName}'s state of mind.",
          score: score,
          leftLabel: "1 (worst)",
          rightLabel: "10 (best)",
          onChanged: (v) => setState(() => _answers["state_of_mind_score"] = v),
        ),
        _buildPreviousScoreNote(
          currentScore: score,
          scoreKey: "state_of_mind_score",
          explanationKey: "state_of_mind_explanation",
        ),
        if (score != null && score <= 5)
          _helperText(
            "It can be so hard to feel your pet mentally slip away from you even before they physically slip away from you. It can even test the loving bond that you've developed with your pet over the time you both have shared.\n\n"
            "Cognitive decline, whatever the cause, can be a prison of anxiety and confusion for our pets whether or not they are being challenged physically. However, all too often we can feel deep guilt over discussing quality of life options when our pets' bodies don't raise the same concern as their minds. Cognition and state of mind is a critical component to the quality of life of our pets who live in the moment and for today. If you feel as though ${widget.petName} has undergone significant cognitive change, it's never too early to have a discussion about how we might be able to help.",
          ),
        _buildExplanationField(
          title: "Cognition Score Explanation",
          answerKey: "state_of_mind_explanation",
        ),
      ],
    );
  }

  Widget _buildJoyStep(BuildContext context) {
    final joyItems = _answers["joy_items"] as List<Map<String, dynamic>>;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < joyItems.length; i++) ...[
          _JoyItemCard(
            label: (joyItems[i]["label"] ?? "").toString().trim().isEmpty
                ? "Favorite activity ${i + 1}"
                : joyItems[i]["label"].toString(),
            value: (joyItems[i]["status"] ?? "").toString(),
            onChanged: (v) => setState(() => joyItems[i]["status"] = v),
          ),
          const SizedBox(height: 12),
        ],
        if (_joyConcern()) ...[
          const SizedBox(height: 2),
          _helperText(
            "${widget.petName} is starting to lose touch with some of those favorite things. Understanding that a quality of life extends to mind, body AND spirit is important in this process. While favorites aren't end all be all, they make up a significant portion of our pets' day to day joy. The burden of losing that joy can be significant. That said, even if we have lost things just as we liked them, there may be substitutions that are also pretty fun too. We can help have that discussion.",
          ),
        ],
        const SizedBox(height: 12),
        _FieldTitle(
          "Joy Explanation",
          description:
              "Additional thoughts on ${widget.petName}'s daily joy...",
        ),
        const SizedBox(height: 10),
        _TextAnswerField(
          initialValue: _answers["joy_explanation"],
          minLines: 4,
          maxLines: 6,
          onChanged: (v) => _answers["joy_explanation"] = v,
        ),
      ],
    );
  }

  Widget _buildOwnerStateStep(BuildContext context) {
    final int? score = _answers["owner_state_score"] as int?;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _RatingBlock(
          prompt:
              "On a scale of 1–10, rate how you and your family are doing with ${widget.petName}'s changes.",
          score: score,
          leftLabel: "1 (worst)",
          rightLabel: "10 (best)",
          onChanged: (v) => setState(() => _answers["owner_state_score"] = v),
        ),
        _buildPreviousScoreNote(
          currentScore: score,
          scoreKey: "owner_state_score",
          explanationKey: "owner_state_explanation",
        ),
        if (score != null && score <= 6)
          _helperText(
            "This stage of life is often the most challenging as the burden of responsibility regarding end-of-life decisions weighs heavily on an owner's shoulders. We've loved them, often for the entire length of their lives. Admitting the rigors of this phase of your relationship to others and even to oneself can riddle many people with guilt.\n\n"
            "We want you to know that YOU matter. The BOND that you share with ${widget.petName} matters. When discussing quality of life, we are remiss to overlook such an important aspect of ${widget.petName}'s situation.\n\n"
            "We are here to help the both of you in every way that we can.",
          ),
        _buildExplanationField(
          title: "${widget.ownerName}'s Score Explanation",
          answerKey: "owner_state_explanation",
        ),
      ],
    );
  }

  Widget _buildResultsStep(BuildContext context) {
    final heart = _heartScore();
    final condition = _conditionScore();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ScoreCard(
          label: "Heart Score",
          score: "$heart / 10",
          subtitle: _heartScoreRangeTitle(heart),
          frontBody: _heartScoreRangeText(heart),
          backBody:
              "The Heart Score is an 10 point score that assesses the ability and desire both you and ${widget.petName} have for the pursuit of treatment. "
              "A high score suggests a readiness to pursue treatments for both you and your pet. Deciding NOT to pursue diagnostics or treatment IS AN OPTION "
              "and one that many are afraid to entertain. Treatment is a team effort and both you and ${widget.petName} have to be on board to make it a good experience. "
              "Never mistake having a low Heart Score as being a bad owner or giving up. But acknowledging where you both are on your journey together is an important consideration.",
        ),
        const SizedBox(height: 16),
        _ScoreCard(
          label: "Condition Score",
          score: "$condition / 100",
          subtitle: _conditionScoreRangeTitle(condition),
          frontBody: _conditionScoreRangeText(condition),
          backBody:
              "The Condition Score is a 100 point subjective assessment of ${widget.petName}'s mind and body at this point in time. "
              "It also considers how you're holding up as well. You are linked inextricably to ${widget.petName} and you carry so many of their burdens. "
              "It can be easy, as you work to support ${widget.petName}, to lose sight of the importance of your place in the human-animal bond. "
              "The Condition Score seeks to address the most important elements of an animal's quality of life as seen through mind, body and experience. "
              "When combined with an objective physical exam from your veterinarian, we hope this examination provides you with the very best tools for understanding "
              "the best path forward for you and ${widget.petName}.",
        ),
        const SizedBox(height: 24),
        const _MutedParagraph(
          "Keep in mind that this assessment is deeply subjective. Often times the scores on different categories can vary wildly between different members. That's ok. Also consider that this score is a combination of all the things. However, most often it's one critical quality of life component that is faltering. Sometimes it just takes the one thing to be enough.",
        ),
        const SizedBox(height: 12),
        const _MutedParagraph(
          "Remember: this is an assessment tool, not a decision.",
        ),
      ],
    );
  }
}

// ---------------------------
// Local models & small UI widgets
// ---------------------------

class _AssessmentStep {
  final String id;
  final String title;
  final String? description;
  final Widget Function(BuildContext context) builder;

  _AssessmentStep({
    required this.id,
    required this.title,
    required this.description,
    required this.builder,
  });
}

class _OptionWithDescription {
  final String title;
  final String description;

  const _OptionWithDescription({
    required this.title,
    required this.description,
  });
}

class _SectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String trailingLabel;
  final Color statusColor;
  final VoidCallback onTap;

  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.trailingLabel,
    required this.statusColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE9DDD3)),
        ),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: statusColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF3E3028),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF7B6D64),
                    ),
                  ),
                ],
              ),
            ),
            Text(
              trailingLabel,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFFD88442),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviousAnswerNote extends StatelessWidget {
  final String label;
  final String value;

  const _PreviousAnswerNote({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F1EC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE3D8CE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF8A7769),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              height: 1.45,
              color: Color(0xFF5E4E45),
            ),
          ),
        ],
      ),
    );
  }
}
