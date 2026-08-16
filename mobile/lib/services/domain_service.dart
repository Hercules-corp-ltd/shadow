import '../models/domain.dart';
import 'api_client.dart';
import 'fetch_outcome.dart';

/// Olympus domain management — register, resolve, transfer, renew.
class DomainService {
  final ApiClient _api = ApiClient.instance;

  /// Looks up a single domain.
  ///
  /// Returns an outcome rather than a nullable domain. The old `null` meant
  /// both "no such domain" and "the request blew up", and the details screen
  /// treated null as still-loading — so any error left a spinner turning
  /// forever under the subtitle "Loading...".
  Future<FetchOutcome<ShadowDomain>> get(String domain) async {
    try {
      final res = await _api.get<Map<String, dynamic>>('/domains/$domain');
      final data = res.data;
      if (data == null || data.isEmpty) return const FetchNotFound();
      return FetchSuccess(ShadowDomain.fromJson(data));
    } catch (error) {
      return outcomeFromDio<ShadowDomain>(error);
    }
  }

  Future<List<ShadowDomain>> search(String query, {int limit = 20}) async {
    final res = await _api.get<List<dynamic>>(
      '/domains/search',
      query: {'q': query, 'limit': limit},
    );
    return (res.data ?? [])
        .map((e) => ShadowDomain.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<ShadowDomain>> ownerDomains(String wallet) async {
    final res = await _api.get<List<dynamic>>('/domains/owner/$wallet');
    return (res.data ?? [])
        .map((e) => ShadowDomain.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<ShadowDomain> register({
    required String domain,
    required String programAddress,
    required String ownerPubkey,
    int? years,
  }) async {
    final res = await _api.post<Map<String, dynamic>>('/domains', data: {
      'domain': domain,
      'program_address': programAddress,
      'owner_pubkey': ownerPubkey,
      'years': years ?? 1,
    });
    return ShadowDomain.fromJson(res.data ?? const {});
  }

  Future<void> transfer({
    required String domain,
    required String toPubkey,
  }) async {
    await _api.post<void>('/domains/$domain/transfer', data: {
      'to_pubkey': toPubkey,
    });
  }

  Future<void> renew({required String domain, int years = 1}) async {
    await _api.post<void>('/domains/$domain/renew', data: {'years': years});
  }

  Future<void> verify(String domain) async {
    await _api.post<void>('/domains/$domain/verify');
  }

  Future<List<DnsRecord>> dnsRecords(String domain) async {
    final res =
        await _api.get<List<dynamic>>('/domains/$domain/dns');
    return (res.data ?? [])
        .map((e) => DnsRecord.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> upsertDnsRecord(
    String domain,
    DnsRecord record,
  ) async {
    await _api.put<void>('/domains/$domain/dns/${record.id}', data: {
      'type': record.type,
      'name': record.name,
      'value': record.value,
      'ttl': record.ttl,
    });
  }

  Future<void> deleteDnsRecord(String domain, String recordId) async {
    await _api.delete<void>('/domains/$domain/dns/$recordId');
  }
}
