/// Everything Shadow derives for one account on one site.
///
/// Holds secrets in memory and is deliberately not serialisable: nothing here
/// should ever reach disk, analytics or a crash report. It can always be
/// regenerated from the recovery phrase, so there is no reason to store it.
class SiteIdentity {
  const SiteIdentity({
    required this.registrableDomain,
    required this.email,
    required this.password,
    required this.handle,
    required this.accountIndex,
    required this.version,
  });

  /// The domain this identity is keyed on, after normalisation.
  final String registrableDomain;

  /// The alias to hand the site. Mail sent here reaches the user without the
  /// site ever learning their real address.
  final String email;

  final String password;

  /// The username, where the site asks for one separately from the email.
  final String handle;

  /// Which account this is on the same site, for people who keep more than
  /// one. Index 0 is the default.
  final int accountIndex;

  /// Bumped when a site forces a reset or suffers a breach. Changing it
  /// changes the password and nothing else, which is why the counter has to
  /// be recorded in the adapter rather than remembered by the user.
  final int version;

  /// A redacted form safe to log or screenshot.
  @override
  String toString() =>
      'SiteIdentity($registrableDomain, account $accountIndex, v$version, '
      'email: $email, password: ${'•' * password.length})';

  bool get isRotated => version > 1;
}
