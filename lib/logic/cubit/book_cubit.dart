import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:readmate/core/constants/enums/enums.dart';
import 'package:readmate/logic/cubit/current_book_cubit.dart';
import 'package:readmate/model/book.dart';
import 'package:readmate/model/reading.dart';
import 'package:readmate/resources/api_book_repository.dart';
import 'package:readmate/main.dart';
import 'package:rxdart/rxdart.dart';

class BookCubit extends Cubit<List<Book>> {
  ApiBookRepository? _repository;
  bool _isInitialSyncComplete = false;

  final BehaviorSubject<List<Book>> _booksFetcher = BehaviorSubject<List<Book>>();
  final BehaviorSubject<List<Book>> _finishedBooksFetcher = BehaviorSubject<List<Book>>();
  final BehaviorSubject<List<Book>> _inProgressBooksFetcher = BehaviorSubject<List<Book>>();
  final BehaviorSubject<List<Book>> _toReadBooksFetcher = BehaviorSubject<List<Book>>();
  final BehaviorSubject<List<Book>> _deletedBooksFetcher = BehaviorSubject<List<Book>>();
  final BehaviorSubject<List<Book>> _unfinishedBooksFetcher = BehaviorSubject<List<Book>>();
  final BehaviorSubject<List<Book>> _searchBooksFetcher = BehaviorSubject<List<Book>>();
  final BehaviorSubject<List<int>> _finishedYearsFetcher = BehaviorSubject<List<int>>();
  final BehaviorSubject<List<String>> _tagsFetcher = BehaviorSubject<List<String>>();
  final BehaviorSubject<List<String>> _authorsFetcher = BehaviorSubject<List<String>>();
  final BehaviorSubject<Book?> _bookFetcher = BehaviorSubject<Book?>();

  Stream<List<Book>> get allBooks => _booksFetcher.stream;
  Stream<List<Book>> get finishedBooks => _finishedBooksFetcher.stream;
  Stream<List<Book>> get inProgressBooks => _inProgressBooksFetcher.stream;
  Stream<List<Book>> get toReadBooks => _toReadBooksFetcher.stream;
  Stream<List<Book>> get deletedBooks => _deletedBooksFetcher.stream;
  Stream<List<Book>> get unfinishedBooks => _unfinishedBooksFetcher.stream;
  Stream<List<Book>> get searchBooks => _searchBooksFetcher.stream;
  Stream<List<int>> get finishedYears => _finishedYearsFetcher.stream;
  Stream<List<String>> get tags => _tagsFetcher.stream;
  Stream<List<String>> get authors => _authorsFetcher.stream;
  Stream<Book?> get book => _bookFetcher.stream;

  BookCubit() : super([]) {
    _updateFetchers(state);
  }

  void clearAllData() {
    debugPrint("Clearing all local book data.");
    emit([]);
  }

  void setRepository(ApiBookRepository repository) {
    _repository = repository;
    if (_repository?.uid != null) {
      debugPrint("Repository set while user logged in. Fetching cloud state...");
      fetchFromCloud();
      _isInitialSyncComplete = true;
    }
  }

  void setInitialSyncComplete(bool complete) {
    debugPrint("Initial sync status set to: $complete");
    _isInitialSyncComplete = complete;
  }

  @override
  void onChange(Change<List<Book>> change) {
    super.onChange(change);
    _updateFetchers(change.nextState);
  }

  void _updateFetchers(List<Book> books) {
    debugPrint("Updating fetchers with ${books.length} books.");
    _booksFetcher.sink.add(books.where((b) => !b.deleted).toList());
    
    final finished = books.where((b) => b.status == BookStatus.read && !b.deleted).toList();
    debugPrint("Found ${finished.length} finished books.");
    _finishedBooksFetcher.sink.add(finished);
    _finishedYearsFetcher.sink.add(_getFinishedYears(finished));
    
    _inProgressBooksFetcher.sink.add(books.where((b) => b.status == BookStatus.inProgress && !b.deleted).toList());
    _toReadBooksFetcher.sink.add(books.where((b) => b.status == BookStatus.forLater && !b.deleted).toList());
    _unfinishedBooksFetcher.sink.add(books.where((b) => b.status == BookStatus.unfinished && !b.deleted).toList());
    _deletedBooksFetcher.sink.add(books.where((b) => b.deleted).toList());
    
    _tagsFetcher.sink.add(_getTags(books.where((b) => !b.deleted).toList()));
    _authorsFetcher.sink.add(_getAuthors(books.where((b) => !b.deleted).toList()));
  }

  Future<void> fetchFromCloud() async {
    final repo = _repository;
    if (repo == null) {
      debugPrint("[API_DEBUG] Fetch skipped: Repository is null.");
      return;
    }
    try {
      debugPrint("[API_DEBUG] Requesting all books from cloud...");
      final cloudBooks = await repo.getBooks();
      debugPrint("[API_DEBUG] Cloud returned ${cloudBooks.length} books.");
      
      emit(cloudBooks);
    } catch (e) {
      debugPrint("[API_DEBUG] Cloud fetch ERROR: $e");
      rethrow;
    }
  }

  Future<void> syncLocalToCloud() async {
    final repo = _repository;
    if (repo == null) {
      debugPrint("[API_DEBUG] Sync skipped: Repository is null.");
      return;
    }
    if (state.isEmpty) {
      debugPrint("[API_DEBUG] Sync skipped: Local state is empty.");
      return;
    }

    try {
      debugPrint("[API_DEBUG] Syncing ${state.length} local books to cloud...");
      await repo.syncLocalBooks(state);
      debugPrint("[API_DEBUG] Sync SUCCESS.");
    } catch (e) {
      debugPrint("[API_DEBUG] Sync ERROR: $e");
      rethrow;
    }
  }

  Future<void> getAllBooks({
    bool getTags = true,
    bool getAuthors = true,
  }) async {
    _updateFetchers(state);
  }

  removeAllBooks() {
    emit([]);
  }

  Future<void> getAllBooksByStatus() async {
    _updateFetchers(state);
  }

  getFinishedBooks() {
    _updateFetchers(state);
  }

  getInProgressBooks() {
    _updateFetchers(state);
  }

  getToReadBooks() {
    _updateFetchers(state);
  }

  getDeletedBooks() {
    _updateFetchers(state);
  }

  getUnfinishedBooks() {
    _updateFetchers(state);
  }

  getSearchBooks(String query) {
    if (query.isEmpty) {
      _searchBooksFetcher.sink.add(List.empty());
    } else {
      final results = state.where((b) =>
        !b.deleted &&
        (b.title.toLowerCase().contains(query.toLowerCase()) ||
         b.author.toLowerCase().contains(query.toLowerCase()))
      ).toList();
      _searchBooksFetcher.sink.add(results);
    }
  }

  Future<int> addBook(Book book, {bool refreshBooks = true, Uint8List? cover}) async {
    final dateNow = DateTime.now();
    final date = DateTime(dateNow.year, dateNow.month, dateNow.day);

    List<Reading> readings = List<Reading>.from(book.readings);
    if (book.status == BookStatus.read && readings.isEmpty) {
      readings = [Reading(finishDate: date)];
    } else if (book.status == BookStatus.inProgress && readings.isEmpty) {
      readings = [Reading(startDate: date)];
    }

    final tempId = -1 * (state.length + 1);
    final newBook = book.copyWith(
      id: tempId,
      hasCover: cover != null,
      cover: cover,
      readings: readings,
    );

    emit(List<Book>.from(state)..add(newBook));

    if (_repository != null) {
      try {
        final savedBook = await _repository!.upsertBook(newBook.copyWith(id: null));
        if (savedBook != null && savedBook.id != null) {
          final newState = state.map((b) => b.id == tempId ? savedBook : b).toList();
          emit(newState);
          
          return savedBook.id!;
        } else {
          throw 'Server returned empty book after save.';
        }
      } catch (e) {
        emit(state.where((b) => b.id != tempId).toList());
        rethrow;
      }
    }

    return 0;
  }

  Future<void> refresh() async {
    debugPrint("Manual refresh triggered.");
    await fetchFromCloud();
  }

  Future<void> updateBook(Book book, {Uint8List? cover, BuildContext? context}) async {
    final previousState = List<Book>.from(state);
    
    final updatedList = state.map((b) => b.id == book.id ? book : b).toList();
    emit(updatedList);

    if (_repository != null) {
      try {
        final updatedBook = await _repository!.upsertBook(book.copyWith(cover: cover, hasCover: cover != null || book.hasCover));
        
        if (updatedBook != null) {
          final reconciledList = state.map((b) => b.id == updatedBook.id ? updatedBook : b).toList();
          emit(reconciledList);
          
          if (context != null && context.mounted) {
            context.read<CurrentBookCubit>().setBook(updatedBook);
          }
          if (updatedBook.id != null) {
            getBook(updatedBook.id!);
          }
        } else {
          throw 'Failed to update book in database.';
        }
      } catch (e) {
        emit(previousState);
        rethrow;
      }
    }
  }

  Future<void> deleteBook(int id) async {
    final newState = state.where((b) => b.id != id).toList();
    emit(newState);

    if (_repository != null) {
      await _repository!.deleteBook(id);
    }
  }

  Future<void> bulkDeleteBooks(List<int> ids) async {
    final idsSet = ids.toSet();
    final newState = state.where((b) => b.id == null || !idsSet.contains(b.id)).toList();
    emit(newState);

    if (_repository != null) {
      await _repository!.bulkDeleteBooks(ids);
    }
  }

  Book? findBookByISBN(String? isbn) {
    if (isbn == null || isbn.trim().isEmpty) return null;
    final cleanIsbn = isbn.replaceAll(RegExp(r'[\s\-]'), '').toLowerCase();
    try {
      return state.firstWhere(
        (b) =>
            !b.deleted &&
            b.isbn != null &&
            b.isbn!.replaceAll(RegExp(r'[\s\-]'), '').toLowerCase() == cleanIsbn,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> bulkUpdateStatus(List<int> ids, BookStatus newStatus) async {
    final idsSet = ids.toSet();
    final dateNow = DateTime.now();
    final date = DateTime(dateNow.year, dateNow.month, dateNow.day);

    final updatedList = state.map((b) {
      if (b.id != null && idsSet.contains(b.id)) {
        List<Reading> readings = List<Reading>.from(b.readings);
        if (newStatus == BookStatus.read) {
          if (readings.isEmpty) {
            readings = [Reading(finishDate: date)];
          } else {
            final last = readings.last;
            if (last.finishDate == null) {
              readings[readings.length - 1] = last.copyWith(finishDate: date);
            }
          }
        }
        return b.copyWith(status: newStatus, readings: readings);
      }
      return b;
    }).toList();

    emit(updatedList);

    if (_repository != null) {
      for (final id in ids) {
        final book = updatedList.firstWhere((b) => b.id == id, orElse: () => state.first);
        if (book.id == id) {
          try {
            await _repository!.upsertBook(book);
          } catch (e) {
            debugPrint("Error updating book $id in cloud: $e");
          }
        }
      }
    }
  }

  Future<Book?> getBook(int id) async {
    try {
      final book = state.firstWhere((b) => b.id == id);
      _bookFetcher.sink.add(book);
      return book;
    } catch (e) {
      _bookFetcher.sink.add(null);
      return null;
    }
  }

  List<int> _getFinishedYears(List<Book> books) {
    final years = List<int>.empty(growable: true);
    for (var book in books) {
      for (var date in book.readings) {
        if (date.finishDate != null) {
          if (!years.contains(date.finishDate!.year)) {
            years.add(date.finishDate!.year);
          }
        }
      }
    }
    years.sort((a, b) => b.compareTo(a));
    return years;
  }

  List<String> _getTags(List<Book> books) {
    final tags = List<String>.empty(growable: true);
    for (var book in books) {
      if (book.tags != null) {
        for (var tag in book.tags!.split('|||||')) {
          if (!tags.contains(tag)) {
            tags.add(tag);
          }
        }
      }
    }
    tags.sort((a, b) => a.compareTo(b));
    return tags;
  }

  List<String> _getAuthors(List<Book> books) {
    final authors = List<String>.empty(growable: true);
    for (var book in books) {
      if (!authors.contains(book.author)) {
        authors.add(book.author);
      }
    }
    authors.sort((a, b) => a.compareTo(b));
    return authors;
  }
}
