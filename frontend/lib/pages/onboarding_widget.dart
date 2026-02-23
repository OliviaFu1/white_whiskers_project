import 'package:flutter/material.dart';

class OnboardingStepScaffold extends StatelessWidget {
  final String title;
  final Widget field;
  final bool showBack;
  final VoidCallback? onBack;
  final bool canNext;
  final VoidCallback? onNext;
  final String? helperError;

  // styling
  final Color bg;
  final Color titleColor;
  final Color accent;
  final Color muted;

  const OnboardingStepScaffold({
    super.key,
    required this.title,
    required this.field,
    required this.showBack,
    required this.canNext,
    required this.bg,
    required this.titleColor,
    required this.accent,
    required this.muted,
    this.onBack,
    this.onNext,
    this.helperError,
  });

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;
    final titleTop = h * 0.15;
    final titleToField = h * 0.05;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: showBack
                    ? IconButton(
                        onPressed: onBack,
                        icon: Icon(Icons.arrow_back_ios_new, color: muted),
                      )
                    : const SizedBox(height: 48, width: 48),
              ),

              SizedBox(height: titleTop),

              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: titleColor,
                ),
              ),

              SizedBox(height: titleToField),

              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    field,
                    const SizedBox(height: 10),
                    if (helperError != null)
                      Text(
                        helperError!,
                        style: const TextStyle(color: Colors.red, fontSize: 12),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              _NextArrowButton(
                enabled: canNext,
                accent: accent,
                onTap: canNext ? onNext : null,
              ),

              const Spacer(),
              const SizedBox(height: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _NextArrowButton extends StatelessWidget {
  final bool enabled;
  final Color accent;
  final VoidCallback? onTap;

  const _NextArrowButton({
    required this.enabled,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.4,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: accent),
          ),
          child: Icon(Icons.arrow_forward, size: 20, color: accent),
        ),
      ),
    );
  }
}

class UnderlineTextInput extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool obscure;
  final TextInputType keyboardType;
  final Color lineColor;
  final ValueChanged<String>? onChanged;

  const UnderlineTextInput({
    super.key,
    required this.controller,
    required this.label,
    required this.lineColor,
    this.obscure = false,
    this.keyboardType = TextInputType.text,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: lineColor),
        ),
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: lineColor, width: 1.2),
        ),
      ),
    );
  }
}

class UnderlineDropdownInput<T> extends StatelessWidget {
  final String label;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final Color lineColor;

  const UnderlineDropdownInput({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    required this.lineColor,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      items: items,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: lineColor),
        ),
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: lineColor, width: 1.2),
        ),
      ),
    );
  }
}