import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utilities/constants.dart';

/// Simple EmailJS client for sending verification codes.
class EmailJsService {
  EmailJsService._();
  static final instance = EmailJsService._();

  static const _endpoint = 'https://api.emailjs.com/api/v1.0/email/send';

  /// Sends a verification email using EmailJS.
  /// The EmailJS template should accept `to_email`, `passcode`, and `time`.
  Future<void> sendVerificationEmail({
    required String toEmail,
    required String passcode,
    required String time,
  }) async {
    final payload = {
      'service_id': Constants.emailJsServiceId,
      'template_id': Constants.emailJsTemplateId,
      'user_id': Constants.emailJsPublicKey,
      'template_params': {
        'to_email': toEmail,
        'passcode': passcode,
        'time': time,
      },
    };

    final res = await http.post(
      Uri.parse(_endpoint),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode(payload),
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('EmailJS send failed: ${res.statusCode} ${res.body}');
    }
  }
}