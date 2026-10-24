import 'package:dlibphonenumber/dlibphonenumber.dart';

/// A validated phone snapshot, not evidence of SMS or WhatsApp registration.
class ParsedPhoneNumber {
  const ParsedPhoneNumber({required this.e164, required this.region});
  final String e164;
  final String region;
}

abstract final class PhoneNumberService {
  static final PhoneNumberUtil _util = PhoneNumberUtil.instance;

  static ParsedPhoneNumber? parse(String input, {String? region}) {
    final value = input.trim();
    if (value.isEmpty || (!value.startsWith('+') && region == null)) {
      return null;
    }
    try {
      final number = _util.parse(value, value.startsWith('+') ? null : region);
      if (!_util.isValidNumber(number) || number.hasExtension_3()) return null;
      final resolvedRegion = _util.getRegionCodeForNumber(number);
      if (resolvedRegion == null) return null;
      return ParsedPhoneNumber(
        e164: _util.format(number, PhoneNumberFormat.e164),
        region: resolvedRegion,
      );
    } on NumberParseException {
      return null;
    } on IllegalArgumentException {
      return null;
    }
  }

  static String? normalize(String input, {String? region}) =>
      parse(input, region: region)?.e164;
}
