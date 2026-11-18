import 'package:easy_localization/easy_localization.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:readmate/core/constants/enums/enums.dart';
import 'package:readmate/generated/locale_keys.g.dart';
import 'package:readmate/model/book.dart';

part 'stats_event.dart';
part 'stats_state.dart';

class StatsBloc extends Bloc<StatsEvent, StatsState> {
  StatsBloc() : super(StatsLoading()) {
    on<StatsLoad>((event, emit) {
      final allBooks = event.books;
      final finishedBooks = _filterBooksByStatus(allBooks, BookStatus.read);

      final years = _calculateYears(finishedBooks);

      final inProgressBooks = _filterBooksByStatus(
        allBooks,
        BookStatus.inProgress,
      );
      final forLaterBooks = _filterBooksByStatus(
        allBooks,
        BookStatus.forLater,
      );
      final unfinishedBooks = _filterBooksByStatus(
        allBooks,
        BookStatus.unfinished,
      );

      final allFinishedBooks = _countFinishedBooks(finishedBooks);
      final allFinishedPages = _countFinishedPages(finishedBooks);

      final currentYear = DateTime.now().year;

      final monthlyStats = <int, int>{};
      for (int i = 1; i <= 12; i++) {
        monthlyStats[i] = 0;
      }

      DateTime? earliestDate;

      for (var book in finishedBooks) {
        if (book.readings.isEmpty) {
          if (earliestDate == null || book.dateAdded.isBefore(earliestDate)) {
            earliestDate = book.dateAdded;
          }
          if (book.dateAdded.year == currentYear) {
             monthlyStats[book.dateAdded.month] = (monthlyStats[book.dateAdded.month] ?? 0) + 1;
          }
        } else {
          for (final reading in book.readings) {
            final date = reading.startDate ?? reading.finishDate ?? book.dateAdded;
            if (earliestDate == null || date.isBefore(earliestDate)) {
              earliestDate = date;
            }
            if (reading.finishDate != null && reading.finishDate!.year == currentYear) {
              monthlyStats[reading.finishDate!.month] = (monthlyStats[reading.finishDate!.month] ?? 0) + 1;
            }
          }
        }
      }

      double avgBooksPerMonth = 0.0;
      double avgPagesPerDay = 0.0;

      if (allFinishedBooks > 0) {
        final referenceDate = earliestDate ?? DateTime.now();
        final now = DateTime.now();
        final totalDaysPassed = now.difference(referenceDate).inDays + 1;
        final days = totalDaysPassed < 1 ? 1 : totalDaysPassed;
        final totalMonthsPassed = days / 30.4375;
        final months = totalMonthsPassed < 1.0 ? 1.0 : totalMonthsPassed;

        avgBooksPerMonth = allFinishedBooks / months;
        avgPagesPerDay = allFinishedPages / days;
      }

      double totalRating = 0.0;
      int ratedBooksCount = 0;

      for (var book in allBooks) {
        if (!book.deleted && book.rating != null && book.rating! > 0) {
          totalRating += (book.rating! / 10.0);
          ratedBooksCount++;
        }
      }

      double avgRating = ratedBooksCount > 0 ? (totalRating / ratedBooksCount) : 0.0;

      emit(StatsLoaded(
        years: years,
        finishedBooks: finishedBooks,
        inProgressBooks: inProgressBooks,
        forLaterBooks: forLaterBooks,
        unfinishedBooks: unfinishedBooks,
        finishedBooksAll: allFinishedBooks,
        finishedPagesAll: allFinishedPages,
        avgBooksPerMonth: avgBooksPerMonth,
        avgPagesPerDay: avgPagesPerDay,
        avgRating: avgRating,
        ratedBooksCount: ratedBooksCount,
        monthlyStats: monthlyStats,
      ));
    });
  }

  List<Book> _filterBooksByStatus(List<Book> books, BookStatus status) {
    final filteredBooks = List<Book>.empty(growable: true);

    for (var book in books) {
      if (book.status == status) {
        filteredBooks.add(book);
      }
    }

    return filteredBooks;
  }

  int _countFinishedBooks(List<Book> books) {
    int finishedBooksCount = 0;

    for (var book in books) {
      if (book.readings.isEmpty) {
        finishedBooksCount += 1;
      } else {
        int finishedReadings = 0;
        for (final reading in book.readings) {
          if (reading.finishDate != null) {
            finishedReadings += 1;
          }
        }
        finishedBooksCount += (finishedReadings > 0) ? finishedReadings : 1;
      }
    }

    return finishedBooksCount;
  }

  int _countFinishedPages(List<Book> books) {
    int finishedPagesCount = 0;

    for (var book in books) {
      if (book.pages != null) {
        if (book.readings.isEmpty) {
          finishedPagesCount += book.pages!;
        } else {
          int finishedReadings = 0;
          for (final reading in book.readings) {
            if (reading.finishDate != null) {
              finishedReadings += 1;
            }
          }
          finishedPagesCount += (finishedReadings > 0) ? (finishedReadings * book.pages!) : book.pages!;
        }
      }
    }

    return finishedPagesCount;
  }

  List<int> _calculateYears(List<Book> books) {
    final years = List<int>.empty(growable: true);

    for (var book in books) {
      for (final reading in book.readings) {
        if (reading.finishDate != null) {
          final year = reading.finishDate!.year;

          if (!years.contains(year)) {
            years.add(year);
          }
        }
      }
    }

    years.sort((a, b) {
      return b.compareTo(a);
    });

    return years;
  }
}
