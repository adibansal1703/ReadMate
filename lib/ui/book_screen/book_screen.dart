import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:readmate/core/constants/enums/enums.dart';
import 'package:readmate/generated/locale_keys.g.dart';
import 'package:readmate/logic/cubit/current_book_cubit.dart';
import 'package:readmate/main.dart';
import 'package:readmate/model/book.dart';
import 'package:readmate/model/reading.dart';
import 'package:readmate/ui/book_screen/widgets/widgets.dart';
import 'package:readmate/ui/common/book_cover.dart';

class BookScreen extends StatelessWidget {
  const BookScreen({
    super.key,
    required this.heroTag,
  });

  final String heroTag;

  _onLikeTap(BuildContext context, Book book) {
    book = book.copyWith(favourite: !book.favourite == true);

    bookCubit.updateBook(book);
    context.read<CurrentBookCubit>().setBook(book);
  }

  IconData? _decideStatusIcon(BookStatus? status) {
    if (status == BookStatus.read) {
      return Icons.done;
    } else if (status == BookStatus.inProgress) {
      return Icons.autorenew;
    } else if (status == BookStatus.forLater) {
      return Icons.timelapse;
    } else if (status == BookStatus.unfinished) {
      return Icons.not_interested;
    } else {
      return null;
    }
  }

  String _decideStatusText(BookStatus? status, BuildContext context) {
    if (status == BookStatus.read) {
      return LocaleKeys.book_status_finished.tr();
    } else if (status == BookStatus.inProgress) {
      return LocaleKeys.book_status_in_progress.tr();
    } else if (status == BookStatus.forLater) {
      return LocaleKeys.book_status_for_later.tr();
    } else if (status == BookStatus.unfinished) {
      return LocaleKeys.book_status_unfinished.tr();
    } else {
      return '';
    }
  }

  String? _decideChangeStatusText(BookStatus? status, BuildContext context) {
    if (status == BookStatus.inProgress) {
      return LocaleKeys.finish_reading.tr();
    } else if (status == BookStatus.forLater) {
      return LocaleKeys.start_reading.tr();
    } else if (status == BookStatus.unfinished) {
      return LocaleKeys.start_reading.tr();
    } else {
      return null;
    }
  }

  Future<int?> _getQuickRating(BuildContext context) async {
    return null;
  }

  void _changeStatusAction(
    BuildContext context,
    BookStatus status,
    Book book,
  ) async {
    final dateNow = DateTime.now();
    final date = DateTime(dateNow.year, dateNow.month, dateNow.day);

    if (status == BookStatus.inProgress) {
      final rating = await _getQuickRating(context);

      book = book.copyWith(
        status: BookStatus.read,
        rating: rating,
        readings: book.readings.isNotEmpty
            ? (List<Reading>.from(book.readings)..[0] = book.readings[0].copyWith(finishDate: date))
            : [Reading(finishDate: date)],
      );
    } else if (status == BookStatus.forLater) {
      book = book.copyWith(
        status: BookStatus.inProgress,
        readings: book.readings.isNotEmpty
            ? (List<Reading>.from(book.readings)..[0] = book.readings[0].copyWith(startDate: date))
            : [Reading(startDate: date)],
      );
    } else if (status == BookStatus.unfinished) {
      book = book.copyWith(
        status: BookStatus.inProgress,
        readings: book.readings.isNotEmpty
            ? (List<Reading>.from(book.readings)..[0] = book.readings[0].copyWith(startDate: date))
            : [Reading(startDate: date)],
      );
    }

    bookCubit.updateBook(book);

    if (!context.mounted) return;
    context.read<CurrentBookCubit>().setBook(book);
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);

    return SelectableRegion(
      selectionControls: materialTextSelectionControls,
      focusNode: FocusNode(),
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: const BookScreenAppBar(),
        body: BlocBuilder<CurrentBookCubit, Book>(
          builder: (context, state) {
            return SingleChildScrollView(
              child: Column(
                children: [
                  _buildCoverSpace(state, mediaQuery),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTitleDetail(state),
                      _buildStatusDetail(state, context),
                      _buildBookFormatDetail(state),
                      _buildPublicationYearDetail(state),
                      _buildPagesDetail(state),
                      _buildISBNDetail(state),
                      _buildOLIDDetail(state),
                      const SizedBox(height: 20),
                      _buildHistoryCheckButton(state, context),
                      const SizedBox(height: 30),
                      _buildDescriptionDetail(state),
                      _buildNotesDetail(state),
                      _buildEditDates(state),
                      const SizedBox(height: 100),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  BookDetailDateAddedUpdated _buildEditDates(Book state) {
    return BookDetailDateAddedUpdated(
      dateAdded: state.dateAdded,
      dateModified: state.dateModified,
    );
  }

  Widget _buildNotesDetail(Book state) {
    return (state.notes != null && state.notes!.isNotEmpty)
        ? BookDetailLong(
            title: LocaleKeys.notes.tr(),
            text: state.notes!,
          )
        : const SizedBox();
  }



  Widget _buildDescriptionDetail(Book state) {
    return (state.description != null && state.description!.isNotEmpty)
        ? BookDetailLong(
            title: LocaleKeys.description.tr(),
            text: state.description!,
          )
        : const SizedBox();
  }

  Widget _buildOLIDDetail(Book state) {
    return (state.olid != null)
        ? BookDetail(
            title: LocaleKeys.open_library_ID.tr(),
            text: (state.olid ?? "").toString(),
          )
        : const SizedBox();
  }

  Widget _buildISBNDetail(Book state) {
    return (state.isbn != null)
        ? BookDetail(
            title: LocaleKeys.isbn.tr(),
            text: (state.isbn ?? "").toString(),
          )
        : const SizedBox();
  }

  Widget _buildPagesDetail(Book state) {
    return (state.pages != null)
        ? BookDetail(
            title: LocaleKeys.pages_uppercase.tr(),
            text: (state.pages ?? "").toString(),
          )
        : const SizedBox();
  }

  Widget _buildBookFormatDetail(Book state) {
    return BookDetail(
      title: LocaleKeys.book_format.tr(),
      text: state.bookFormat == BookFormat.audiobook
          ? LocaleKeys.book_format_audiobook.tr()
          : state.bookFormat == BookFormat.ebook
              ? LocaleKeys.book_format_ebook.tr()
              : state.bookFormat == BookFormat.hardcover
                  ? LocaleKeys.book_format_hardcover.tr()
                  : LocaleKeys.book_format_paperback.tr(),
    );
  }

  Widget _buildPublicationYearDetail(Book state) {
    return (state.publicationYear != null)
        ? BookDetail(
            title: LocaleKeys.enter_publication_year.tr(),
            text: (state.publicationYear ?? "").toString(),
          )
        : const SizedBox();
  }

  Widget _buildCoverSpace(
      Book state, MediaQueryData mediaQuery) {
    return (state.hasCover == true)
        ? Padding(
            padding: EdgeInsets.only(top: mediaQuery.padding.top + 20),
            child: Center(
              child: BookCover(
                book: state,
                width: 200,
                height: 300,
                fit: BoxFit.contain,
              ),
            ),
          )
        : SizedBox(
            height: mediaQuery.padding.top + AppBar().preferredSize.height,
          );
  }

  BookTitleDetail _buildTitleDetail(Book state) {
    return BookTitleDetail(
      title: state.title.toString(),
      subtitle: state.subtitle,
      author: state.author.toString(),
      publicationYear: (state.publicationYear ?? "").toString(),
      tags: state.tags?.split('|||||'),
      bookType: state.bookFormat,
    );
  }

  void _markUnfinishedAction(BuildContext context, Book book) {
    book = book.copyWith(
      status: BookStatus.unfinished,
    );

    bookCubit.updateBook(book);

    if (!context.mounted) return;
    context.read<CurrentBookCubit>().setBook(book);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Marked as Unfinished at page ${book.currentPage > 0 ? book.currentPage : "1"}'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  BookStatusDetail _buildStatusDetail(Book state, BuildContext context) {
    return BookStatusDetail(
      book: state,
      statusIcon: _decideStatusIcon(state.status),
      statusText: _decideStatusText(
        state.status,
        context,
      ),
      onLikeTap: () => _onLikeTap(context, state),
      showChangeStatus: (state.status == BookStatus.inProgress ||
          state.status == BookStatus.forLater ||
          state.status == BookStatus.unfinished),
      changeStatusText: _decideChangeStatusText(
        state.status,
        context,
      ),
      changeStatusAction: () {
        _changeStatusAction(
          context,
          state.status,
          state,
        );
      },
      showUnfinishStatus: (state.status == BookStatus.inProgress),
      unfinishStatusAction: () {
        _markUnfinishedAction(context, state);
      },
      showRatingAndLike: (state.status == BookStatus.read || state.status == BookStatus.unfinished),
    );
  }

  Widget _buildHistoryCheckButton(Book state, BuildContext context) {
    if (state.id == null) return const SizedBox();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 25),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () => BookHistorySheet.show(context, state),
          icon: const Icon(Icons.history, color: Color(0xff00BFA6)),
          label: const Text(
            'History Check & Report',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Color(0xff00BFA6),
            ),
          ),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            side: const BorderSide(color: Color(0xff00BFA6), width: 1.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
    );
  }
}
