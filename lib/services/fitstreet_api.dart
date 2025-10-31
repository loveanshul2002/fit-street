// lib/services/fitstreet_api.dart
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

/// FitstreetApi - central API helper used across the app.
class FitstreetApi {
  final String baseUrl;
  String? token;

  FitstreetApi(this.baseUrl, {this.token});

  Map<String, String> _jsonHeaders() => {
    'Content-Type': 'application/json',
    if (token != null && token!.isNotEmpty) 'Authorization': 'Bearer $token',
  };

  Map<String, String> _multipartHeaders() => {
    if (token != null && token!.isNotEmpty) 'Authorization': 'Bearer $token',
  };

  // ----------------------
  // Auth endpoints
  // ----------------------
  Future<http.Response> sendSignupOtp(String mobile, {String? type}) {
    final uri = Uri.parse('$baseUrl/api/auth/send-otp-hc');
    final body = jsonEncode({'mobileNumber': mobile, if (type != null) 'type': type});
    return http.post(uri, headers: _jsonHeaders(), body: body);
  }

  Future<http.Response> sendLoginOtp(String mobile) {
    final uri = Uri.parse('$baseUrl/api/auth/login/send-otp-hc');
    final body = jsonEncode({'mobileNumber': mobile});
    return http.post(uri, headers: _jsonHeaders(), body: body);
  }

  Future<http.Response> verifySignupOtp(String mobile, String otp, {String? role}) {
    final uri = Uri.parse('$baseUrl/api/auth/verify-otp-hc');
    final body = jsonEncode({'mobileNumber': mobile, 'otp': otp, if (role != null) 'type': role});
    return http.post(uri, headers: _jsonHeaders(), body: body);
  }

  Future<http.Response> verifyLoginOtp(String mobile, String otp) {
    final uri = Uri.parse('$baseUrl/api/auth/login/verify-otp-hc'); // <-- correct path
    final body = jsonEncode({'mobileNumber': mobile, 'otp': otp});
    return http.post(uri, headers: _jsonHeaders(), body: body);
  }

  // ----------------------
  // Session booking endpoints
  // ----------------------
  Future<http.Response> bookSession(Map<String, dynamic> data, File paymentScreenshot) async {
    final uri = Uri.parse('$baseUrl/api/session-bookings');
    var request = http.MultipartRequest('POST', uri)
      ..headers.addAll(_multipartHeaders());

    // Add all the form fields
    data.forEach((key, value) {
      if (value != null) request.fields[key] = value.toString();
    });

    // Add the payment screenshot
    request.files.add(
      await http.MultipartFile.fromPath(
        'paymentSSImageURL',
        paymentScreenshot.path,
      ),
    );

    final response = await request.send();
    return http.Response.fromStream(await response);
  }


  // ----------------------
  // Trainer endpoints
  // ----------------------
  Future<http.Response> getTrainer(String trainerId) {
    final uri = Uri.parse('$baseUrl/api/trainers/$trainerId');
    return http.get(uri, headers: _jsonHeaders());
  }

  Future<http.Response> getTrainerSlots(String trainerId) {
    final uri = Uri.parse('$baseUrl/api/trainers/slots/$trainerId');
    return http.get(uri, headers: _jsonHeaders());
  }

  Future<http.Response> updateTrainerSlots(String trainerId, List<dynamic> slots) {
    final uri = Uri.parse('$baseUrl/api/trainers/slots/$trainerId');
    final body = jsonEncode({'slots': slots});
    return http.post(uri, headers: _jsonHeaders(), body: body);
  }

  /// List all trainers
  Future<http.Response> getAllTrainers() {
    final uri = Uri.parse('$baseUrl/api/trainers');
    return http.get(uri, headers: _jsonHeaders());
  }

  /// Slot availability endpoints (alternate endpoint names)
  Future<http.Response> getSlotAvailabilityDetails(String trainerId) {
    final uri = Uri.parse('$baseUrl/api/trainers/slotAvailabilityDetails/$trainerId');
    return http.get(uri, headers: _jsonHeaders());
  }

  Future<http.Response> saveSlotAvailabilityDetails(String trainerId, List<dynamic> slots) {
    // this endpoint expects { "slots": [ { "day": "Mon", "slots": [...] }, ... ] }
    final uri = Uri.parse('$baseUrl/api/trainers/slotAvailabilityDetails/$trainerId');
    final body = jsonEncode({'slots': slots});
    return http.post(uri, headers: _jsonHeaders(), body: body);
  }

  Future<http.StreamedResponse> updateTrainerProfileMultipart(
      String trainerId, {
        required Map<String, dynamic> fields,
        Map<String, File>? files,
      }) async {
    final uri = Uri.parse('$baseUrl/api/auth/trainer/$trainerId');
    final request = http.MultipartRequest('PUT', uri);
    request.headers.addAll(_multipartHeaders());

    fields.forEach((k, v) {
      if (v != null) request.fields[k] = v.toString();
    });

    if (files != null) {
      for (final entry in files.entries) {
        final file = entry.value;
        final stream = http.ByteStream(Stream.castFrom(file.openRead()));
        final length = await file.length();
        final filename = p.basename(file.path);
        final multipartFile = http.MultipartFile(entry.key, stream, length, filename: filename);
        request.files.add(multipartFile);
      }
    }

    return request.send();
  }

 // Replace the existing updateTrainerPreferences method

/// Update trainer preferences in MongoDB
Future<http.Response> updateTrainerPreferences(String trainerId, Map<String, dynamic> preferences) async {
  // Use the existing trainer profile endpoint which should update the mode field
  final uri = Uri.parse('$baseUrl/api/auth/trainer/$trainerId');
  final request = http.MultipartRequest('PUT', uri);
  request.headers.addAll(_multipartHeaders());
  
  preferences.forEach((k, v) {
    if (v != null) request.fields[k] = v.toString();
  });
  
  final streamed = await request.send();
  return http.Response.fromStream(streamed);
}

  /// Get trainer preferences from MongoDB
  Future<http.Response> getTrainerPreferences(String trainerId) {
    final uri = Uri.parse('$baseUrl/api/trainer/preferences/$trainerId');
    return http.get(uri, headers: _jsonHeaders());
  }

  // ----------------------
  // Specialization proofs
  // ----------------------
  /// Create specialization proof WITH image (multipart)
  Future<http.Response> createSpecializationProof(
      String trainerId,
      String specialization,
      File image, {
        String? certificateName,
      }) async {
    final uri = Uri.parse('$baseUrl/api/trainers/trainerSpecializationProof/$trainerId');
    final request = http.MultipartRequest('POST', uri);
    request.headers.addAll(_multipartHeaders());

    request.fields['specialization'] = specialization;
    request.fields['certificateName'] = certificateName ?? p.basename(image.path);

    final stream = http.ByteStream(Stream.castFrom(image.openRead()));
    final length = await image.length();
    request.files.add(http.MultipartFile('certificateImageURL', stream, length, filename: p.basename(image.path)));

    final streamed = await request.send();
    return http.Response.fromStream(streamed);
  }
  

  /// Create specialization proof WITHOUT image (JSON only)
  Future<http.Response> createSpecializationProofMinimal(
      String trainerId,
      String specialization, {
        String? certificateName,
      }) {
    final uri = Uri.parse('$baseUrl/api/trainers/trainerSpecializationProof/$trainerId');
    final body = jsonEncode({
      'specialization': specialization,
      'certificateName': (certificateName == null || certificateName.isEmpty) ? null : certificateName,
      // certificateImageURL intentionally left out → server should store null
    });
    return http.post(uri, headers: _jsonHeaders(), body: body);
  }

  Future<http.Response> getSpecializationProofs(String trainerId) {
    final uri = Uri.parse('$baseUrl/api/trainers/trainerSpecializationProof/$trainerId');
    return http.get(uri, headers: _jsonHeaders());
  }

  Future<http.Response> deleteSpecializationProof(String trainerId, String proofId) {
    final uri = Uri.parse('$baseUrl/api/trainers/trainerSpecializationProof/$trainerId/$proofId');
    return http.delete(uri, headers: _jsonHeaders());
  }


  // ----------------------
  // User endpoints
  // ----------------------
  Future<http.Response> getUser(String userId) {
    final uri = Uri.parse('$baseUrl/api/users/$userId');
    return http.get(uri, headers: _jsonHeaders());
  }

  Future<http.Response> updateUserMultipart(String userId, Map<String, dynamic> fields, {File? image}) async {
    final uri = Uri.parse('$baseUrl/api/auth/user/$userId');
    final request = http.MultipartRequest('PUT', uri);
    request.headers.addAll(_multipartHeaders());
    fields.forEach((k, v) {
      if (v != null) request.fields[k] = v.toString();
    });
    if (image != null) {
      final stream = http.ByteStream(Stream.castFrom(image.openRead()));
      final length = await image.length();
      request.files.add(http.MultipartFile('userImageURL', stream, length, filename: p.basename(image.path)));
    }
    final streamed = await request.send();
    return http.Response.fromStream(streamed);
  }
  // ----------------------
  //Notifications
  // ----------------------
  Future<http.Response> getNotifications(String userType, String userId) {
    final uri = Uri.parse('$baseUrl/api/common/notifications/$userType/$userId/unread');
    return http.get(uri, headers: _jsonHeaders());
  }

  Future<http.Response> markNotificationsAsRead(String userId, String userType) {
    final uri = Uri.parse('$baseUrl/api/common/notifications/$userId/read/$userType');
    return http.patch(uri, headers: _jsonHeaders());
  }

  // ----------------------
  // Common
  // ----------------------
  Future<http.Response> getCityStateByPincode(String pincode) {
    final uri = Uri.parse('$baseUrl/api/common/city-state-by-pincode/$pincode');
    return http.get(uri, headers: _jsonHeaders());
  }

  // ----------------------
  // Wallet
  // ----------------------
  Future<http.Response> getUserSessionPayments(String userId) {
    final uri = Uri.parse('$baseUrl/api/wallet/sessionPayment/user/$userId');
    return http.get(uri, headers: _jsonHeaders());
  }

  Future<http.Response> getTrainerSessionPayments(String trainerId) {
    final uri = Uri.parse('$baseUrl/api/wallet/sessionPayment/trainer/$trainerId');
    return http.get(uri, headers: _jsonHeaders());
  }

  Future<http.Response> getWithdrawalAmount(String trainerId) {
    final uri = Uri.parse('$baseUrl/api/wallet/withdrawalAmount/$trainerId');
    return http.get(uri, headers: _jsonHeaders());
  }

  Future<http.Response> getWithdrawals(String trainerId) {
    final uri = Uri.parse('$baseUrl/api/wallet/withdrawals/$trainerId');
    return http.get(uri, headers: _jsonHeaders());
  }

  Future<http.Response> requestWithdrawal(String trainerId, num amount) {
    final uri = Uri.parse('$baseUrl/api/wallet/requestWithdrawal/$trainerId');
    final body = jsonEncode({'amount': amount});
    return http.post(uri, headers: _jsonHeaders(), body: body);
  }
}
