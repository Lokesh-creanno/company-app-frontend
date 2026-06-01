/// ─────────────────────────────────────────────────────────────────────────────
/// CREANNO — AI Configuration
/// ─────────────────────────────────────────────────────────────────────────────
///
/// FREE Gemini API Key Setup (takes 1 minute):
///   1. Go to  https://aistudio.google.com/app/apikey
///   2. Sign in with any Google account
///   3. Click "Create API Key" → copy the key
///   4. Paste it below as [geminiApiKey]
///
/// FREE Tier Limits (Gemini 1.5 Flash):
///   ✅  1,500 requests per day
///   ✅  1,000,000 tokens per day
///   ✅  15 requests per minute
///   ✅  No credit card required
/// ─────────────────────────────────────────────────────────────────────────────
class AiConfig {
  // 🔑 Paste your free Gemini API key here:
  static const geminiApiKey = 'AIzaSyB_REPLACE_WITH_YOUR_FREE_KEY';

  /// Set to false to hide all AI features from the UI
  static const aiEnabled = true;

  /// Returns true only when a real key is configured
  static bool get isReady =>
      aiEnabled &&
      geminiApiKey.isNotEmpty &&
      !geminiApiKey.contains('REPLACE_WITH');
}
