import 'api_client.dart';

class SearchResult {
  final String domain;
  final String? title;
  final String? description;
  final int? trustScore;
  final String? programAddress;

  const SearchResult({
    required this.domain,
    this.title,
    this.description,
    this.trustScore,
    this.programAddress,
  });

  factory SearchResult.fromJson(Map<String, dynamic> json) => SearchResult(
        domain: json['domain'] ?? '',
        title: json['title'],
        description: json['description'],
        trustScore: json['trust_score'] as int?,
        programAddress: json['program_address'],
      );
}

class SearchService {
  final ApiClient _api = ApiClient.instance;

  Future<List<SearchResult>> search(String query, {int limit = 20}) async {
    if (query.trim().isEmpty) return const [];
    final res = await _api.get<List<dynamic>>(
      '/search',
      query: {'q': query, 'limit': limit},
    );
    return (res.data ?? [])
        .map((e) => SearchResult.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }
}
