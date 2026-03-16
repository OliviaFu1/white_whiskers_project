import 'package:flutter/material.dart';
import '../../services/assessment_api.dart';
import '../app_shell.dart';

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
  String? _submitError;

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
    "physical_score": 5,
    "physical_explanation": "",
    "appetite_score": 5,
    "appetite_explanation": "",
    "food_relationship": "",
    "hydration_score": 5,
    "hydration_explanation": "",
    "mobility_score": 5,
    "mobility_explanation": "",
    "cleanliness_score": 5,
    "cleanliness_explanation": "",
    "behavior_change_notes": "",
    "state_of_mind_score": 5,
    "state_of_mind_explanation": "",
    "joy_items": <Map<String, dynamic>>[],
    "joy_explanation": "",
    "owner_state_score": 5,
    "owner_state_explanation": "",
  };

  List<_AssessmentStep> get _steps => _buildSteps();

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
  }

  List<_AssessmentStep> _buildSteps() {
    return [
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

  void _goNext() {
    if (_currentPage >= _steps.length - 1) return;
    FocusScope.of(context).unfocus();
    _pageController.nextPage(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  void _goBack() {
    if (_currentPage <= 0) return;
    FocusScope.of(context).unfocus();
    _pageController.previousPage(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  double get _progress {
    if (_steps.isEmpty) return 0;
    return (_currentPage + 1) / _steps.length;
  }

  List<String> _favoriteThingsAll() {
    final petThings = ((_answers["favorite_pet_things"] as List).map(
      (e) => e.toString().trim(),
    )).where((e) => e.isNotEmpty).toList();

    final sharedThings = ((_answers["favorite_shared_things"] as List).map(
      (e) => e.toString().trim(),
    )).where((e) => e.isNotEmpty).toList();

    return [...petThings, ...sharedThings];
  }

  void _syncJoyItemsFromFavorites() {
    final all = _favoriteThingsAll();
    final current = _answers["joy_items"] as List<Map<String, dynamic>>;
    _answers["joy_items"] = List.generate(5, (index) {
      final existingStatus = index < current.length
          ? (current[index]["status"] ?? "").toString()
          : "";
      return {
        "label": index < all.length ? all[index] : "",
        "status": existingStatus,
      };
    });
  }

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
    return (_answers["physical_score"] as int) +
        (_answers["appetite_score"] as int) +
        (_answers["hydration_score"] as int) +
        (_answers["mobility_score"] as int) +
        (_answers["cleanliness_score"] as int) +
        (_answers["state_of_mind_score"] as int) +
        _joyScore() +
        (_answers["owner_state_score"] as int);
  }

  bool _hasSignificantlyChallengedFlag() {
    final ratings = [
      _answers["physical_score"] as int,
      _answers["appetite_score"] as int,
      _answers["hydration_score"] as int,
      _answers["mobility_score"] as int,
      _answers["cleanliness_score"] as int,
      _answers["state_of_mind_score"] as int,
      _answers["owner_state_score"] as int,
    ];
    return ratings.any((e) => e <= 2);
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
    if (challenged) return "Condition Score Range: 30-90, but significantly challenged";
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
        "behavior_change_notes": _answers["behavior_change_notes"],
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
    };
  }

  Future<void> _submitAssessment() async {
    if (_isSubmitting) return;

    setState(() {
      _isSubmitting = true;
      _submitError = null;
    });

    try {
      final saved = await AssessmentApi.createAssessment(
        body: _buildAssessmentPayload(),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Assessment saved.")));

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AppShell()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _submitError = e.toString();
      });

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFFAF7F5),
      appBar: AppBar(
        title: const Text("Assessment"),
        backgroundColor: Color(0xFFFAF7F5),
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            _TopProgressBar(
              progress: _progress,
              percentText: "${(_progress * 100).round()}%",
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
              isLast: _currentPage == _steps.length - 1,
              isLoading: _isSubmitting,
              onBack: _goBack,
              onNext: () {
                if (_currentPage == _steps.length - 1) {
                  _submitAssessment();
                } else {
                  if (_steps[_currentPage].id == "intro_favorites") {
                    _syncJoyItemsFromFavorites();
                  }
                  _goNext();
                }
              },
            ),
          ],
        ),
      ),
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
            onChanged: (v) => petThings[i] = v,
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
            onChanged: (v) => sharedThings[i] = v,
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
            onChanged: (v) => _answers["other_concern_text"] = v,
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
          onChanged: (v) => _answers["concerns_expand"] = v,
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
          onChanged: (v) => _answers["boundaries"] = v,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _RatingBlock(
          prompt:
              "On a scale of 1–10, rate ${widget.petName}'s physical condition.",
          score: _answers["physical_score"],
          leftLabel: "1 (worst)",
          rightLabel: "10 (best)",
          details:
              "For reference and consideration (rated most important to least):\n- Respiration (Breathing)\n- Pain (Difficult to assess in stoic pets)\n- Tumors/Cancer\n- Wounds/Infections",
          onChanged: (v) => setState(() => _answers["physical_score"] = v),
        ),
        const SizedBox(height: 24),
        _FieldTitle(
          "Physical Score Explanation",
          description: "Tell us a bit about why you gave the score you gave...",
        ),
        const SizedBox(height: 10),
        _TextAnswerField(
          initialValue: _answers["physical_explanation"],
          minLines: 4,
          maxLines: 6,
          onChanged: (v) => _answers["physical_explanation"] = v,
        ),
      ],
    );
  }

  Widget _buildAppetiteStep(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _RatingBlock(
          prompt: "On a scale of 1–10, rate ${widget.petName}'s appetite.",
          score: _answers["appetite_score"],
          leftLabel: "1 (abnormal)",
          rightLabel: "10 (normal)",
          details:
              "Abnormal appetite could mean excessive hunger or refusal to eat.",
          onChanged: (v) => setState(() => _answers["appetite_score"] = v),
        ),
        const SizedBox(height: 24),
        _FieldTitle(
          "Appetite Score Explanation",
          description: "Tell us a bit about why you gave the score you gave...",
        ),
        const SizedBox(height: 10),
        _TextAnswerField(
          initialValue: _answers["appetite_explanation"],
          minLines: 4,
          maxLines: 6,
          onChanged: (v) => _answers["appetite_explanation"] = v,
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
      ],
    );
  }

  Widget _buildHydrationStep(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _RatingBlock(
          prompt:
              "On a scale of 1–10, rate ${widget.petName}'s hydration status.",
          score: _answers["hydration_score"],
          leftLabel: "1 (abnormal)",
          rightLabel: "10 (normal)",
          details:
              "Abnormal water intake could mean excessive thirst or refusal to drink.",
          onChanged: (v) => setState(() => _answers["hydration_score"] = v),
        ),
        const SizedBox(height: 24),
        _FieldTitle(
          "Hydration Score Explanation",
          description: "Tell us a bit about why you gave the score you gave...",
        ),
        const SizedBox(height: 10),
        _TextAnswerField(
          initialValue: _answers["hydration_explanation"],
          minLines: 4,
          maxLines: 6,
          onChanged: (v) => _answers["hydration_explanation"] = v,
        ),
      ],
    );
  }

  Widget _buildMobilityStep(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _RatingBlock(
          prompt: "On a scale of 1–10, rate ${widget.petName}'s mobility.",
          score: _answers["mobility_score"],
          leftLabel: "1 (worst)",
          rightLabel: "10 (best)",
          onChanged: (v) => setState(() => _answers["mobility_score"] = v),
        ),
        const SizedBox(height: 24),
        _FieldTitle(
          "Mobility Score Explanation",
          description: "Tell us a bit about why you gave the score you gave...",
        ),
        const SizedBox(height: 10),
        _TextAnswerField(
          initialValue: _answers["mobility_explanation"],
          minLines: 4,
          maxLines: 6,
          onChanged: (v) => _answers["mobility_explanation"] = v,
        ),
      ],
    );
  }

  Widget _buildCleanlinessStep(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _RatingBlock(
          prompt:
              "On a scale of 1–10, rate ${widget.petName}'s physical cleanliness.",
          score: _answers["cleanliness_score"],
          leftLabel: "1 (worst)",
          rightLabel: "10 (best)",
          onChanged: (v) => setState(() => _answers["cleanliness_score"] = v),
        ),
        const SizedBox(height: 24),
        _FieldTitle(
          "Cleanliness Score Explanation",
          description: "Tell us a bit about why you gave the score you gave...",
        ),
        const SizedBox(height: 10),
        _TextAnswerField(
          initialValue: _answers["cleanliness_explanation"],
          minLines: 4,
          maxLines: 6,
          onChanged: (v) => _answers["cleanliness_explanation"] = v,
        ),
      ],
    );
  }

  Widget _buildStateOfMindStep(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _RatingBlock(
          prompt: "On a scale of 1–10, rate ${widget.petName}'s state of mind.",
          score: _answers["state_of_mind_score"],
          leftLabel: "1 (worst)",
          rightLabel: "10 (best)",
          onChanged: (v) => setState(() => _answers["state_of_mind_score"] = v),
        ),
        const SizedBox(height: 24),
        _FieldTitle(
          "Cognition Score Explanation",
          description: "Tell us a bit about why you gave the score you gave...",
        ),
        const SizedBox(height: 10),
        _TextAnswerField(
          initialValue: _answers["state_of_mind_explanation"],
          minLines: 4,
          maxLines: 6,
          onChanged: (v) => _answers["state_of_mind_explanation"] = v,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _RatingBlock(
          prompt:
              "On a scale of 1–10, rate how you and your family are doing with ${widget.petName}'s changes.",
          score: _answers["owner_state_score"],
          leftLabel: "1 (worst)",
          rightLabel: "10 (best)",
          onChanged: (v) => setState(() => _answers["owner_state_score"] = v),
        ),
        const SizedBox(height: 24),
        _FieldTitle(
          "${widget.ownerName}'s Score Explanation",
          description: "Tell us a bit about why you gave the score you gave...",
        ),
        const SizedBox(height: 10),
        _TextAnswerField(
          initialValue: _answers["owner_state_explanation"],
          minLines: 4,
          maxLines: 6,
          onChanged: (v) => _answers["owner_state_explanation"] = v,
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

class _TopProgressBar extends StatelessWidget {
  final double progress;
  final String percentText;

  const _TopProgressBar({required this.progress, required this.percentText});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            percentText,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: const Color(0xFF6F625B),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: const Color(0xFFE7DDD7),
              valueColor: const AlwaysStoppedAnimation(Color(0xFF8B6B5C)),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepHeader extends StatelessWidget {
  final String title;
  final String? description;

  const _StepHeader({required this.title, required this.description});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            height: 1.25,
          ),
        ),
        if (description != null && description!.trim().isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            description!,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[700],
              height: 1.5,
            ),
          ),
        ],
      ],
    );
  }
}

class _FieldTitle extends StatelessWidget {
  final String title;
  final String? description;

  const _FieldTitle(this.title, {this.description});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            height: 1.3,
          ),
        ),
        if (description != null && description!.trim().isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            description!,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[700],
              height: 1.5,
            ),
          ),
        ],
      ],
    );
  }
}

class _TextAnswerField extends StatefulWidget {
  final String? initialValue;
  final String? hintText;
  final int minLines;
  final int maxLines;
  final ValueChanged<String> onChanged;

  const _TextAnswerField({
    required this.onChanged,
    this.initialValue,
    this.hintText,
    this.minLines = 1,
    this.maxLines = 1,
  });

  @override
  State<_TextAnswerField> createState() => _TextAnswerFieldState();
}

class _TextAnswerFieldState extends State<_TextAnswerField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue ?? "");
  }

  @override
  void didUpdateWidget(covariant _TextAnswerField oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newText = widget.initialValue ?? "";
    if (_controller.text != newText) _controller.text = newText;
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      minLines: widget.minLines,
      maxLines: widget.maxLines,
      onChanged: widget.onChanged,
      decoration: InputDecoration(
        hintText: widget.hintText,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
      ),
    );
  }
}

class _SingleChoiceGroup extends StatelessWidget {
  final String value;
  final List<String> options;
  final ValueChanged<String> onChanged;

  const _SingleChoiceGroup({
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    const selectedColor = Color(0xFFF1E2D8);
    const selectedBorder = Color(0xFF8B6B5C);

    return Column(
      children: options.map((option) {
        final selected = value == option;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: InkWell(
            onTap: () => onChanged(option),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: selected ? selectedBorder : Colors.grey.shade300,
                  width: selected ? 1.8 : 1,
                ),
                color: selected ? selectedColor : Colors.white,
              ),
              child: Text(
                option,
                style: TextStyle(
                  color: const Color(0xFF2F2A28),
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _MultiChoiceGroup extends StatelessWidget {
  final List<String> options;
  final List<String> selected;
  final ValueChanged<List<String>> onChanged;

  const _MultiChoiceGroup({
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    const selectedColor = Color(0xFFF1E2D8);
    const selectedBorder = Color(0xFF8B6B5C);
    const textColor = Color(0xFF2F2A28);

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: options.map((option) {
        final isSelected = selected.contains(option);
        return FilterChip(
          label: Text(
            option,
            style: const TextStyle(
              color: textColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          selected: isSelected,
          selectedColor: selectedColor,
          checkmarkColor: selectedBorder,
          side: BorderSide(
            color: isSelected ? selectedBorder : Colors.grey.shade300,
          ),
          backgroundColor: Colors.white,
          onSelected: (v) {
            final next = [...selected];
            if (v) {
              if (!next.contains(option)) next.add(option);
            } else {
              next.remove(option);
            }
            onChanged(next);
          },
        );
      }).toList(),
    );
  }
}

class _LongOptionCards extends StatelessWidget {
  final String value;
  final List<_OptionWithDescription> options;
  final ValueChanged<String> onChanged;

  const _LongOptionCards({
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    const selectedColor = Color(0xFFF1E2D8);
    const selectedBorder = Color(0xFF8B6B5C);

    return Column(
      children: options.map((opt) {
        final selected = value == opt.title;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            onTap: () => onChanged(opt.title),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: selected ? selectedBorder : Colors.grey.shade300,
                  width: selected ? 1.8 : 1,
                ),
                color: selected ? selectedColor : Colors.white,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    opt.title,
                    style: TextStyle(
                      color: const Color(0xFF2F2A28),
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    opt.description,
                    style: TextStyle(color: Colors.grey[800], height: 1.45),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _RatingBlock extends StatelessWidget {
  final String prompt;
  final String? details;
  final int score;
  final String leftLabel;
  final String rightLabel;
  final ValueChanged<int> onChanged;

  const _RatingBlock({
    required this.prompt,
    required this.score,
    required this.onChanged,
    required this.leftLabel,
    required this.rightLabel,
    this.details,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldTitle(prompt, description: details),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Colors.white,
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            children: [
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: const Color(0xFF8B6B5C),
                  inactiveTrackColor: const Color(0xFFE7DDD7),
                  thumbColor: const Color(0xFF8B6B5C),
                  overlayColor: const Color(0x338B6B5C),
                  trackHeight: 4,
                ),
                child: Slider(
                  value: score.toDouble(),
                  min: 1,
                  max: 10,
                  divisions: 9,
                  label: "$score",
                  onChanged: (v) => onChanged(v.round()),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(leftLabel, style: TextStyle(color: Colors.grey[700])),
                  Text(rightLabel, style: TextStyle(color: Colors.grey[700])),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                "Selected score: $score",
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _JoyItemCard extends StatelessWidget {
  final String label;
  final String value;
  final ValueChanged<String> onChanged;

  const _JoyItemCard({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
        color: Colors.white,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          _SingleChoiceGroup(
            value: value,
            options: const ["Continues to Enjoy", "No Longer Enjoys"],
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _ScoreCard extends StatefulWidget {
  final String label;
  final String? subtitle;
  final String? score;
  final String frontBody; // range explanation (default view)
  final String backBody; // score system explanation (tap view)

  const _ScoreCard({
    required this.label,
    required this.frontBody,
    required this.backBody,
    this.subtitle,
    this.score,
  });

  @override
  State<_ScoreCard> createState() => _ScoreCardState();
}

class _ScoreCardState extends State<_ScoreCard> {
  bool _showBack = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        setState(() => _showBack = !_showBack);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: Colors.white,
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.label,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),

            if (widget.subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                widget.subtitle!,
                style: TextStyle(
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],

            if (widget.score != null) ...[
              const SizedBox(height: 10),
              Text(
                widget.score!,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],

            const SizedBox(height: 12),

            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Text(
                _showBack ? widget.backBody : widget.frontBody,
                key: ValueKey(_showBack),
                style: TextStyle(color: Colors.grey[800], height: 1.55),
              ),
            ),

            const SizedBox(height: 10),
            Text(
              _showBack
                  ? "Tap to return to score meaning"
                  : "Tap to learn how this score works",
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MutedParagraph extends StatelessWidget {
  final String text;

  const _MutedParagraph(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text, style: TextStyle(color: Colors.grey[700], height: 1.5));
  }
}

class _BottomNavBar extends StatelessWidget {
  final bool canGoBack;
  final bool isLast;
  final bool isLoading;
  final VoidCallback onBack;
  final VoidCallback onNext;

  const _BottomNavBar({
    required this.canGoBack,
    required this.isLast,
    required this.isLoading,
    required this.onBack,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 50,
                child: OutlinedButton(
                  onPressed: canGoBack && !isLoading ? onBack : null,
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    side: BorderSide(color: Colors.grey.shade400),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text("Back"),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 50,
                child: FilledButton(
                  onPressed: isLoading ? null : onNext,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF8B6B5C),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(isLast ? "Done" : "Next"),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
