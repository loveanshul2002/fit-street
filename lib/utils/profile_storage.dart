// lib/utils/profile_storage.dart
import 'package:shared_preferences/shared_preferences.dart';

const _kMobile = 'fitstreet_mobile';
const _kGender = 'fitstreet_gender';
const _kAge = 'fitstreet_age';
const _kProfileCompleted = 'fitstreet_profile_completed';

enum StoredGender { male, female, other, unknown }

String _genderToString(StoredGender g) {
  switch (g) {
    case StoredGender.male:
      return 'male';
    case StoredGender.female:
      return 'female';
    case StoredGender.other:
      return 'other';
    default:
      return 'unknown';
  }
}

StoredGender _genderFromString(String s) {
  switch (s) {
    case 'male':
      return StoredGender.male;
    case 'female':
      return StoredGender.female;
    case 'other':
      return StoredGender.other;
    default:
      return StoredGender.unknown;
  }
}

Future<void> saveMobile(String mobile) async {
  final sp = await SharedPreferences.getInstance();
  await sp.setString(_kMobile, mobile);
}

Future<String?> getMobile() async {
  final sp = await SharedPreferences.getInstance();
  return sp.getString(_kMobile);
}

Future<void> saveGender(StoredGender g) async {
  final sp = await SharedPreferences.getInstance();
  await sp.setString(_kGender, _genderToString(g));
}

Future<StoredGender> getGender() async {
  final sp = await SharedPreferences.getInstance();
  final s = sp.getString(_kGender) ?? 'unknown';
  return _genderFromString(s);
}

Future<void> saveAge(int age) async {
  final sp = await SharedPreferences.getInstance();
  await sp.setInt(_kAge, age);
}

Future<int?> getAge() async {
  final sp = await SharedPreferences.getInstance();
  return sp.containsKey(_kAge) ? sp.getInt(_kAge) : null;
}

Future<void> saveProfileCompleted(bool done) async {
  final sp = await SharedPreferences.getInstance();
  await sp.setBool(_kProfileCompleted, done);
}

Future<bool> getProfileCompleted() async {
  final sp = await SharedPreferences.getInstance();
  return sp.getBool(_kProfileCompleted) ?? false;
}

Future<void> clearPartialProfile() async {
  final sp = await SharedPreferences.getInstance();
  await sp.remove(_kMobile);
  await sp.remove(_kGender);
  await sp.remove(_kAge);
  await sp.remove(_kProfileCompleted);
}
