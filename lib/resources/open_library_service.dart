import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart';
import 'package:readmate/core/constants/enums/enums.dart';
import 'package:readmate/model/ol_author_result.dart';
import 'package:readmate/model/ol_edition_result.dart';
import 'package:readmate/model/ol_search_result.dart';
import 'package:readmate/model/ol_work_result.dart';

class OpenLibraryService {
  static const baseUrl = 'https://openlibrary.org';
  static const coversBaseUrl = 'https://covers.openlibrary.org';

  Future<OLSearchResult> getResults({
    required String query,
    required int offset,
    required int limit,
    required OLSearchType searchType,
  }) async {
    final queryParam = searchType == OLSearchType.isbn 
        ? query.replaceAll('-', '').trim() 
        : query;

    final searchTypeParam = searchType == OLSearchType.general
        ? 'q'
        : searchType == OLSearchType.author
            ? 'author'
            : searchType == OLSearchType.title
                ? 'title'
                : searchType == OLSearchType.isbn
                    ? 'isbn'
                    : 'q';
    const modeParam = '&mode=everything';
    const fieldsParam =
        '&fields=key,title,subtitle,author_key,author_name,editions,number_of_pages_median,first_publish_year,isbn,edition_key,cover_edition_key,cover_i';
    final offsetParam = '&offset=$offset';
    final limitParam = '&limit=$limit';

    final uri = Uri.parse(
      '$baseUrl/search.json?$searchTypeParam=$queryParam$limitParam$offsetParam$modeParam$fieldsParam',
    );

    final response = await get(uri);
    return openLibrarySearchResultFromJson(response.body);
  }

  Future<OLEditionResult> getEdition(String edition) async {
    final uri = Uri.parse('$baseUrl/works/$edition.json');
    final response = await get(uri);
    return openLibraryEditionResultFromJson(response.body);
  }

  Future<OLWorkResult> getWork(String work) async {
    final uri = Uri.parse('$baseUrl/$work.json');
    final response = await get(uri);
    return openLibraryWorkResultFromJson(response.body);
  }

  Future<Uint8List?> getCover(String isbn) async {
    try {
      final response = await get(
        Uri.parse('$coversBaseUrl/b/isbn/$isbn-M.jpg'),
      );

      if (response.bodyBytes.length < 500) return null;

      return response.bodyBytes;
    } catch (e) {
      return null;
    }
  }

  Future<OLEditionResult?> getEditionByISBN({
    required String isbn,
  }) async {
    final uri = Uri.parse(
      '$baseUrl/isbn/$isbn.json',
    );

    final response = await get(uri);

    if (response.statusCode == 200) {
      return openLibraryEditionResultFromJson(response.body);
    } else {
      return null;
    }
  }

  Future<OLAuthorResult?> getAuthor({
    required String key,
  }) async {
    final uri = Uri.parse(
      '$baseUrl$key.json',
    );

    final response = await get(uri);

    if (response.statusCode == 200) {
      return openLibraryAuthorResultFromJson(response.body);
    } else {
      return null;
    }
  }

  Future<List<OLSearchResultDoc>> getTrending() async {
    try {
      final uri = Uri.parse('$baseUrl/trending/daily.json?limit=10');
      final response = await get(uri);
      if (response.statusCode == 200) {
        final data = openLibrarySearchResultFromJson(response.body);
        return data.docs;
      }
    } catch (e) {
      debugPrint("Trending fetch error: $e");
    }
    return [];
  }

  Future<List<String>> getWorkEditions(String workKey) async {
    try {
      final uri = Uri.parse('$baseUrl$workKey/editions.json?limit=100');
      final response = await get(uri);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final entries = data['entries'] as List;
        return entries.map((e) => e['key'].toString().replaceAll('/books/', '')).toList();
      }
    } catch (e) {
      debugPrint("Work editions fetch error: $e");
    }
    return [];
  }
}
