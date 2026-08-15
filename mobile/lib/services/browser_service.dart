// Browser service for managing history, bookmarks, and sessions
import 'dart:convert';
import 'package:http/http.dart' as http;

class BrowserService {
  final String baseUrl;
  
  BrowserService({this.baseUrl = 'http://localhost:8080/api'});
  
  // History management
  Future<List<Map<String, dynamic>>> getHistory(String authToken, {int limit = 50}) async {
    final response = await http.get(
      Uri.parse('$baseUrl/history?limit=$limit'),
      headers: {
        'X-Shadow-Auth': authToken,
        'Content-Type': 'application/json',
      },
    );
    
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(json.decode(response.body));
    }
    throw Exception('Failed to load history');
  }
  
  Future<void> recordVisit(
    String authToken,
    String domain,
    String programAddress,
    String? title,
    int timeSpentSeconds,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/history'),
      headers: {
        'X-Shadow-Auth': authToken,
        'Content-Type': 'application/json',
      },
      body: json.encode({
        'domain': domain,
        'program_address': programAddress,
        'title': title,
        'time_spent_seconds': timeSpentSeconds,
      }),
    );
    
    if (response.statusCode != 200) {
      throw Exception('Failed to record visit');
    }
  }
  
  Future<void> clearHistory(String authToken) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/history'),
      headers: {
        'X-Shadow-Auth': authToken,
        'Content-Type': 'application/json',
      },
    );
    
    if (response.statusCode != 200) {
      throw Exception('Failed to clear history');
    }
  }
  
  // Bookmarks management
  Future<List<Map<String, dynamic>>> getBookmarks(String authToken, {String? folder}) async {
    final uri = folder != null 
        ? Uri.parse('$baseUrl/bookmarks?q=$folder')
        : Uri.parse('$baseUrl/bookmarks');
    
    final response = await http.get(
      uri,
      headers: {
        'X-Shadow-Auth': authToken,
        'Content-Type': 'application/json',
      },
    );
    
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(json.decode(response.body));
    }
    throw Exception('Failed to load bookmarks');
  }
  
  Future<void> addBookmark(
    String authToken,
    String domain,
    String programAddress,
    String? title,
    String? description,
    String? folder,
    List<String>? tags,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/bookmarks'),
      headers: {
        'X-Shadow-Auth': authToken,
        'Content-Type': 'application/json',
      },
      body: json.encode({
        'domain': domain,
        'program_address': programAddress,
        'title': title,
        'description': description,
        'folder': folder,
        'tags': tags ?? [],
      }),
    );
    
    if (response.statusCode != 201) {
      throw Exception('Failed to add bookmark');
    }
  }
  
  Future<void> removeBookmark(String authToken, String domain) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/bookmarks/$domain'),
      headers: {
        'X-Shadow-Auth': authToken,
        'Content-Type': 'application/json',
      },
    );
    
    if (response.statusCode != 200) {
      throw Exception('Failed to remove bookmark');
    }
  }
  
  // Session management
  Future<String> createSession(String authToken) async {
    final response = await http.post(
      Uri.parse('$baseUrl/sessions'),
      headers: {
        'X-Shadow-Auth': authToken,
        'Content-Type': 'application/json',
      },
    );
    
    if (response.statusCode == 201) {
      final data = json.decode(response.body);
      return data['session_id'] as String;
    }
    throw Exception('Failed to create session');
  }
  
  Future<List<Map<String, dynamic>>> getActiveSessions(String authToken) async {
    final response = await http.get(
      Uri.parse('$baseUrl/sessions/active'),
      headers: {
        'X-Shadow-Auth': authToken,
        'Content-Type': 'application/json',
      },
    );
    
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(json.decode(response.body));
    }
    throw Exception('Failed to load sessions');
  }
  
  // Search functionality
  Future<List<Map<String, dynamic>>> search(
    String query, {
    int limit = 20,
  }) async {
    final response = await http.get(
      Uri.parse('$baseUrl/search?q=${Uri.encodeComponent(query)}&limit=$limit'),
      headers: {
        'Content-Type': 'application/json',
      },
    );
    
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(json.decode(response.body));
    }
    throw Exception('Search failed');
  }
  
  // Analytics
  Future<Map<String, dynamic>> getAnalytics(String domain) async {
    final response = await http.get(
      Uri.parse('$baseUrl/analytics/$domain'),
      headers: {
        'Content-Type': 'application/json',
      },
    );
    
    if (response.statusCode == 200) {
      return json.decode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to load analytics');
  }
  
  Future<List<Map<String, dynamic>>> getTopSites({int limit = 10}) async {
    final response = await http.get(
      Uri.parse('$baseUrl/analytics/top?limit=$limit'),
      headers: {
        'Content-Type': 'application/json',
      },
    );
    
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(json.decode(response.body));
    }
    throw Exception('Failed to load top sites');
  }
  
  Future<void> recordPerformance(
    String domain,
    double loadTimeMs,
    double renderTimeMs,
    int totalSizeBytes,
    int requestCount,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/analytics/performance'),
      headers: {
        'Content-Type': 'application/json',
      },
      body: json.encode({
        'domain': domain,
        'load_time_ms': loadTimeMs,
        'render_time_ms': renderTimeMs,
        'total_size_bytes': totalSizeBytes,
        'request_count': requestCount,
      }),
    );
    
    if (response.statusCode != 200) {
      throw Exception('Failed to record performance');
    }
  }
}

