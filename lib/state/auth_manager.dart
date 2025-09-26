// lib/state/auth_manager.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

import '../services/fitstreet_api.dart';
import '../utils/role_storage.dart';
import '../utils/user_role.dart';

class AuthManager extends ChangeNotifier {
  final FitstreetApi api;

  static const _authTokenKey = 'fitstreet_token';

  String? _token;
  String? _role;
  String? _userId;
  String? _trainerId; // this will hold DB _id for API calls

  // In-memory cache for trainer ids
  int? _cachedTrainerNumericId;
  String? _cachedTrainerRawId;

  AuthManager(this.api) {
    _loadFromStorage();
  }

  bool get isLoggedIn => _token != null && _token!.isNotEmpty;
  String? get role => _role;
  String? get token => _token;
  String? get trainerId => _trainerId; // DB id used for API calls
  String? get userId => _userId;

  Future<void> _loadFromStorage() async {
    final sp = await SharedPreferences.getInstance();
    _token = sp.getString('fitstreet_token');
    _role = sp.getString('fitstreet_role');
    _userId = sp.getString('fitstreet_user_id');

    // load DB id into _trainerId (canonical API id)
    _trainerId = sp.getString('fitstreet_trainer_id') ?? sp.getString('fitstreet_trainer_db_id') ?? sp.getString('fitstreet_trainer_db_raw');

    if (sp.containsKey('trainer_numeric_id')) _cachedTrainerNumericId = sp.getInt('trainer_numeric_id');
    if (sp.containsKey('trainer_raw_id')) _cachedTrainerRawId = sp.getString('trainer_raw_id');

    // keep api.token in sync
    if (_token != null && _token!.isNotEmpty) api.token = _token;
    notifyListeners();
  }

  Future<void> _persistTokenRoleId({
    required String token,
    required String role,
    String? id,
  }) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString('fitstreet_token', token);
    await sp.setString('fitstreet_role', role);
    _token = token;
    _role = role;
    api.token = token;

    if (id != null && id.isNotEmpty) {
      // Normalize candidate: if it's a JSON/object string, try to extract an _id or id field
      String candidateId = id.toString().trim();
      try {
        if (candidateId.startsWith('{') || candidateId.startsWith('[')) {
          final decoded = jsonDecode(candidateId);
          if (decoded is Map) {
            final poss = (decoded['_id'] ?? decoded['id'] ?? decoded['trainerId'] ?? decoded['trainerUniqueId']);
            if (poss != null) candidateId = poss.toString();
          }
        }
      } catch (_) {}

      if (role.toLowerCase().contains('trainer')) {
        _trainerId = candidateId;
        await sp.setString('fitstreet_trainer_id', candidateId);

        // Additionally try to extract trainerUniqueId (UI friendly) and persist separately
        final maybeUnique = _extractTrainerUnique(id);
        if (maybeUnique != null && maybeUnique.isNotEmpty) {
          await sp.setString('fitstreet_trainer_unique_id', maybeUnique);
          // also persist an internal raw cache key
          await sp.setString(_kTrainerRawKey, maybeUnique);
          _cachedTrainerRawId = maybeUnique;
        }
      } else {
        _userId = candidateId;
        await sp.setString('fitstreet_user_id', candidateId);
      }

      final numeric = _extractTrailingNumber(candidateId);
      if (numeric != null) await saveTrainerNumericId(numeric);

      if (role.toLowerCase().contains('trainer')) {
        // Keep the raw storage consistent
        await saveRawTrainerId(candidateId);
      }
    }
    try {
      await saveUserRole(userRoleFromString(role));
    } catch (_) {}
    notifyListeners();
  }

  Future<void> logout() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove('fitstreet_token');
    await sp.remove('fitstreet_role');
    await sp.remove('fitstreet_user_id');
    await sp.remove('fitstreet_trainer_id');
    await sp.remove('trainer_numeric_id');
    await sp.remove('trainer_raw_id');
    await sp.remove('fitstreet_trainer_unique_id');
    await sp.remove('fitstreet_trainer_db_id');
    await sp.remove('fitstreet_trainer_db_raw');

    _token = null;
    _role = null;
    _userId = null;
    _trainerId = null;
    _cachedTrainerNumericId = null;
    _cachedTrainerRawId = null;

    api.token = null;

    // Also clear the role stored by role_storage.dart so UI reading getUserRole() sees unknown.
    try {
      await clearUserRole();
    } catch (_) {}

    notifyListeners();
  }


  // ============================
  // OTP wrappers
  // ============================

  Future<Map<String, dynamic>> sendLoginOtp(String mobile) async {
    try {
      final res = await api.sendLoginOtp(mobile);
      final body = _tryDecode(res.body);
      return {'statusCode': res.statusCode, 'body': body};
    } catch (e) {
      return {'statusCode': 0, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> sendSignupOtp(String mobile, {String? role}) async {
    try {
      final res = await api.sendSignupOtp(mobile, type: role);
      final body = _tryDecode(res.body);
      return {'statusCode': res.statusCode, 'body': body};
    } catch (e) {
      return {'statusCode': 0, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> verifyLoginOtp(String mobile, String otp) async {
    try {
      final res = await api.verifyLoginOtp(mobile, otp);
      final body = _tryDecode(res.body);
      final success = _responseIndicatesSuccess(res.statusCode, body);

      if (success) {
        final token = _extractTokenFromBody(body);
        final role = _extractRoleFromBody(body) ?? 'member';
        final id = _extractIdFromBody(body);

        await _persistTokenRoleId(token: token ?? '', role: role, id: id);

        return {
          'statusCode': res.statusCode,
          'body': body,
          'success': true,
          'token': token,
          'role': role,
          'id': id
        };
      } else {
        return {
          'statusCode': res.statusCode,
          'body': body,
          'success': false,
          'message': _extractMessage(body, res.body)
        };
      }
    } on SocketException catch (e) {
      return {'statusCode': 0, 'success': false, 'message': 'Network error: ${e.message}'};
    } catch (e) {
      return {'statusCode': 0, 'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> verifySignupOtp(String mobile, String otp, {String role = 'member'}) async {
    try {
      final res = await api.verifySignupOtp(mobile, otp, role: role);
      final body = _tryDecode(res.body);
      final success = _responseIndicatesSuccess(res.statusCode, body);

      if (success) {
        final token = _extractTokenFromBody(body);
        final roleFromBody = _extractRoleFromBody(body) ?? role;
        final id = _extractIdFromBody(body);

        // persist token + role + id (DB id preferred)
        await _persistTokenRoleId(token: token ?? '', role: roleFromBody, id: id);

        // Extra: persist both readable unique code and DB id if present in response data
        try {
          if (body is Map) {
            final data = body['data'] ?? body;
            if (data is Map) {
              final sp = await SharedPreferences.getInstance();
              final possibleTrainerUnique = (data['trainerUniqueId'] ?? data['trainerUniqueID'] ?? data['trainerUniqueid'])?.toString();
              final possibleDbId = (data['_id'] ?? data['id'])?.toString();

              if (possibleTrainerUnique != null && possibleTrainerUnique.isNotEmpty) {
                await sp.setString('fitstreet_trainer_unique_id', possibleTrainerUnique); // UI code
              }

              if (possibleDbId != null && possibleDbId.isNotEmpty) {
                // canonical API id
                await sp.setString('fitstreet_trainer_db_id', possibleDbId);
                await sp.setString('fitstreet_trainer_id', possibleDbId); // ensure API key is DB _id
                _trainerId = possibleDbId;
              }
            }
          }
        } catch (_) {}

        return {
          'statusCode': res.statusCode,
          'body': body,
          'success': true,
          'token': token,
          'role': roleFromBody,
          'id': id
        };
      } else {
        return {
          'statusCode': res.statusCode,
          'body': body,
          'success': false,
          'message': _extractMessage(body, res.body)
        };
      }
    } on SocketException catch (e) {
      return {'statusCode': 0, 'success': false, 'message': 'Network error: ${e.message}'};
    } catch (e) {
      return {'statusCode': 0, 'success': false, 'message': e.toString()};
    }
  }

  // ============================
  // Profile update (multipart) - improved diagnostics + persist ids
  // ============================
  Future<Map<String, dynamic>> updateTrainerProfile(
      String id, {
        String? fullName,
        String? email,
      }) async {
    try {
      // ---------- Normalize incoming id ----------
      String normalizeId(String raw) {
        if (raw == null) return '';
        final s = raw.toString().trim();
        if (s.isEmpty) return s;

        // 1) If already a plain 24-char hex string, return as-is
        final hexMatch = RegExp(r'^[0-9a-fA-F]{24}$').firstMatch(s);
        if (hexMatch != null) return s;

        // 2) If looks like JSON/object text, try JSON decode
        if (s.startsWith('{') || s.startsWith('[')) {
          try {
            final parsed = jsonDecode(s);
            if (parsed is Map) {
              final cand = (parsed['_id'] ?? parsed['id'] ?? parsed['trainerUniqueId'] ?? parsed['trainerUniqueID']);
              if (cand != null) {
                final candStr = cand.toString();
                final hexInside = RegExp(r'([0-9a-fA-F]{24})').firstMatch(candStr);
                if (hexInside != null) return hexInside.group(1)!;
                return candStr;
              }
            }
          } catch (_) {
            // not valid JSON - continue to regex extraction
          }
        }

        // 3) Try to extract any 24-hex substring
        final extract = RegExp(r'([0-9a-fA-F]{24})').firstMatch(s);
        if (extract != null) return extract.group(1)!;

        // 4) Looser attempt: "id: 68cd..." patterns or _id=
        final loose = RegExp(r'(?:_?id[:=]\s*)([0-9a-fA-F]{8,24})').firstMatch(s);
        if (loose != null) return loose.group(1)!;

        // 5) Fallback: return raw trimmed string
        return s;
      }

      final normalizedId = normalizeId(id);
      debugPrint('AuthManager.updateTrainerProfile -> original id: "$id" -> normalizedId: "$normalizedId"');

      // Use normalizedId for API call
      final useId = normalizedId;

      // ---------- Build fields ----------
      final fields = <String, dynamic>{};
      if (fullName != null) fields['fullName'] = fullName;
      if (email != null) fields['email'] = email;

      // Ensure token from prefs is applied to api
      try {
        final sp = await SharedPreferences.getInstance();
        final storedToken = sp.getString('fitstreet_token') ?? '';
        if (storedToken.isNotEmpty) api.token = storedToken;
        debugPrint('AuthManager.updateTrainerProfile: api.token present: ${api.token != null && api.token!.isNotEmpty}');
      } catch (_) {
        debugPrint('AuthManager.updateTrainerProfile: cannot read prefs for token');
      }

      debugPrint('AuthManager.updateTrainerProfile -> trainerId: $useId');
      debugPrint('AuthManager.updateTrainerProfile -> fields: $fields');

      final streamed = await api.updateTrainerProfileMultipart(useId, fields: fields, files: null);
      final resp = await http.Response.fromStream(streamed);

      debugPrint('AuthManager.updateTrainerProfile -> status: ${resp.statusCode}');
      debugPrint('AuthManager.updateTrainerProfile -> headers: ${resp.headers}');
      debugPrint('AuthManager.updateTrainerProfile -> body: ${resp.body}');

      dynamic body;
      try {
        body = jsonDecode(resp.body);
      } catch (_) {
        body = resp.body;
      }

      // Persist reasonable fields if present
      try {
        if (body is Map) {
          final data = body['data'] ?? body;
          final name = (data is Map) ? (data['fullName'] ?? data['name']) : null;
          final mail = (data is Map) ? data['email'] : null;
          if (name != null) await saveUserName(name.toString());
          if (mail != null) {
            final sp = await SharedPreferences.getInstance();
            await sp.setString('fitstreet_user_email', mail.toString());
          }

          // Persist both readable unique id and DB id if returned
          if (data is Map) {
            final sp = await SharedPreferences.getInstance();
            final trainerUnique = (data['trainerUniqueId'] ?? data['trainerUniqueID'] ?? data['trainerUniqueid'])?.toString();
            final dbId = (data['_id'] ?? data['id'])?.toString();

            if (trainerUnique != null && trainerUnique.isNotEmpty) {
              await sp.setString('fitstreet_trainer_unique_id', trainerUnique);
            }
            if (dbId != null && dbId.isNotEmpty) {
              await sp.setString('fitstreet_trainer_db_id', dbId);
              await sp.setString('fitstreet_trainer_id', dbId); // canonical API id
              _trainerId = dbId;
            }

            // also attempt numeric suffix save for readable code if present
            if (trainerUnique != null) {
              final numericMatch = RegExp(r'(\d+)$').firstMatch(trainerUnique);
              if (numericMatch != null) {
                final numeric = int.tryParse(numericMatch.group(1)!);
                if (numeric != null) await saveTrainerNumericId(numeric);
              }
            }
          }
        }
      } catch (_) {}

      return {'statusCode': resp.statusCode, 'body': body};
    } catch (e, st) {
      debugPrint('AuthManager.updateTrainerProfile exception: $e\n$st');
      return {'statusCode': 0, 'error': e.toString()};
    }
  }


  Future<Map<String, dynamic>> fetchTrainerProfile(String trainerId) async {
    try {
      final res = await api.getTrainer(trainerId);
      final body = _tryDecode(res.body);
      if (res.statusCode == 200) {
        if (body is Map) {
          final data = body['data'] ?? body;
          final name = (data is Map) ? (data['fullName'] ?? data['name']) : null;
          final email = (data is Map) ? data['email'] : null;
          if (name != null) await saveUserName(name.toString());
          if (email != null) {
            final sp = await SharedPreferences.getInstance();
            await sp.setString('fitstreet_user_email', email.toString());
          }

          // Save BOTH IDs: readable unique code and DB _id (and make DB id canonical for API)
          final possibleTrainerUnique = (data is Map) ? (data['trainerUniqueId'] ?? data['trainerUniqueID'] ?? data['trainerUniqueid']) : null;
          final possibleDbId = (data is Map) ? (data['_id'] ?? data['id']) : null;

          final sp = await SharedPreferences.getInstance();
          if (possibleTrainerUnique != null) {
            final unique = possibleTrainerUnique.toString();
            await sp.setString('fitstreet_trainer_unique_id', unique); // UI code
            final numeric = _extractTrailingNumber(unique);
            if (numeric != null) await saveTrainerNumericId(numeric);
          }

          if (possibleDbId != null) {
            final dbid = possibleDbId.toString();
            await sp.setString('fitstreet_trainer_db_id', dbid);
            await sp.setString('fitstreet_trainer_id', dbid); // canonical API id
            _trainerId = dbid;
          }
        }
        return {'success': true, 'body': body};
      }
      return {'success': false, 'body': body};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // -------------------------
  // Helper: extract trailing digits from strings like "Bull2508" -> 2508
  // -------------------------
  int? _extractTrailingNumber(String s) {
    final match = RegExp(r'(\d+)$').firstMatch(s);
    if (match != null) {
      try {
        return int.parse(match.group(1)!);
      } catch (_) {}
    }
    return null;
  }

  /// Try to extract a clean trainerUniqueId (like "Bull2512") from mixed inputs.
  String? _extractTrainerUnique(dynamic cand) {
    if (cand == null) return null;

    try {
      // If it's already a map-like object, read directly
      if (cand is Map) {
        final v = cand['trainerUniqueId'] ?? cand['trainerUniqueID'] ?? cand['trainerUniqueid'];
        if (v != null) return v.toString();
      }

      // If it's a plain string that might be JSON, try decode
      final s = cand.toString().trim();
      if (s.startsWith('{') || s.startsWith('[')) {
        try {
          final parsed = jsonDecode(s);
          if (parsed is Map) {
            final v = parsed['trainerUniqueId'] ?? parsed['trainerUniqueID'] ?? parsed['trainerUniqueid'];
            if (v != null) return v.toString();
          }
        } catch (_) {
          // fallthrough to regex
        }
      }

      // Look for trainerUniqueId: Bull123 or trainerUniqueId":"Bull123 patterns
      final uniMatch = RegExp("trainerUniqueId\\s*[:=]\\s*['\"]?([A-Za-z0-9_-]+)['\"]?").firstMatch(s);
      if (uniMatch != null) return uniMatch.group(1);

      // If the candidate itself is short (like Bull2512), return it
      final shortMatch = RegExp(r'^[A-Za-z][A-Za-z0-9\-_]{2,30}$').firstMatch(s);
      if (shortMatch != null) return s;

    } catch (_) {}
    return null;
  }

  /// Return the canonical DB id to use for trainer endpoints (API id).
  /// Falls back to legacy keys if required.
  Future<String?> getApiTrainerId() async {
    final sp = await SharedPreferences.getInstance();
    final dbid = sp.getString('fitstreet_trainer_db_id') ?? sp.getString('fitstreet_trainer_id') ?? sp.getString('fitstreet_trainer_db_raw');
    if (dbid != null && dbid.isNotEmpty) return dbid;
    return null;
  }

  // ============================
  // Persistence helpers for trainer numeric/raw ids
  // ============================
  static const String _kTrainerNumericKey = 'trainer_numeric_id';
  static const String _kTrainerRawKey = 'trainer_raw_id';

  Future<void> saveTrainerNumericId(int numeric) async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setInt(_kTrainerNumericKey, numeric);
      _cachedTrainerNumericId = numeric;
    } catch (_) {}
  }

  Future<int?> getTrainerNumericId() async {
    if (_cachedTrainerNumericId != null) return _cachedTrainerNumericId;
    try {
      final sp = await SharedPreferences.getInstance();
      if (sp.containsKey(_kTrainerNumericKey)) {
        _cachedTrainerNumericId = sp.getInt(_kTrainerNumericKey);
        return _cachedTrainerNumericId;
      }
    } catch (_) {}
    return null;
  }

  Future<void> saveRawTrainerId(String raw) async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setString(_kTrainerRawKey, raw);
      _cachedTrainerRawId = raw;

      // Also persist UI-friendly unique id if it looks like one
      final maybeUnique = _extractTrainerUnique(raw);
      if (maybeUnique != null && maybeUnique.isNotEmpty) {
        await sp.setString('fitstreet_trainer_unique_id', maybeUnique);
      }
    } catch (_) {}
  }

  Future<String?> getRawTrainerId() async {
    if (_cachedTrainerRawId != null && _cachedTrainerRawId!.isNotEmpty) return _cachedTrainerRawId;
    try {
      final sp = await SharedPreferences.getInstance();
      // Prefer UI-friendly unique id first
      final unique = sp.getString('fitstreet_trainer_unique_id');
      if (unique != null && unique.isNotEmpty) {
        _cachedTrainerRawId = unique;
        return unique;
      }
      final raw = sp.getString(_kTrainerRawKey);
      if (raw != null && raw.isNotEmpty) {
        _cachedTrainerRawId = raw;
        return raw;
      }
    } catch (_) {}
    return null;
  }

  Future<void> clearTrainerIds() async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.remove(_kTrainerNumericKey);
      await sp.remove(_kTrainerRawKey);
      await sp.remove('fitstreet_trainer_unique_id');
      await sp.remove('fitstreet_trainer_db_id');
      await sp.remove('fitstreet_trainer_db_raw');
    } catch (_) {}
    _cachedTrainerNumericId = null;
    _cachedTrainerRawId = null;
  }

  // ============================
  // Helpers
  // ============================
  dynamic _tryDecode(String? body) {
    if (body == null) return null;
    try {
      return jsonDecode(body);
    } catch (_) {
      return body;
    }
  }

  bool _responseIndicatesSuccess(int statusCode, dynamic body) {
    if (statusCode == 200 || statusCode == 201) return true;
    if (body is Map) {
      final s = (body['status']?.toString() ?? '').toLowerCase();
      if (s == 'success' || s == 'ok') return true;
      if (body['success'] == true) return true;
      if ((body['code']?.toString() ?? '') == '200') return true;
    }
    return false;
  }

  String? _extractTokenFromBody(dynamic body) {
    if (body is Map) {
      return (body['token'] ??
          body['accessToken'] ??
          body['data']?['token'] ??
          body['data']?['accessToken'])
          ?.toString();
    }
    return null;
  }

  String? _extractRoleFromBody(dynamic body) {
    if (body is Map) {
      return (body['role'] ??
          body['user']?['role'] ??
          body['data']?['user']?['role'] ??
          body['userType'] ??
          body['type'])
          ?.toString();
    }
    return null;
  }

  /// Robust id extraction: looks for many common fields and nested locations
  String? _extractIdFromBody(dynamic body) {
    if (body is Map) {
      final candidates = [
        body['id'],
        body['_id'],
        body['userId'],
        body['trainerId'],
        body['trainerUniqueId'],
        body['trainerUniqueID'],
        body['trainerUniqueid'],
        body['trainer_id'],
        body['trainer'],
        body['data']?['id'],
        body['data']?['_id'],
        body['data']?['trainerId'],
        body['data']?['trainerUniqueId'],
        body['data']?['trainerUniqueID'],
        body['data']?['user']?['_id'],
        body['data']?['_id'],
      ];

      for (final c in candidates) {
        if (c != null) return c.toString();
      }

      try {
        if (body['data'] is Map) {
          final dd = body['data'] as Map;
          if (dd['user'] is Map && dd['user']['_id'] != null) return dd['user']['_id'].toString();
          if (dd['trainer'] is Map && dd['trainer']['_id'] != null) return dd['trainer']['_id'].toString();
        }
      } catch (_) {}
    }
    return null;
  }

  String _extractMessage(dynamic body, String rawBody) {
    if (body is Map) {
      if (body['message'] != null) return body['message'].toString();
      if (body['error'] != null) return body['error'].toString();
      if (body['msg'] != null) return body['msg'].toString();
    }
    return rawBody;
  }
}
