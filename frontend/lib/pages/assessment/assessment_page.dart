import 'package:flutter/material.dart';

class AssessmentPage extends StatefulWidget {
  final String petName;
  final String ownerName;

  const AssessmentPage({
    super.key,
    required this.petName,
    required this.ownerName,
  });

  @override
  State<AssessmentPage> createState() => _AssessmentPageState();
}

class _AssessmentPageState extends State<AssessmentPage> {
  late final PageController _pageController;

  int _currentPage = 0;

  /// answers store
  final Map<String, dynamic> _answers = {
    "favorite_pet_things": <String>["", "", ""],
    "favorite_shared_things": <String>["", ""],
    "biggest_concerns": <String>[],
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
    "reach_out": false,
  };

  List<_AssessmentStep> get _steps => _buildSteps();

  @override
  void initState() {
    super.initState();
    _pageController = PageController();

    // initialize joy items from favorite things once if empty
    final joyItems = _answers["joy_items"] as List<Map<String, dynamic>>;
    if (joyItems.isEmpty) {
      _answers["joy_items"] = [
        {"label": "", "status": ""},
        {"label": "", "status": ""},
        {"label": "", "status": ""},
        {"label": "", "status": ""},
        {"label": "", "status": ""},
      ];
    }
  }

  List<_AssessmentStep> _buildSteps() {
    return [
      _AssessmentStep(
        id: "intro_favorites",
        title: "Before we begin, let’s figure out ${widget.petName}’s favorite things.",
        description: null,
        builder: _buildFavoritesStep,
      ),
      _AssessmentStep(
        id: "concerns",
        title: "What are your biggest concerns regarding ${widget.petName}’s health?",
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
        title: "Describe yourself",
        description:
            "This is not a judgement. Your comfort through this process is imporant too and understanding who you are helps us direct you towards what options are best for you and your family. Your honest answers help us give you and your pet the best experience.",
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
            "Like their appetites, changes to our pets' water intake can be a signifier that important changes are taking place within their bodies.  Likewise, inappropriate urination or incontinence can signal that mechanical or cognitive problems need to be addressed.",
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
            "Our companion animals can undergo age-related changes to their minds and their behavior, very similar to humans can experience. These changes can be present in conjunction with physical age-related challenges or they can present completely on their own.",
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
            "${widget.petName} isn't the only consideration in this equation. You and your family matter as well. Although our last years with our cherished friends can be beautiful, they can be rife with challenges as well.\n\nThere are times when our situation or ability to cope with the increasing needs of our ailing friends starts to put strain on our bond with them. There are times when changes to their condition become incompatible with their home environment. And there are times when the money to treat them simply isn't there.\n\nIn a perfect world, we would have unlimited resources, unlimited time, and unlimited flexibility. We don't live in that world and it's alright to be honest about the limitations of what we can do.",
        builder: _buildOwnerStateStep,
      ),
      _AssessmentStep(
        id: "results",
        title: "Understanding our Scoring System",
        description:
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
    if (_steps.length <= 1) return 1;
    return (_currentPage + 1) / _steps.length;
  }

  List<String> _favoriteThingsAll() {
    final petThings =
        ((_answers["favorite_pet_things"] as List).map((e) => e.toString().trim()))
            .where((e) => e.isNotEmpty)
            .toList();

    final sharedThings =
        ((_answers["favorite_shared_things"] as List).map((e) => e.toString().trim()))
            .where((e) => e.isNotEmpty)
            .toList();

    return [...petThings, ...sharedThings];
  }

  void _syncJoyItemsFromFavorites() {
    final all = _favoriteThingsAll();
    final current = _answers["joy_items"] as List<Map<String, dynamic>>;
    final synced = List.generate(5, (index) {
      final existingStatus =
          index < current.length ? (current[index]["status"] ?? "").toString() : "";
      return {
        "label": index < all.length ? all[index] : "",
        "status": existingStatus,
      };
    });
    _answers["joy_items"] = synced;
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
      if ((item["status"] ?? "") == "Continues to Enjoy") {
        total += 6;
      }
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

  String _heartScoreRangeText(int score) {
    if (score >= 6) {
      return "We have tools in our toolbox to help slow and mitigate some of the changes associated with age or some forms of disease, even if we don't have any that completely stop those processes.\n\nBased on your responses, ${widget.petName} may be a candidate for the pursuit of additional lines of treatment to improve the quality of this stage of their life. That doesn't mean that every situation is appropriate to pursue new avenues of care, but under the guidance of your White Whiskers Care Team, there may be more that we can do for ${widget.petName}.";
    }
    if (score >= 3) {
      return "We have tools in our toolbox to help slow and mitigate some of the changes associated with age or some forms of disease, even if we don't have any that completely stop those processes.\n\nBased on your responses, with some creativity, there may be some options for ${widget.petName} that haven't yet been considered. At this score, we want to focus on comfort for both you and ${widget.petName} with the understanding that a measured approach is a better fit for your family. We want to never lose sight of our mission to make things as good as they can be for each family's situation.";
    }
    return "Based on your responses, the pursuit of treatment for ${widget.petName} isn't feasible at this time. This is often the case for our animals who consider the treatment to be as bad if not worse than the disease. We can also reach a point as care givers where we don't have the resources to give more than we already have.\n\nEach situation is unique. Each animal and owner have their own path forward. We will help you find yours and help to ensure that this time with ${widget.petName} is as good as it can be.";
  }

  String _conditionScoreRangeTitle(int score) {
    if (score > 60) return "Condition Score Range: >60";
    if (score < 30) return "Condition Score Range: <30";
    return "Condition Score Range: 30-60";
  }

  String _conditionScoreRangeText(int score) {
    if (score > 60) {
      return "Not every scoring system is perfect, but your score suggests that we still have options to improve ${widget.petName}'s quality of life and to give you more good days to share with your friend.\n\nCall us today for a consultation on how we can help ${widget.petName}'s golden years really shine with a Sunrise Visit.\n\nCall Now: (719) 799 - 6670";
    }
    if (score < 30) {
      return "We are never ready to say goodbye and we never want to rob them of those good days. It's important, however, that we not hold on so tightly that we cross the threshold of distress with them.\n\n${widget.petName} is nearing that time when our options are few and our time is likely limited. As hard as it is to let them go, know that helping them pass with tranquility and peace is an act of love. When the time is right, we can help you give ${widget.petName} that gift.\n\nNone of us at White Whiskers have ever had the honor to call ourselves ${widget.petName}'s owners, but we have all loved and lost our own special friends. We understand how hard this time is and we're here to help.\n\nCall Now: (719) 799-6670";
    }
    return "In spite of the challenges ${widget.petName} is facing, there may be adjustments we can make  to improve their quality of life to a point where you can have more time with them.\n\nYour score places you in a grey zone that is best aided by a physical examination. Contact us today to schedule a Crossroads Visit with our doctor who will help you to be the best advocate for ${widget.petName} as you can be.\n\nCrossroads Visits can seamlessly be converted to a Sunrise Visit for planning and treatment or to a Sunset Visit should we decide that the most loving way to help ${widget.petName} is to let them go. In either case, we will help you every step of the way to ensure that you have that critical peace of mind in your decision.\n\nCall Now: (719) 799 - 6670";
  }

  String _significantlyChallengedText() {
    return "In a perfect world, our aging pets pass seamlessly in their sleep from a failing mind and body after a good day of play and love and all of their favorite things. All too often, that's not the case and it's only one system that's failing while others are still trucking along.\n\nWithin at least one of your answers, you selected a 1 or a 2 score which means that somewhere along the line you pin pointed something that is causing you or ${widget.petName} significant distress. Sometimes it's not a whole picture. It's just one incompatible problem that we need to address. Sometimes that problem can be fixed. Sometimes it can't. In either case we can help you better contextualize that problem, see if there are options to address it that work for your family, or help you understand that just one '1' score on this list can be enough to offer them release.\n\nWe're here to help.\n\nCall Now: (719) 799-6670";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Assessment"),
        centerTitle: false,
      ),
      body: SafeArea(
        child: Column(
          children: [
            _TopProgressBar(
              current: _currentPage + 1,
              total: _steps.length,
              progress: _progress,
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
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _StepHeader(
                          title: s.title,
                          description: s.description,
                        ),
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
              onBack: _goBack,
              onNext: () {
                if (_currentPage == _steps.length - 1) {
                  Navigator.of(context).maybePop();
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

  // ---------------------------
  // Step builders
  // ---------------------------

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
        _FieldTitle("What are your 2 favorite things you share with ${widget.petName}?"),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _MultiChoiceGroup(
          options: options,
          selected: (_answers["biggest_concerns"] as List<String>),
          onChanged: (v) => setState(() => _answers["biggest_concerns"] = v),
        ),
        const SizedBox(height: 24),
        _FieldTitle("Can you expand upon your primary concerns for ${widget.petName}?"),
        const SizedBox(height: 10),
        _TextAnswerField(
          initialValue: _answers["concerns_expand"],
          minLines: 4,
          maxLines: 6,
          onChanged: (v) => _answers["concerns_expand"] = v,
        ),
        const SizedBox(height: 24),
        _FieldTitle("How long has it been going on?*"),
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
          options: const [
            "Good Days",
            "Bad Days",
          ],
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
          options: const [
            "More Information",
            "Less Information",
          ],
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
                  "You have the time and resources to build a medical team, but you need help managing and translating that team's findings.",
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
          options: const [
            "Anything Goes",
            "Limited Pokes",
            "Hands Off!",
          ],
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
              "On a scale of 1-10 (1 = worst) rate the condition of ${widget.petName}'s physical condition.",
          score: _answers["physical_score"],
          details:
              "For reference and consideration (rated most important to least):\nRespiration (Breathing)\nPain (Difficult to assess in stoic pets)\nTumors/Cancer\nWounds/Infections",
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
          prompt:
              "On a scale of 1-10 (1 = most abnormal) rate the condition of ${widget.petName}'s appetite.",
          score: _answers["appetite_score"],
          details:
              "Abnormal appetite could either be excessive hunger or a refusal to eat. This rating represents a deviation from normal.",
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
        _FieldTitle("How would you describe ${widget.petName}'s relationship with food these days?"),
        const SizedBox(height: 10),
        _SingleChoiceGroup(
          value: _answers["food_relationship"],
          options: const [
            "Eats all the food",
            "Picky and discerning",
          ],
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
              "On a scale of 1-10 (1 = most abnormal) rate the condition of ${widget.petName}'s hydration status.",
          score: _answers["hydration_score"],
          details:
              "Abnormal water intake could either be excessive thirst or a refusal to drink. This rating represents a deviation from normal.",
          onChanged: (v) => setState(() => _answers["hydration_score"] = v),
        ),
        const SizedBox(height: 24),
        _FieldTitle(
          "Hydration Score Explanation",
          description: "Tell us a bit about why you gave the score you gave…",
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
          prompt:
              "On a scale of 1-10 (1 = worst) rate ${widget.petName}'s ability to move around their environment.",
          score: _answers["mobility_score"],
          onChanged: (v) => setState(() => _answers["mobility_score"] = v),
        ),
        const SizedBox(height: 24),
        _FieldTitle(
          "Mobility Score Explanation",
          description: "Tell us a bit about why you gave the score you gave…",
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
              "On a scale of 1-10 (1 = worst) rate the condition of ${widget.petName}'s physical cleanliness.",
          score: _answers["cleanliness_score"],
          onChanged: (v) => setState(() => _answers["cleanliness_score"] = v),
        ),
        const SizedBox(height: 24),
        _FieldTitle(
          "Cleanliness Score Explanation",
          description: "Tell us a bit about why you gave the score you gave…",
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
        _FieldTitle(
          "Have you detected a behavioral change in ${widget.petName}?",
          description:
              "This is not a question, only prompt. Some examples are increased grumpiness, getting lost in familiar places, hiding or distancing or incessant pacing. Like human dementia, the early stages of this process can be difficult to assess because symptoms can wax and wane and often lack consistency.",
        ),
        const SizedBox(height: 10),
        _TextAnswerField(
          initialValue: _answers["behavior_change_notes"],
          minLines: 4,
          maxLines: 6,
          onChanged: (v) => _answers["behavior_change_notes"] = v,
        ),
        const SizedBox(height: 24),
        _RatingBlock(
          prompt:
              "On a scale of 1-10 (1 = worst) rate ${widget.petName}'s state of mind.",
          score: _answers["state_of_mind_score"],
          onChanged: (v) =>
              setState(() => _answers["state_of_mind_score"] = v),
        ),
        const SizedBox(height: 24),
        _FieldTitle(
          "Cognition Score Explanation",
          description: "Tell us a bit about why you gave the score you gave…",
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
    _syncJoyItemsFromFavorites();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldTitle("For each"),
        const SizedBox(height: 12),
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
          description: "Additional thoughts on ${widget.petName}'s daily joy…",
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
              "On a scale of 1-10 (1 = worst) rate how you and your family are doing with ${widget.petName}'s changes.",
          score: _answers["owner_state_score"],
          onChanged: (v) => setState(() => _answers["owner_state_score"] = v),
        ),
        const SizedBox(height: 24),
        _FieldTitle(
          "${widget.ownerName}'s Score Explanation",
          description: "Tell us a bit about why you gave the score you gave…",
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
    final challenged = condition >= 30 && condition <= 90 && _hasSignificantlyChallengedFlag();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _InfoCard(
          title: "Heart Score",
          body:
              "The Heart Score  is an 10 point score that assesses the ability and desire both you and ${widget.petName} have for the pursuit of treatment. A high score suggests a readiness to pursue treatments for both you and your pet. Deciding NOT to pursue diagnostics or treatment IS AN OPTION and one that many are afraid to entertain. Treatment is a team effort and both you and ${widget.petName} have to be on board to make it a good experience. Never mistake having a low Heart Score as being a bad owner or giving up. But acknowledging where you both are on your journey together is an important consideration.",
        ),
        const SizedBox(height: 12),
        _InfoCard(
          title: "Condition Score",
          body:
              "The Condition Score is a 100 point subjective assessment of ${widget.petName}'s mind and body at this point in time. It also considers how you're holding up as well. You are linked inextricably to ${widget.petName} and you carry so many of their burdens. It can be easy, as you work to support ${widget.petName}, to lose sight of the importance of your place in the human-animal bond. The Condition Score seeks to address the most important elements of an animal's quality of life as seen through mind, body and experience. When combined with an objective physical exam from your veterinarian, we hope this examination provides you with the very best tools for understanding the best path forward for you and ${widget.petName}.",
        ),
        const SizedBox(height: 12),
        _MutedParagraph(
          "Keep in mind that this assessment is deeply subjective. Often times the scores on different categories can vary wildly between different members. That's ok. Also consider that this score is a combination of all the things. However, most often it's one critical quality of life component that is faltering. Sometimes it just takes the one thing to be enough.",
        ),
        const SizedBox(height: 12),
        const _MutedParagraph(
          "Remember: this is an assessment tool, not a decision.",
        ),
        const SizedBox(height: 20),
        _ScoreCard(
          label: "Heart Score",
          score: "$heart / 10",
          body: _heartScoreRangeText(heart),
        ),
        const SizedBox(height: 16),
        _ScoreCard(
          label: "Condition Score",
          score: "$condition / 100",
          body: _conditionScoreRangeText(condition),
          subtitle: _conditionScoreRangeTitle(condition),
        ),
        if (challenged) ...[
          const SizedBox(height: 16),
          _ScoreCard(
            label: "Condition Score Range: 30-90 but significantly challenged",
            score: null,
            body: _significantlyChallengedText(),
          ),
        ],
        const SizedBox(height: 20),
        CheckboxListTile(
          value: _answers["reach_out"] as bool,
          onChanged: (v) => setState(() => _answers["reach_out"] = v ?? false),
          title: const Text(
            "If you would like us to reach out to you, select this option below and a member of our team will contact you shortly.",
          ),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
        ),
      ],
    );
  }
}

// =========================
// Models
// =========================

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

// =========================
// Reusable UI
// =========================

class _TopProgressBar extends StatelessWidget {
  final int current;
  final int total;
  final double progress;

  const _TopProgressBar({
    required this.current,
    required this.total,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Step $current of $total",
            style: theme.textTheme.labelLarge?.copyWith(
              color: Colors.grey[700],
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
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

  const _StepHeader({
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            height: 1.25,
          ),
        ),
        if (description != null && description!.trim().isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            description!,
            style: theme.textTheme.bodyMedium?.copyWith(
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
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            height: 1.3,
          ),
        ),
        if (description != null && description!.trim().isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            description!,
            style: theme.textTheme.bodyMedium?.copyWith(
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
    if (_controller.text != newText) {
      _controller.text = newText;
    }
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
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
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
                  color: selected ? Theme.of(context).colorScheme.primary : Colors.grey.shade300,
                  width: selected ? 2 : 1,
                ),
                color: selected
                    ? Theme.of(context).colorScheme.primary.withValues()
                    : Colors.white,
              ),
              child: Text(
                option,
                style: TextStyle(
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
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: options.map((option) {
        final isSelected = selected.contains(option);
        return FilterChip(
          label: Text(option),
          selected: isSelected,
          onSelected: (v) {
            final next = [...selected];
            if (v) {
              next.add(option);
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
                  color: selected ? Theme.of(context).colorScheme.primary : Colors.grey.shade300,
                  width: selected ? 2 : 1,
                ),
                color: selected
                    ? Theme.of(context).colorScheme.primary.withValues()
                    : Colors.white,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    opt.title,
                    style: TextStyle(
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    opt.description,
                    style: TextStyle(
                      color: Colors.grey[700],
                      height: 1.45,
                    ),
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
  final ValueChanged<int> onChanged;

  const _RatingBlock({
    required this.prompt,
    required this.score,
    required this.onChanged,
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
            color: Colors.grey.shade50,
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  const Text("1"),
                  Expanded(
                    child: Slider(
                      value: score.toDouble(),
                      min: 1,
                      max: 10,
                      divisions: 9,
                      label: "$score",
                      onChanged: (v) => onChanged(v.round()),
                    ),
                  ),
                  const Text("10"),
                ],
              ),
              const SizedBox(height: 4),
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
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          _SingleChoiceGroup(
            value: value,
            options: const [
              "Continues to Enjoy",
              "No Longer Enjoys",
            ],
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final String body;

  const _InfoCard({
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.grey.shade50,
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(body, style: TextStyle(color: Colors.grey[800], height: 1.5)),
        ],
      ),
    );
  }
}

class _ScoreCard extends StatelessWidget {
  final String label;
  final String? subtitle;
  final String? score;
  final String body;

  const _ScoreCard({
    required this.label,
    required this.body,
    this.subtitle,
    this.score,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            blurRadius: 12,
            color: Colors.black.withValues(),
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: TextStyle(
                color: Colors.grey[700],
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (score != null) ...[
            const SizedBox(height: 10),
            Text(
              score!,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ],
          const SizedBox(height: 12),
          Text(body, style: TextStyle(color: Colors.grey[800], height: 1.55)),
        ],
      ),
    );
  }
}

class _MutedParagraph extends StatelessWidget {
  final String text;

  const _MutedParagraph(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: Colors.grey[700],
        height: 1.5,
      ),
    );
  }
}

class _BottomNavBar extends StatelessWidget {
  final bool canGoBack;
  final bool isLast;
  final VoidCallback onBack;
  final VoidCallback onNext;

  const _BottomNavBar({
    required this.canGoBack,
    required this.isLast,
    required this.onBack,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: canGoBack ? onBack : null,
              child: const Text("Back"),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton(
              onPressed: onNext,
              child: Text(isLast ? "Done" : "Next"),
            ),
          ),
        ],
      ),
    );
  }
}