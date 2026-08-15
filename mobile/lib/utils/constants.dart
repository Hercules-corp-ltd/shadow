// Constants for Shadow mobile app
class ShadowConstants {
  // API endpoints
  static const String defaultApiUrl = 'http://localhost:8080/api';
  static const String defaultSolanaRpc = 'https://api.devnet.solana.com';
  
  // Storage keys
  static const String walletKey = 'shadow_wallet';
  static const String authTokenKey = 'shadow_auth_token';
  static const String sessionKey = 'shadow_session';
  static const String settingsKey = 'shadow_settings';
  
  // UI constants
  static const double defaultPadding = 16.0;
  static const double smallPadding = 8.0;
  static const double largePadding = 24.0;
  static const double borderRadius = 12.0;
  static const double cardElevation = 2.0;
  
  // Animation durations
  static const Duration shortAnimation = Duration(milliseconds: 200);
  static const Duration mediumAnimation = Duration(milliseconds: 400);
  static const Duration longAnimation = Duration(milliseconds: 600);
  
  // Limits
  static const int maxHistoryItems = 1000;
  static const int maxBookmarks = 500;
  static const int searchResultLimit = 20;
  static const int defaultPageSize = 20;
  
  // Timeouts
  static const Duration networkTimeout = Duration(seconds: 30);
  static const Duration cacheTimeout = Duration(hours: 1);
  
  // Error messages
  static const String networkError = 'Network connection failed';
  static const String authError = 'Authentication failed';
  static const String validationError = 'Invalid input';
  static const String unknownError = 'An unknown error occurred';
  
  // Success messages
  static const String bookmarkAdded = 'Bookmark added successfully';
  static const String bookmarkRemoved = 'Bookmark removed';
  static const String historyCleared = 'History cleared';
  static const String domainRegistered = 'Domain registered successfully';
}

