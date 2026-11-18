import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:readmate/core/constants/enums/enums.dart';
import 'package:readmate/main.dart';
import 'package:readmate/model/reading.dart';
import 'package:readmate/model/book.dart';

class EditBookCubit extends Cubit<Book> {
  EditBookCubit() : super(Book.empty());

  setBook(Book book) => emit(book);

  Future<void> updateBook(Uint8List? cover, BuildContext context) async {
    if (state.id == null) return;

    await bookCubit.updateBook(state, cover: cover, context: context);
  }

  Future<int> addNewBook(Uint8List? cover) async {
    final bookID = await bookCubit.addBook(state, cover: cover);

    return bookID;
  }

  void setStatus(BookStatus status) {
    final dateNow = DateTime.now();
    final date = DateTime(dateNow.year, dateNow.month, dateNow.day);
    List<Reading> readings = List<Reading>.from(state.readings);

    if (status == BookStatus.inProgress) {
      if (readings.isEmpty) {
        readings = [Reading(startDate: date)];
      } else {
        final last = readings.last;
        if (last.startDate == null) {
          readings[readings.length - 1] = last.copyWith(startDate: date);
        }
      }
    } else if (status == BookStatus.read) {
      if (readings.isEmpty) {
        readings = [Reading(finishDate: date)];
      } else {
        final last = readings.last;
        if (last.finishDate == null) {
          readings[readings.length - 1] = last.copyWith(finishDate: date);
        }
      }
    }

    emit(state.copyWith(status: status, readings: readings));
  }

  void setRating(double rating) {
    emit(state.copyWith(rating: (rating * 10).toInt()));
  }

  void setBookFormat(BookFormat bookFormat) {
    emit(state.copyWith(bookFormat: bookFormat));
  }

  void setTitle(String title) {
    emit(state.copyWith(title: title));
  }

  void setSubtitle(String subtitle) {
    final book = state.copyWith();
    book.subtitle = subtitle.isNotEmpty ? subtitle : null;
    emit(book);
  }

  void setAuthor(String author) {
    emit(state.copyWith(author: author));
  }

  void setPages(String pages) {
    emit(state.copyWith(pages: pages.isEmpty ? null : int.parse(pages)));
  }

  void setCurrentPage(String currentPage) {
    emit(state.copyWith(
        currentPage: currentPage.isEmpty ? 0 : int.parse(currentPage)));
  }

  void setDescription(String description) {
    final book = state.copyWith();
    book.description = description.isNotEmpty ? description : null;
    emit(book);
  }

  void setISBN(String isbn) {
    final book = state.copyWith();
    book.isbn = isbn.isNotEmpty ? isbn : null;
    emit(book);
  }

  void setOLID(String olid) {
    final book = state.copyWith();
    book.olid = olid.isNotEmpty ? olid : null;
    emit(book);
  }

  void setPublicationYear(String publicationYear) {
    final book = state.copyWith();
    book.publicationYear =
        publicationYear.isEmpty ? null : int.parse(publicationYear);

    emit(book);
  }



  void setNotes(String notes) {
    final book = state.copyWith();
    book.notes = notes.isNotEmpty ? notes : null;

    emit(book);
  }

  void setBlurHash(String? blurHash) {
    final book = state.copyWith();
    book.blurHash = blurHash;

    emit(book);
  }

  void setHasCover(bool hasCover) {
    final book = state.copyWith();
    book.hasCover = hasCover;

    emit(book);
  }

  void addNewTag(String tag) {
    if (tag.substring(tag.length - 1) == ' ') {
      tag = tag.substring(0, tag.length - 1);
    }

    tag = tag.replaceAll('|', '');

    List<String> tags = state.tags == null ? [] : state.tags!.split('|||||');

    if (tags.contains(tag)) return;
    tags.add(tag);

    final book = state.copyWith();
    book.tags = tags.join('|||||');

    emit(book);
  }

  void removeTag(String tag) {
    List<String> tags = state.tags == null ? [] : state.tags!.split('|||||');

    if (!tags.contains(tag)) return;
    tags.remove(tag);

    final book = state.copyWith();
    book.tags = tags.isEmpty ? null : tags.join('|||||');

    emit(book);
  }

  void addNewReading(Reading reading) {
    List<Reading> readings = state.readings;

    readings.add(reading);

    final book = state.copyWith();
    book.readings = readings;

    emit(book);
  }

  void removeReading(int index) {
    List<Reading> readings = state.readings;

    readings.removeAt(index);

    final book = state.copyWith();
    book.readings = readings;

    emit(book);
  }

  void setReadingStartDate(DateTime? startDate, int index) {
    List<Reading> readings = state.readings;

    readings[index].startDate = startDate;

    final book = state.copyWith();
    book.readings = readings;

    emit(book);
  }

  setReadingFinishDate(DateTime? finishDate, int index) {
    List<Reading> readings = state.readings;

    readings[index].finishDate = finishDate;

    final book = state.copyWith();
    book.readings = readings;

    emit(book);
  }
}

class EditBookCoverCubit extends Cubit<Uint8List?> {
  EditBookCoverCubit() : super(null);

  setCover(Uint8List? cover) {
    imageCache.clear();

    emit(cover);
  }

  deleteCover(int? bookID) async {
    if (bookID == null) return;

    emit(null);

    final coverExists = await File(
      '${appDocumentsDirectory.path}/$bookID.jpg',
    ).exists();

    if (coverExists) {
      await File(
        '${appDocumentsDirectory.path}/$bookID.jpg',
      ).delete();
    }
  }
}
