part of 'stats_bloc.dart';

abstract class StatsState extends Equatable {
  const StatsState();

  @override
  List<Object> get props => [];
}

class StatsLoading extends StatsState {}

class StatsLoaded extends StatsState {
  final List<int> years;
  final List<Book> finishedBooks;
  final List<Book> inProgressBooks;
  final List<Book> forLaterBooks;
  final List<Book> unfinishedBooks;
  final int finishedBooksAll;
  final int finishedPagesAll;
  final double avgBooksPerMonth;
  final double avgPagesPerDay;
  final double avgRating;
  final int ratedBooksCount;
  final Map<int, int> monthlyStats;

  const StatsLoaded({
    required this.years,
    required this.finishedBooks,
    required this.inProgressBooks,
    required this.forLaterBooks,
    required this.unfinishedBooks,
    required this.finishedBooksAll,
    required this.finishedPagesAll,
    required this.avgBooksPerMonth,
    required this.avgPagesPerDay,
    required this.avgRating,
    required this.ratedBooksCount,
    required this.monthlyStats,
  });

  @override
  List<Object> get props => [
        years,
        finishedBooks,
        inProgressBooks,
        forLaterBooks,
        unfinishedBooks,
        finishedBooksAll,
        finishedPagesAll,
        avgBooksPerMonth,
        avgPagesPerDay,
        avgRating,
        ratedBooksCount,
        monthlyStats,
      ];
}

class StatsError extends StatsState {
  final String msg;

  const StatsError(
    this.msg,
  );

  @override
  List<Object> get props => [msg];
}
