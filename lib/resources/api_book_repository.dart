import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:readmate/model/book.dart';
import 'package:readmate/model/book_history.dart';
import 'package:readmate/resources/api_auth_repository.dart';

class ApiBookRepository {
  final ApiAuthRepository _authRepo = ApiAuthRepository();

  String? get uid => _authRepo.currentUser?.id;
  String? get _token => _authRepo.authToken;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  Future<Book?> upsertBook(Book book) async {
    if (uid == null) return null;

    try {
      final data = book.toJSON();
      data['user_id'] = uid;

      debugPrint("[API_DEBUG] Upserting book. Payload: $data");

      if (data['id'] != null && data['id'] is int && data['id'] < 0) {
        data.remove('id');
      }

      if (book.cover != null) {
        debugPrint("[API_DEBUG] Uploading cover for book: ${book.title}");
        final fileName = '${uid}_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final url = await uploadCover(book.cover!, fileName);
        if (url != null) {
          data['cover_url'] = url;
          debugPrint("[API_DEBUG] Cover uploaded. URL: $url");
        }
      }

      final res = await http.post(
        Uri.parse('${ApiAuthRepository.baseUrl}/books/upsert'),
        headers: _headers,
        body: jsonEncode(data),
      );

      if (res.statusCode == 200 || res.statusCode == 201) {
        final json = jsonDecode(res.body);
        final savedBook = Book.fromJSON(json['book']);
        debugPrint("[API_DEBUG] SUCCESS: Book upserted with ID: ${savedBook.id}");
        return savedBook;
      } else {
        final errJson = jsonDecode(res.body);
        throw errJson['error'] ?? 'Failed to save book.';
      }
    } catch (e) {
      debugPrint("[API_DEBUG] Error during upsert: $e");
      rethrow;
    }
  }

  Future<String?> uploadCover(Uint8List bytes, String fileName) async {
    try {
      final uri = Uri.parse('${ApiAuthRepository.baseUrl}/books/upload-cover');
      final request = http.MultipartRequest('POST', uri);

      if (_token != null) {
        request.headers['Authorization'] = 'Bearer $_token';
      }

      request.files.add(http.MultipartFile.fromBytes(
        'cover',
        bytes,
        filename: fileName,
      ));

      final streamedRes = await request.send();
      final res = await http.Response.fromStream(streamedRes);

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return data['url'] as String?;
      }
      return null;
    } catch (e) {
      debugPrint("[API_DEBUG] Cover upload error: $e");
      return null;
    }
  }

  Future<List<Book>> getBooks() async {
    if (uid == null) return [];

    try {
      final res = await http.get(
        Uri.parse('${ApiAuthRepository.baseUrl}/books'),
        headers: _headers,
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final list = data['books'] as List;
        return list.map((json) => Book.fromJSON(json)).toList();
      }
      return [];
    } catch (e) {
      debugPrint("[API_DEBUG] Error fetching books: $e");
      return [];
    }
  }

  Future<void> deleteBook(int id) async {
    if (uid == null) return;
    try {
      await http.delete(
        Uri.parse('${ApiAuthRepository.baseUrl}/books/$id'),
        headers: _headers,
      );
    } catch (e) {
      debugPrint("[API_DEBUG] Error deleting book: $e");
    }
  }

  Future<void> bulkDeleteBooks(List<int> ids) async {
    if (uid == null || ids.isEmpty) return;
    try {
      final res = await http.post(
        Uri.parse('${ApiAuthRepository.baseUrl}/books/bulk-delete'),
        headers: _headers,
        body: jsonEncode({'ids': ids}),
      );
      if (res.statusCode == 200) {
        debugPrint("[API_DEBUG] Bulk deleted ${ids.length} books successfully.");
      } else {
        debugPrint("[API_DEBUG] Bulk delete response status: ${res.statusCode}");
      }
    } catch (e) {
      debugPrint("[API_DEBUG] Error bulk deleting books: $e");
    }
  }

  Future<List<BookHistory>> getBookHistory(int bookId) async {
    if (uid == null) return [];
    try {
      final res = await http.get(
        Uri.parse('${ApiAuthRepository.baseUrl}/books/$bookId/history'),
        headers: _headers,
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final list = data['history'] as List;
        return list.map((json) => BookHistory.fromJSON(json)).toList();
      }
      return [];
    } catch (e) {
      debugPrint("[API_DEBUG] Error fetching book history: $e");
      return [];
    }
  }

  Future<bool> addBookNote(int bookId, String noteContent) async {
    if (uid == null) return false;
    try {
      final res = await http.post(
        Uri.parse('${ApiAuthRepository.baseUrl}/books/$bookId/notes'),
        headers: _headers,
        body: jsonEncode({'note': noteContent}),
      );
      return res.statusCode == 201 || res.statusCode == 200;
    } catch (e) {
      debugPrint("[API_DEBUG] Error adding note: $e");
      return false;
    }
  }

  Future<void> syncLocalBooks(List<Book> localBooks) async {
    if (uid == null || localBooks.isEmpty) return;

    try {
      debugPrint("[API_DEBUG] Syncing ${localBooks.length} books to REST API...");
      final data = localBooks.map((book) {
        final json = book.toJSON();
        json['user_id'] = uid;
        if (book.id != null && book.id! < 0) {
          json.remove('id');
        }
        return json;
      }).toList();

      final res = await http.post(
        Uri.parse('${ApiAuthRepository.baseUrl}/books/sync'),
        headers: _headers,
        body: jsonEncode({'books': data}),
      );

      if (res.statusCode == 200) {
        debugPrint("[API_DEBUG] Cloud backup successful for all books.");
      } else {
        final errJson = jsonDecode(res.body);
        throw errJson['error'] ?? 'Batch sync failed.';
      }
    } catch (e) {
      debugPrint("[API_DEBUG] ERROR: Cloud backup failed. Reason: $e");
      rethrow;
    }
  }

  Future<List<Book>> getPublicBooks(String userId) async {
    try {
      final res = await http.get(
        Uri.parse('${ApiAuthRepository.baseUrl}/books/profiles/$userId'),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final list = data['books'] as List;
        return list.map((json) => Book.fromJSON(json)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> searchProfiles(String query) async {
    try {
      final res = await http.get(
        Uri.parse('${ApiAuthRepository.baseUrl}/books/profiles/search?q=${Uri.encodeComponent(query)}'),
        headers: _headers,
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return List<Map<String, dynamic>>.from(data['profiles']);
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>?> getProfile(String userId) async {
    try {
      final res = await http.get(
        Uri.parse('${ApiAuthRepository.baseUrl}/books/profiles/$userId'),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return data['profile'] as Map<String, dynamic>?;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<bool> checkConnection() async {
    try {
      final res = await http.get(
        Uri.parse('${ApiAuthRepository.baseUrl}/health'),
      ).timeout(const Duration(seconds: 3));
      return res.statusCode == 200;
    } catch (e) {
      debugPrint("[API_DEBUG] Connection check failed: $e");
      return false;
    }
  }

  Future<void> updateYearlyGoal(int goal) async {
    if (uid == null) return;
    try {
      await http.put(
        Uri.parse('${ApiAuthRepository.baseUrl}/auth/yearly-goal'),
        headers: _headers,
        body: jsonEncode({'goal': goal}),
      );
    } catch (e) {
      debugPrint("[API_DEBUG] Failed to update yearly goal: $e");
    }
  }
}
