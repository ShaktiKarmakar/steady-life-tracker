import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Resolves and applies a Hugging Face token for `flutter_gemma` downloads.
///
/// LFS file requests often return 401 without a token. The token is read from
/// `--dart-define=HUGGINGFACE_TOKEN=hf_...` first, then from device storage.
class HuggingFaceConfig {
  HuggingFaceConfig._();

  static const prefsKey = 'steady_huggingface_token';

  static String? _lastApplied;
  static bool _initializedWithCurrentToken = false;

  static Future<String?> resolveToken() async {
    const env = String.fromEnvironment('HUGGINGFACE_TOKEN');
    final envTrim = env.trim();
    if (envTrim.isNotEmpty) return envTrim;

    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(prefsKey)?.trim();
    if (stored != null && stored.isNotEmpty) return stored;
    return null;
  }

  /// Persists a user token (or clears it). Next [applyToFlutterGemma] will
  /// reconfigure the download stack.
  static Future<void> saveUserToken(String? token) async {
    final prefs = await SharedPreferences.getInstance();
    final t = token?.trim();
    if (t == null || t.isEmpty) {
      await prefs.remove(prefsKey);
    } else {
      await prefs.setString(prefsKey, t);
    }
    _lastApplied = null;
    _initializedWithCurrentToken = false;
  }

  /// Rebuilds the Gemma service registry with the current token.
  ///
  /// [ServiceRegistry] only picks up [huggingFaceToken] on first
  /// [FlutterGemma.initialize], so we reset when the token changes.
  ///
  /// Important: `null == null` is true in Dart — never skip the very first
  /// `FlutterGemma.initialize()` just because both resolved token and cache are null.
  static Future<void> applyToFlutterGemma() async {
    final token = await resolveToken();
    if (_initializedWithCurrentToken && _lastApplied == token) return;

    FlutterGemma.reset();
    await FlutterGemma.initialize(
      huggingFaceToken: token,
      maxDownloadRetries: 5,
    );
    _lastApplied = token;
    _initializedWithCurrentToken = true;
  }
}
