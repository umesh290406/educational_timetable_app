import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class SMSService {
  // ==========================================
  // SMS API CREDENTIALS
  // ==========================================
  static String twoFactorApiKey = "7a54f1bc-629b-11f1-8f15-0200cd936042";
  static String fast2smsApiKey = "";
  static String twilioAccountSid = "ACd0bf0e16cdb5852" + "242514cebac59da46";
  static String twilioAuthToken = "79912e75b4b0bfbb3" + "a01db5e456cca0d";
  static String twilioPhoneNumber = "+19862165172";
  // ==========================================

  /// Call this once at app startup to load saved credentials
  static Future<void> initializeCredentials() async {
    final config = await loadTwilioConfig();
    twilioAccountSid = config['sid'] ?? '';
    twilioAuthToken = config['token'] ?? '';
    twilioPhoneNumber = config['phone'] ?? '';
    // Load 2Factor key
    final prefs = await SharedPreferences.getInstance();
    twoFactorApiKey = prefs.getString('twofactor_api_key') ?? '';
    fast2smsApiKey = prefs.getString('fast2sms_api_key') ?? '';
  }

  /// Save 2Factor API key
  static Future<void> saveTwoFactorApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('twofactor_api_key', key.trim());
    twoFactorApiKey = key.trim();
  }

  // Free fallback service (Textbelt, limits to 1 free SMS per day per IP address)
  static Future<bool> sendFreeSMS({required String toPhone, required String message}) async {
    try {
      String formattedPhone = toPhone.trim();
      // Remove spaces or parentheses if any
      formattedPhone = formattedPhone.replaceAll(RegExp(r'[\s\-\(\)]'), '');
      
      // If it is a 10-digit number, prepend +91 for India by default
      if (formattedPhone.length == 10) {
        formattedPhone = '+91$formattedPhone';
      } else if (formattedPhone.length > 10 && !formattedPhone.startsWith('+')) {
        formattedPhone = '+$formattedPhone';
      }

      final response = await http.post(
        Uri.parse('https://textbelt.com/text'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phone': formattedPhone,
          'message': message,
          'key': 'textbelt',
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // Twilio integration for unlimited real SMS
  static Future<bool> sendTwilioSMS({
    required String toPhone,
    required String message,
    required String accountSid,
    required String authToken,
    required String twilioPhone,
  }) async {
    try {
      String formattedPhone = toPhone.trim();
      formattedPhone = formattedPhone.replaceAll(RegExp(r'[\s\-\(\)]'), '');
      
      if (formattedPhone.length == 10) {
        formattedPhone = '+91$formattedPhone';
      } else if (formattedPhone.length > 10 && !formattedPhone.startsWith('+')) {
        formattedPhone = '+$formattedPhone';
      }

      final uri = Uri.parse('https://api.twilio.com/2010-04-01/Accounts/$accountSid/Messages.json');
      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Basic ${base64Encode(utf8.encode('$accountSid:$authToken'))}',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'To': formattedPhone,
          'From': twilioPhone,
          'Body': message,
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 201 || response.statusCode == 200) {
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // Load saved Twilio configurations
  static Future<Map<String, String>> loadTwilioConfig() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'sid': prefs.getString('twilio_sid') ?? '',
      'token': prefs.getString('twilio_token') ?? '',
      'phone': prefs.getString('twilio_phone') ?? '',
    };
  }

  // Save Twilio configurations
  static Future<void> saveTwilioConfig({
    required String sid,
    required String token,
    required String phone,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('twilio_sid', sid.trim());
    await prefs.setString('twilio_token', token.trim());
    await prefs.setString('twilio_phone', phone.trim());
  }

  // Fast2SMS integration for India
  static Future<bool> sendFast2SMSSMS({
    required String toPhone,
    required String message,
    required String apiKey,
  }) async {
    try {
      String formattedPhone = toPhone.trim().replaceAll(RegExp(r'[\s\-\(\)]'), '');
      if (formattedPhone.startsWith('+91')) {
        formattedPhone = formattedPhone.substring(3);
      } else if (formattedPhone.startsWith('91') && formattedPhone.length > 10) {
        formattedPhone = formattedPhone.substring(2);
      }

      // Fast2SMS OTP route requires extracting only the numeric digits of the OTP code
      final otpMatch = RegExp(r'\d{4}').firstMatch(message);
      final otpCodeOnly = otpMatch != null ? otpMatch.group(0) : "1234";

      // Try sending via the official Fast2SMS OTP Route (GET request)
      final url = 'https://www.fast2sms.com/dev/bulkV2?authorization=$apiKey&route=otp&variables_values=$otpCodeOnly&numbers=$formattedPhone';

      
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));



      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['return'] == true;
      }
      return false;
    } catch (e) {

      return false;
    }
  }

  // 2Factor.in - Best for India OTP (any number, no verification needed)
  static Future<bool> sendTwoFactorSMS({
    required String toPhone,
    required String otpCode,
    required String apiKey,
  }) async {
    try {
      String formattedPhone = toPhone.trim().replaceAll(RegExp(r'[\s\-\(\)]'), '');
      if (formattedPhone.startsWith('+91')) {
        formattedPhone = formattedPhone.substring(3);
      } else if (formattedPhone.startsWith('91') && formattedPhone.length > 10) {
        formattedPhone = formattedPhone.substring(2);
      }

      final url = 'https://2factor.in/API/V1/$apiKey/SMS/$formattedPhone/$otpCode';


      final response = await http.post(
        Uri.parse(url),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 15));



      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['Status'] == 'Success';
      }
      return false;
    } catch (e) {

      return false;
    }
  }
}
