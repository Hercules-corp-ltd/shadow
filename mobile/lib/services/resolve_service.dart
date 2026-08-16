import '../models/site.dart';
import 'api_client.dart';
import 'fetch_outcome.dart';

/// Hermes / URL-to-Token resolution — converts a Shadow ID or domain
/// into the actual on-chain site record.
///
/// Returns a [FetchOutcome] rather than a nullable Site. Both methods used to
/// swallow every exception into `null`, and the screen above rendered that as
/// "the identifier is not registered, may be expired, or the content is no
/// longer pinned" — telling the user their domain does not exist when the real
/// cause was usually that the app could not reach anything at all.
class ResolveService {
  final ApiClient _api = ApiClient.instance;

  Future<FetchOutcome<Site>> resolveById(String shadowId) =>
      _resolve('/resolve/$shadowId');

  Future<FetchOutcome<Site>> resolveDomain(String domain) =>
      _resolve('/resolve/domain/$domain');

  Future<FetchOutcome<Site>> _resolve(String path) async {
    try {
      final res = await _api.get<Map<String, dynamic>>(path);
      final data = res.data;
      if (data == null || data.isEmpty) return const FetchNotFound();
      return FetchSuccess(Site.fromJson(data));
    } catch (error) {
      return outcomeFromDio<Site>(error);
    }
  }
}
