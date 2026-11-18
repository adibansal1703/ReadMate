import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:readmate/core/constants/enums/enums.dart';
import 'package:readmate/main.dart';
import 'package:readmate/model/reading.dart';

class Book {
  int? id;
  String title;
  String? subtitle;
  String author;
  String? description;
  BookStatus status;
  bool favourite;
  bool deleted;
  int? rating;
  int? pages;
  int? publicationYear;
  String? isbn;
  String? olid;
  String? tags;
  String? notes;
  int currentPage;
  Uint8List? cover;
  String? coverUrl;
  String? blurHash;
  BookFormat bookFormat;
  bool hasCover;
  List<Reading> readings;
  DateTime dateAdded;
  DateTime dateModified;

  Book({
    this.id,
    required this.title,
    required this.author,
    required this.status,
    this.subtitle,
    this.description,
    this.favourite = false,
    this.deleted = false,
    this.rating,
    this.pages,
    this.publicationYear,
    this.isbn,
    this.olid,
    this.tags,
    this.notes,
    this.currentPage = 0,
    this.cover,
    this.coverUrl,
    this.blurHash,
    this.bookFormat = BookFormat.paperback,
    this.hasCover = false,
    required this.readings,
    required this.dateAdded,
    required this.dateModified,
  });

  factory Book.empty({
    BookStatus status = BookStatus.read,
    BookFormat bookFormat = BookFormat.paperback,
  }) {
    final newBookDate = DateTime.now();

    return Book(
      id: null,
      title: '',
      author: '',
      status: status,
      favourite: false,
      deleted: false,
      bookFormat: bookFormat,
      hasCover: false,
      readings: List<Reading>.empty(growable: true),
      tags: null,
      dateAdded: newBookDate,
      dateModified: newBookDate,
    );
  }

  factory Book.fromJSON(Map<String, dynamic> json) {
    try {
      return Book(
        id: json['id'],
        title: json['title'] ?? 'Unknown Title',
        subtitle: json['subtitle'],
        author: json['author'] ?? 'Unknown Author',
        description: json['description'],
        status: parseBookStatus(json['status']),
        rating: json['rating'],
        favourite: (json['favourite'] == 1 || json['favourite'] == true),
        hasCover: (json['has_cover'] == 1 || json['has_cover'] == true || json['cover_url'] != null),
        deleted: (json['deleted'] == 1 || json['deleted'] == true),
        pages: json['pages'],
        publicationYear: json['publication_year'],
        isbn: json['isbn'],
        olid: json['olid'],
        tags: json['tags'],
        notes: json['notes'],
        currentPage: json['current_page'] ?? 0,
        cover: _parseCover(json['cover']),
        coverUrl: json['cover_url'],
        blurHash: json['blur_hash'],
        bookFormat: _parseBookFormat(json['book_type']),
        readings: _sortReadings(_parseReadingsFromJson(json)),
        dateAdded: _parseDateTime(json['date_added']),
        dateModified: _parseDateTime(json['date_modified']),
      );
    } catch (e) {
      debugPrint("Error parsing book JSON: $e");
      return Book.empty().copyWith(
        id: json['id'],
        title: "Error loading book: ${json['title']}",
      );
    }
  }

  static Uint8List? _parseCover(dynamic cover) {
    if (cover == null) return null;
    if (cover is Uint8List) return cover;
    try {
      if (cover is List) {
        return Uint8List.fromList(cover.cast<int>());
      }
    } catch (e) {
      debugPrint("Failed to parse cover bytes: $e");
    }
    return null;
  }

  static DateTime _parseDateTime(dynamic date) {
    if (date == null) return DateTime.now();
    try {
      return DateTime.parse(date.toString());
    } catch (e) {
      return DateTime.now();
    }
  }

  static BookFormat _parseBookFormat(dynamic type) {
    switch (type?.toString().toLowerCase()) {
      case 'audiobook':
        return BookFormat.audiobook;
      case 'ebook':
        return BookFormat.ebook;
      case 'hardcover':
        return BookFormat.hardcover;
      case 'paperback':
      default:
        return BookFormat.paperback;
    }
  }

  Book copyWith({
    int? id,
    String? title,
    String? author,
    BookStatus? status,
    String? subtitle,
    String? description,
    bool? favourite,
    bool? deleted,
    int? rating,
    int? pages,
    int? publicationYear,
    String? isbn,
    String? olid,
    String? tags,
    String? notes,
    int? currentPage,
    Uint8List? cover,
    String? coverUrl,
    String? blurHash,
    BookFormat? bookFormat,
    bool? hasCover,
    List<Reading>? readings,
    DateTime? dateAdded,
    DateTime? dateModified,
  }) {
    return Book(
      id: id ?? this.id,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      author: author ?? this.author,
      status: status ?? this.status,
      description: description ?? this.description,
      favourite: favourite ?? this.favourite,
      deleted: deleted ?? this.deleted,
      rating: rating ?? this.rating,
      pages: pages ?? this.pages,
      publicationYear: publicationYear ?? this.publicationYear,
      isbn: isbn ?? this.isbn,
      olid: olid ?? this.olid,
      tags: tags ?? this.tags,
      notes: notes ?? this.notes,
      currentPage: currentPage ?? this.currentPage,
      cover: cover ?? this.cover,
      coverUrl: coverUrl ?? this.coverUrl,
      blurHash: blurHash ?? this.blurHash,
      bookFormat: bookFormat ?? this.bookFormat,
      hasCover: hasCover ?? this.hasCover,
      readings: readings ?? this.readings,
      dateAdded: dateAdded ?? this.dateAdded,
      dateModified: dateModified ?? this.dateModified,
    );
  }

  Book copyWithNullCover() {
    return Book(
      id: id,
      title: title,
      subtitle: subtitle,
      author: author,
      status: status,
      description: description,
      favourite: favourite,
      deleted: deleted,
      rating: rating,
      pages: pages,
      publicationYear: publicationYear,
      isbn: isbn,
      olid: olid,
      tags: tags,
      notes: notes,
      currentPage: currentPage,
      cover: null,
      blurHash: blurHash,
      bookFormat: bookFormat,
      hasCover: hasCover,
      readings: readings,
      dateAdded: dateAdded,
      dateModified: dateModified,
    );
  }

  Map<String, dynamic> toJSON() {
    return {
      'id': id,
      'title': title,
      'subtitle': subtitle,
      'author': author,
      'description': description,
      'status': status.value,
      'rating': rating,
      'favourite': favourite,
      'deleted': deleted,
      'pages': pages,
      'publication_year': publicationYear,
      'isbn': isbn,
      'olid': olid,
      'tags': tags,
      'notes': notes,
      'current_page': currentPage,
      'blur_hash': blurHash,
      'cover_url': coverUrl,
      'book_type': bookFormat == BookFormat.audiobook
          ? 'audiobook'
          : bookFormat == BookFormat.ebook
              ? 'ebook'
              : bookFormat == BookFormat.hardcover
                  ? 'hardcover'
                  : bookFormat == BookFormat.paperback
                      ? 'paperback'
                      : 'paperback',
      'readings': readings.map((reading) => reading.toString()).join(';'),
      'date_added': dateAdded.toIso8601String(),
      'date_modified': dateModified.toIso8601String(),
    };
  }

  File? getCoverFile() {
    if (id != null) {
      final file = File('${appDocumentsDirectory.path}/$id.jpg');
      if (file.existsSync()) {
        return file;
      }
    }
    return null;
  }

  Uint8List? getCoverBytes() {
    final file = getCoverFile();
    if (file != null) {
      try {
        return file.readAsBytesSync();
      } catch (_) {}
    }
    return cover;
  }

  static List<Reading> _parseReadingsFromJson(Map<String, dynamic> json) {
    if (json['readings'] != null) {
      final splittedReadings = json['readings'].split(';');

      if (splittedReadings.isNotEmpty) {
        return List<Reading>.from(
          splittedReadings.map((e) {
            final reading = Reading.fromString(e);

            if (reading.startDate == null &&
                reading.finishDate == null) {
              return null;
            } else {
              return reading;
            }
          }).where((reading) => reading != null),
        );
      } else {
        return List<Reading>.empty(growable: true);
      }
    } else if (json['start_date'] != null || json['finish_date'] != null) {
      return [
        Reading(
            startDate: json['start_date'] != null
                ? DateTime.parse(json['start_date'])
                : null,
            finishDate: json['finish_date'] != null
                ? DateTime.parse(json['finish_date'])
                : null)
      ];
    } else {
      return List<Reading>.empty(growable: true);
    }
  }

  static List<Reading> _sortReadings(List<Reading> readings) {
    final sortedReadings = readings;

    sortedReadings.sort((a, b) {
      if (a.finishDate == null && b.finishDate != null) {
        return -1;
      } else if (a.finishDate != null && b.finishDate == null) {
        return 1;
      } else if (a.finishDate != null && b.finishDate != null) {
        return b.finishDate!.compareTo(a.finishDate!);
      } else {
        if (a.startDate == null && b.startDate == null) return 0;
        if (a.startDate == null) return 1;
        if (b.startDate == null) return -1;
        return b.startDate!.compareTo(a.startDate!);
      }
    });

    return sortedReadings;
  }
}
