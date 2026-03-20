import 'dart:math';

class InviteCodeGenerator {
  static const String _chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  static final Random _random = Random();

  /// Generates a 4-character alphanumeric invite code
  static String generateInviteCode() {
    return String.fromCharCodes(
      Iterable.generate(
          4, (_) => _chars.codeUnitAt(_random.nextInt(_chars.length))),
    );
  }

  /// Validates if a string is a valid invite code format (4 alphanumeric characters)
  static bool isValidInviteCode(String code) {
    if (code.length != 4) return false;
    return code.toUpperCase().split('').every((char) => _chars.contains(char));
  }
}
