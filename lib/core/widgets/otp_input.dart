import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';

class OtpInput extends StatefulWidget {
  final TextEditingController controller;
  final int length;
  final ValueChanged<String>? onCompleted;

  const OtpInput({
    super.key,
    required this.controller,
    this.length = 6,
    this.onCompleted,
  });

  @override
  State<OtpInput> createState() => OtpInputState();
}

class OtpInputState extends State<OtpInput> with TickerProviderStateMixin {
  final FocusNode _focus = FocusNode();
  bool _error = false;

  late final AnimationController _shakeCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  );
  late final AnimationController _blinkCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  )..repeat(reverse: true);

  String get _value => widget.controller.text;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
    _focus.addListener(() => setState(() {}));
  }

  void _onChanged() {
    if (_error) _error = false;
    setState(() {});
    if (_value.length == widget.length) {
      HapticFeedback.lightImpact();
      widget.onCompleted?.call(_value);
    }
  }

  /// À appeler quand le code est invalide.
  Future<void> shake() async {
    setState(() => _error = true);
    HapticFeedback.heavyImpact();
    await _shakeCtrl.forward(from: 0);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    _focus.dispose();
    _shakeCtrl.dispose();
    _blinkCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shakeCtrl,
      builder: (context, child) {
        final t = _shakeCtrl.value;
        final dx = math.sin(t * math.pi * 6) * 10 * (1 - t);
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
      child: Stack(
        children: [
          // Les 6 cases
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(widget.length, _buildBox),
          ),

          // Vrai champ de saisie, invisible, par-dessus
          Positioned.fill(
            child: Opacity(
              opacity: 0,
              child: TextField(
                controller: widget.controller,
                focusNode: _focus,
                autofocus: true,
                keyboardType: TextInputType.number,
                maxLength: widget.length,
                showCursor: false,
                enableInteractiveSelection: false,
                autofillHints: const [AutofillHints.oneTimeCode],
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(counterText: ''),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBox(int i) {
    final hasChar = i < _value.length;
    final isActive =
        _focus.hasFocus && i == _value.length.clamp(0, widget.length - 1);
    final complete = _value.length == widget.length;

    Color border = SM.primarySoft;
    if (_error) {
      border = SM.danger;
    } else if (complete) {
      border = SM.success;
    } else if (isActive) {
      border = SM.primary;
    }

    // Apparition échelonnée des cases
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 350 + i * 90),
      curve: Curves.easeOutBack,
      builder: (context, v, child) => Opacity(
        opacity: v.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, (1 - v) * 24),
          child: child,
        ),
      ),
      child: AnimatedContainer(
        duration: SM.anim,
        curve: Curves.easeOut,
        width: 48,
        height: 60,
        transform: Matrix4.identity()..scale(isActive ? 1.06 : 1.0),
        transformAlignment: Alignment.center,
        decoration: BoxDecoration(
          color: complete && !_error
              ? SM.success.withOpacity(0.08)
              : Colors.white,
          borderRadius: BorderRadius.circular(SM.rButton),
          border: Border.all(color: border, width: isActive ? 2 : 1.5),
          boxShadow: isActive ? SM.shadow : [],
        ),
        child: Center(
          child: hasChar
              ? TweenAnimationBuilder<double>(
                  key: ValueKey('$i-${_value[i]}'),
                  tween: Tween(begin: 0.4, end: 1),
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.elasticOut,
                  builder: (_, s, child) =>
                      Transform.scale(scale: s, child: child),
                  child: Text(
                    _value[i],
                    style: SM.h(24).copyWith(
                          color: _error ? SM.danger : SM.text,
                        ),
                  ),
                )
              : isActive
                  ? FadeTransition(
                      opacity: _blinkCtrl,
                      child: Container(
                        width: 2,
                        height: 26,
                        decoration: BoxDecoration(
                          color: SM.primary,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
        ),
      ),
    );
  }
}