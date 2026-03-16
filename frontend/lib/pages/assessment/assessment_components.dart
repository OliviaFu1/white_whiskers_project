part of 'assessment_page.dart';

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
  final String frontBody;
  final String backBody;

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