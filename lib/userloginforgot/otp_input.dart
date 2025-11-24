import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A reusable OTP input widget that renders a row of fixed-length
/// single-character input fields, handles focus movement, backspace
/// navigation, and reports combined value via callbacks.
class OtpInput extends StatefulWidget {
  const OtpInput({
    super.key,
    this.length = 6,
    this.onChanged,
    this.onCompleted,
    this.fieldWidth = 54,
    this.mainAxisAlignment = MainAxisAlignment.spaceBetween,
    this.textStyle = const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
    this.outlineColor = const Color(0xFFBDBDBD),
    this.focusedOutlineColor = const Color(0xFFFF9BA4),
    this.contentVerticalPadding = 14,
    this.autoFocusFirst = false,
    this.allowAlphanumeric = false,
  });

  final int length;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onCompleted;
  final double fieldWidth;
  final MainAxisAlignment mainAxisAlignment;
  final TextStyle textStyle;
  final Color outlineColor;
  final Color focusedOutlineColor;
  final double contentVerticalPadding;
  final bool autoFocusFirst;
  final bool allowAlphanumeric;

  @override
  State<OtpInput> createState() => _OtpInputState();
}

class _OtpInputState extends State<OtpInput> {
  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _focusNodes;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(widget.length, (_) => TextEditingController());
    _focusNodes = List.generate(widget.length, (_) => FocusNode());
    if (widget.autoFocusFirst && _focusNodes.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _focusNodes.first.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _handleChanged(String value, int index) {
    final v = widget.allowAlphanumeric ? value.toUpperCase() : value;
    if (_controllers[index].text != v) {
      _controllers[index].text = v;
      _controllers[index].selection = TextSelection.collapsed(offset: v.length);
    }
    if (v.length == 1 && index < widget.length - 1) {
      _focusNodes[index + 1].requestFocus();
    }
    final current = _controllers.map((c) => c.text).join();
    widget.onChanged?.call(current);
    if (current.length == widget.length &&
        _controllers.every((c) => c.text.trim().isNotEmpty)) {
      widget.onCompleted?.call(current);
    }
  }

  void _handleKey(KeyEvent event, int index) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace) {
      if (_controllers[index].text.isEmpty && index > 0) {
        _focusNodes[index - 1].requestFocus();
        _controllers[index - 1].selection = TextSelection.fromPosition(
          TextPosition(offset: _controllers[index - 1].text.length),
        );
      }
    }
  }

  OutlineInputBorder _outline({Color? color}) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(color: color ?? widget.outlineColor, width: 1.2),
      );

  Widget _box(int index) {
    return SizedBox(
      width: widget.fieldWidth,
      child: KeyboardListener(
        focusNode: FocusNode(skipTraversal: true),
        onKeyEvent: (e) => _handleKey(e, index),
        child: TextField(
          controller: _controllers[index],
          focusNode: _focusNodes[index],
          textAlign: TextAlign.center,
          style: widget.textStyle,
          textCapitalization: widget.allowAlphanumeric
              ? TextCapitalization.characters
              : TextCapitalization.none,
          keyboardType:
              widget.allowAlphanumeric ? TextInputType.text : TextInputType.number,
          inputFormatters: widget.allowAlphanumeric
              ? [
                  LengthLimitingTextInputFormatter(1),
                  FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                ]
              : [
                  LengthLimitingTextInputFormatter(1),
                  FilteringTextInputFormatter.digitsOnly,
                ],
          onChanged: (v) => _handleChanged(v, index),
          decoration: InputDecoration(
            contentPadding:
                EdgeInsets.symmetric(vertical: widget.contentVerticalPadding),
            border: _outline(),
            enabledBorder: _outline(),
            focusedBorder: _outline(color: widget.focusedOutlineColor),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: widget.mainAxisAlignment,
      children: List.generate(widget.length, _box),
    );
  }
}