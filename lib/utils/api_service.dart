import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = "https://api.fitstreet.in"; // Replace with your API base

  // Example: User Login
  static Future<Map<String, dynamic>> loginUser(String mobile, String otp) async {
    final url = Uri.parse("$baseUrl/auth/login");
    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"mobile": mobile, "otp": otp}),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception("Failed login: ${response.body}");
    }
  }

  // Example: Get Trainers
  static Future<List<dynamic>> getTrainers() async {
    final url = Uri.parse("$baseUrl/trainers");
    final response = await http.get(url);

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as List;
    } else {
      throw Exception("Failed trainers: ${response.body}");
    }
  }

  // Example: Complete Profile
  static Future<bool> completeProfile(Map<String, dynamic> data) async {
    final url = Uri.parse("$baseUrl/user/profile");
    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(data),
    );
    return response.statusCode == 200;
  }
}
