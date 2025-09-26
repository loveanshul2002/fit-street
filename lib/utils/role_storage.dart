// lib/utils/role_storage.dart
import 'package:shared_preferences/shared_preferences.dart';
import 'user_role.dart';

const _kRoleKey = 'fitstreet_user_role';
const _kNameKey = 'fitstreet_user_name';
const _kProfileCompleteKey = 'fitstreet_profile_complete';
const _kEmailKey = 'fitstreet_user_email';

/// ===== Role Handling =====
Future<void> saveUserRole(UserRole r) async {
  final sp = await SharedPreferences.getInstance();
  await sp.setString(_kRoleKey, userRoleToString(r));
}

Future<UserRole> getUserRole() async {
  final sp = await SharedPreferences.getInstance();
  final s = sp.getString(_kRoleKey) ?? 'unknown';
  return userRoleFromString(s);
}

Future<void> clearUserRole() async {
  final sp = await SharedPreferences.getInstance();
  await sp.remove(_kRoleKey);
}

/// ===== Name Handling =====
Future<void> saveUserName(String name) async {
  final sp = await SharedPreferences.getInstance();
  await sp.setString(_kNameKey, name);
}

Future<String?> getUserName() async {
  final sp = await SharedPreferences.getInstance();
  return sp.getString(_kNameKey);
}

Future<void> clearUserName() async {
  final sp = await SharedPreferences.getInstance();
  await sp.remove(_kNameKey);
}

/// ===== Email Handling =====
Future<void> saveUserEmail(String email) async {
  final sp = await SharedPreferences.getInstance();
  await sp.setString(_kEmailKey, email);
}

Future<String?> getUserEmail() async {
  final sp = await SharedPreferences.getInstance();
  return sp.getString(_kEmailKey);
}

Future<void> clearUserEmail() async {
  final sp = await SharedPreferences.getInstance();
  await sp.remove(_kEmailKey);
}

/// ===== Profile Completion =====
Future<void> saveProfileComplete(bool v) async {
  final sp = await SharedPreferences.getInstance();
  await sp.setBool(_kProfileCompleteKey, v);
}

Future<bool> getProfileComplete() async {
  final sp = await SharedPreferences.getInstance();
  return sp.getBool(_kProfileCompleteKey) ?? false;
}

Future<void> clearProfileComplete() async {
  final sp = await SharedPreferences.getInstance();
  await sp.remove(_kProfileCompleteKey);
}
