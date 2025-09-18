import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'set_new_pass.dart';

const Color tomatoRed = Color(0xFFE53935);

class EmailOtpPage extends StatefulWidget {
	const EmailOtpPage({super.key, this.email});

	final String? email;

	@override
	State<EmailOtpPage> createState() => _EmailOtpPageState();
}

class _EmailOtpPageState extends State<EmailOtpPage> {
	static const int _otpLength = 5;
	late final List<TextEditingController> _controllers;
	late final List<FocusNode> _focusNodes;
	bool _allFilled = false;

	@override
	void initState() {
		super.initState();
		_controllers = List.generate(_otpLength, (_) => TextEditingController());
		_focusNodes = List.generate(_otpLength, (_) => FocusNode());
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

	void _onChanged(String value, int index) {
		if (value.length == 1 && index < _otpLength - 1) {
			_focusNodes[index + 1].requestFocus();
		}
			// Update filled status
			final filled = _controllers.every((c) => c.text.trim().isNotEmpty);
			if (filled != _allFilled) {
				setState(() => _allFilled = filled);
			}
	}

  void _onKey(KeyEvent event, int index) {
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.backspace) {
      if (_controllers[index].text.isEmpty && index > 0) {
        _focusNodes[index - 1].requestFocus();
        _controllers[index - 1].selection = TextSelection.fromPosition(
          TextPosition(offset: _controllers[index - 1].text.length),
        );
      }
    }
  }

	void _verify() {
		if (!_allFilled) return; // ignore if incomplete
		FocusScope.of(context).unfocus();
		// final code = _controllers.map((c) => c.text).join(); // collected if needed for backend call

		// Normally: validate OTP with backend then navigate.
		Navigator.push(
			context,
			MaterialPageRoute(
				builder: (_) => const SetNewPasswordPage(),
			),
		);
	}

	void _resend() {
		// TODO: trigger resend OTP API
	}

	Widget _buildOtpBox(int index) {
		return SizedBox(
			width: 54,
			child: KeyboardListener(
				focusNode: FocusNode(skipTraversal: true),
				onKeyEvent: (e) {
					_onKey(e, index);
				},
				child: TextField(
					controller: _controllers[index],
					focusNode: _focusNodes[index],
					textAlign: TextAlign.center,
					style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
					keyboardType: TextInputType.number,
						// Allow only one digit.
								inputFormatters: [
									LengthLimitingTextInputFormatter(1),
									FilteringTextInputFormatter.digitsOnly,
								],
					onChanged: (v) => _onChanged(v, index),
					decoration: InputDecoration(
						contentPadding: const EdgeInsets.symmetric(vertical: 14),
						border: _outline(),
						enabledBorder: _outline(),
						focusedBorder: _outline(color: const Color(0xFFFF9BA4)),
					),
				),
			),
		);
	}

	OutlineInputBorder _outline({Color color = const Color(0xFFBDBDBD)}) =>
			OutlineInputBorder(
				borderRadius: BorderRadius.circular(6),
				borderSide: BorderSide(color: color, width: 1.2),
			);

	@override
	Widget build(BuildContext context) {
		final email = widget.email ?? 'cherry_@gmail.com';
		final theme = Theme.of(context);

		return Scaffold(
			backgroundColor: Colors.white,
			body: SafeArea(
				child: Padding(
					padding: const EdgeInsets.symmetric(horizontal: 24),
					child: Column(
						crossAxisAlignment: CrossAxisAlignment.start,
						children: [
							const SizedBox(height: 8),
							// Back arrow
							IconButton(
								onPressed: () => Navigator.of(context).maybePop(),
								icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
								padding: EdgeInsets.zero,
								constraints: const BoxConstraints(),
							),
							const SizedBox(height: 8),
							Text(
								'Check your email',
								style: theme.textTheme.titleMedium?.copyWith(
									fontSize: 18,
									fontWeight: FontWeight.w700,
								),
							),
							const SizedBox(height: 8),
							_LinkLikeText(
								'We sent a reset link to $email',
							),
							const SizedBox(height: 2),
							const _LinkLikeText(
								'enter 5 digit code that mentioned in the email',
							),
							const SizedBox(height: 40),
							Row(
								mainAxisAlignment: MainAxisAlignment.spaceBetween,
								children: List.generate(_otpLength, _buildOtpBox),
							),
							const SizedBox(height: 40),
							SizedBox(
								width: double.infinity,
								height: 46,
								child: ElevatedButton(
									style: ElevatedButton.styleFrom(
														backgroundColor: _allFilled
																? tomatoRed 
																: const Color(0xFFFFC5C8), 
														foregroundColor: _allFilled ? Colors.white : Colors.black87,
										elevation: 0,
										shape: RoundedRectangleBorder(
											borderRadius: BorderRadius.circular(6),
										),
									),
													onPressed: _allFilled ? _verify : null,
									child: const Text(
										'Verify',
										style: TextStyle(
											fontSize: 14,
											fontWeight: FontWeight.w600,
										),
									),
								),
							),
							const SizedBox(height: 16),
							Center(
								child: Wrap(
									crossAxisAlignment: WrapCrossAlignment.center,
									children: [
										Text(
											"Haven't got the email yet? ",
											style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12),
										),
										GestureDetector(
											onTap: _resend,
											child: const Text(
												'Resent email',
												style: TextStyle(
													color: tomatoRed,
													fontSize: 12,
													fontWeight: FontWeight.w600,
													decoration: TextDecoration.underline,
													decorationColor: tomatoRed, 
												),
											),
										)
									],
								),
							),
						],
					),
				),
			),
		);
	}
}

class _LinkLikeText extends StatelessWidget {
	const _LinkLikeText(this.text);
	final String text;

	@override
	Widget build(BuildContext context) {
		return Text(
			text,
			style: const TextStyle(
				fontSize: 12,
				color: Color(0xFF4F4F4F), // neutral dark gray
				fontWeight: FontWeight.w400,
				decoration: TextDecoration.none,
			),
		);
	}
}

