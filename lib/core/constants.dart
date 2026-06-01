class AppConstants {
  static const String appName = 'CREANNO';

  // ── Backend URL ────────────────────────────────────────────────────────────
  // Override at build time with: --dart-define=API_BASE_URL=https://your-url.railway.app/api
  // Android emulator local:  http://10.0.2.2:5000/api
  // Windows local:           http://localhost:5000/api
  // Production (Railway):    https://company-app-backend.railway.app/api
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://backend-production-8b728.up.railway.app/api',
  );

  // Storage keys
  static const String accessTokenKey = 'access_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String userKey = 'user_data';

  // Pagination
  static const int defaultPageSize = 20;

  // File limits
  static const int maxFileSizeMB = 10;
  static const List<String> allowedDocTypes = ['pdf', 'jpg', 'jpeg', 'png', 'webp'];

  // Task priorities
  static const Map<String, String> taskPriorityLabels = {
    'low': 'Low',
    'medium': 'Medium',
    'high': 'High',
    'urgent': 'Urgent',
  };

  static const Map<String, String> taskStatusLabels = {
    'pending': 'Pending',
    'in_progress': 'In Progress',
    'completed': 'Completed',
    'cancelled': 'Cancelled',
  };

  static const Map<String, String> reimbursementCategories = {
    'travel': 'Travel',
    'food': 'Food & Meals',
    'accommodation': 'Accommodation',
    'office_supplies': 'Office Supplies',
    'medical': 'Medical',
    'training': 'Training',
    'other': 'Other',
  };

  static const Map<String, String> documentTypes = {
    'id_proof': 'ID Proof',
    'address_proof': 'Address Proof',
    'educational': 'Educational',
    'offer_letter': 'Offer Letter',
    'contract': 'Contract',
    'other': 'Other',
  };
}
