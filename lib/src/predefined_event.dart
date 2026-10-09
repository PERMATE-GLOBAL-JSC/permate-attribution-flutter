/// Predefined event name strings for consistent instrumentation (finance niche + common funnel).
/// Other snake_case names may be used if accepted for your app on the server.
///
/// Do not log `install`, `session_start`, or `uninstall` via `logEvent` — the system records those.
abstract final class PredefinedEvent {
  // Account
  static const registrationComplete = 'registration_complete';
  static const profileComplete = 'profile_complete';
  static const login = 'login';
  static const accountCreated = 'account_created';
  static const kycVerified = 'kyc_verified';

  // Application / product
  static const applicationSubmitted = 'application_submitted';
  static const applicationApproved = 'application_approved';
  static const applicationRejected = 'application_rejected';
  static const cardActivated = 'card_activated';
  static const linkedBankAccount = 'linked_bank_account';
  static const firstDeposit = 'first_deposit';
  static const firstTransaction = 'first_transaction';
  static const loanDisbursed = 'loan_disbursed';

  // Commerce / engagement
  static const search = 'search';
  static const viewContent = 'view_content';
  static const addToCart = 'add_to_cart';
  static const initiateCheckout = 'initiate_checkout';
  static const addPaymentInfo = 'add_payment_info';
  static const purchase = 'purchase';
  static const subscribe = 'subscribe';
  static const cancelSubscription = 'cancel_subscription';
  static const share = 'share';
  static const invite = 'invite';
  static const rateApp = 'rate_app';
  static const tutorialComplete = 'tutorial_complete';
}
