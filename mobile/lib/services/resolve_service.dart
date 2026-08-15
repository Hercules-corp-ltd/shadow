import '../models/site.dart';
import 'api_client.dart';

/// Hermes / URL-to-Token resolution — converts a Shadow ID or domain
/// into the actual on-chain site record.
class ResolveService {
  final ApiClient _api = ApiClient.instance;

  Future<Site?> resolveById(String shadowId) async {
    try {
      final res =
          await _api.get<Map<String, dynamic>>('/resolve/$shadowId');
      return Site.fromJson(res.data ?? const {});
    } catch (_) {
      return null;
    }
  }

  Future<Site?> resolveDomain(String domain) async {
    try {
      final res = await _api
          .get<Map<String, dynamic>>('/resolve/domain/$domain');
      return Site.fromJson(res.data ?? const {});
    } catch (_) {
      return null;
    }
  }
}
