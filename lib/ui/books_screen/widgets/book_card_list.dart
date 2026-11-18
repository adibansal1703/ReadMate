import 'dart:io';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:readmate/core/constants/enums/enums.dart';
import 'package:readmate/generated/locale_keys.g.dart';
import 'package:readmate/logic/bloc/rating_type_bloc/rating_type_bloc.dart';
import 'package:readmate/logic/cubit/edit_book_cubit.dart';
import 'package:readmate/model/book.dart';
import 'package:readmate/model/reading.dart';
import 'package:readmate/ui/common/book_cover.dart';

class BookCardList extends StatelessWidget {
  const BookCardList({
    super.key,
    required this.book,
    required this.onPressed,
    required this.heroTag,
    required this.addBottomPadding,
    this.onLongPressed,
    this.cardColor,
  });

  final Book book;
  final String heroTag;
  final bool addBottomPadding;
  final Function() onPressed;
  final Function()? onLongPressed;
  final Color? cardColor;

  Widget _buildSortAttribute() {
    return const SizedBox();
  }

  Widget _buildTags(BuildContext context) {
    return const SizedBox();
  }

  @override
  Widget build(BuildContext context) {
    final coverFile = book.getCoverFile();

    return Padding(
      padding: EdgeInsets.fromLTRB(5, 0, 5, addBottomPadding ? 90 : 5),
      child: Card.filled(
        color: cardColor,
        child: InkWell(
          onTap: onPressed,
          onLongPress: onLongPressed,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BookCover(
                  book: book,
                  width: 85,
                  height: 85 * 1.5,
                  heroTag: heroTag,
                ),
                const SizedBox(width: 15),
                _buildDetails(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Expanded _buildDetails(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  book.title,
                  softWrap: true,
                  overflow: TextOverflow.clip,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              book.favourite
                  ? Padding(
                      padding: const EdgeInsets.only(left: 10),
                      child: FaIcon(
                        FontAwesomeIcons.solidHeart,
                        size: 15,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    )
                  : const SizedBox(),
            ],
          ),
          Text(
            book.author,
            softWrap: true,
            overflow: TextOverflow.clip,
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurface.withAlpha(204),
            ),
          ),
          const SizedBox(height: 5),
          if (book.status == BookStatus.inProgress && book.pages != null && book.pages! > 0) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: LinearProgressIndicator(
                    value: book.currentPage / (book.pages ?? 1),
                    backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  "${((book.currentPage / (book.pages ?? 1)) * 100).toStringAsFixed(0)}%",
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    "Page ${book.currentPage} of ${book.pages}",
                    style: const TextStyle(fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: () => _showUpdatePageDialog(context),
                      icon: const Icon(Icons.edit, size: 18),
                      tooltip: "Update Progress",
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(8),
                    ),
                    IconButton(
                      onPressed: () => _finishBook(context),
                      icon: const Icon(Icons.check_circle_outline, size: 18),
                      tooltip: "Mark as Finished",
                      color: Theme.of(context).colorScheme.primary,
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(8),
                    ),
                  ],
                ),
              ],
            ),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              (book.status == BookStatus.read || book.status == BookStatus.unfinished)
                  ? _buildInteractiveRating(context)
                  : const SizedBox(),
              _buildSortAttribute(),
            ],
          ),
          _buildTags(context),
        ],
      ),
    );
  }

  void _finishWithReview(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(LocaleKeys.rate_book.tr()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(LocaleKeys.book_status_finished.tr() + "! 🎉"),
            const SizedBox(height: 20),
            RatingBar.builder(
              initialRating: 0,
              allowHalfRating: true,
              itemCount: 5,
              itemBuilder: (context, _) => const Icon(Icons.star, color: Colors.amber),
              onRatingUpdate: (rating) {
                final dateNow = DateTime.now();
                final date = DateTime(dateNow.year, dateNow.month, dateNow.day);

                final finishedBook = book.copyWith(
                  status: BookStatus.read,
                  rating: (rating * 10).toInt(),
                  currentPage: book.pages ?? book.currentPage,
                  readings: book.readings.isNotEmpty
                      ? (List<Reading>.from(book.readings)..[0] = book.readings[0].copyWith(finishDate: date))
                      : [Reading(finishDate: date)],
                );
                context.read<EditBookCubit>().setBook(finishedBook);
                context.read<EditBookCubit>().updateBook(null, context);
                Navigator.pop(context);
                
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Book finished and rated!")),
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              _finishBook(context);
              Navigator.pop(context);
            },
            child: Text(LocaleKeys.skip.tr()),
          ),
        ],
      ),
    );
  }

  void _finishBook(BuildContext context) {
    final dateNow = DateTime.now();
    final date = DateTime(dateNow.year, dateNow.month, dateNow.day);

    final finishedBook = book.copyWith(
      status: BookStatus.read,
      currentPage: book.pages ?? book.currentPage,
      readings: book.readings.isNotEmpty
          ? (List<Reading>.from(book.readings)..[0] = book.readings[0].copyWith(finishDate: date))
          : [Reading(finishDate: date)],
    );
    context.read<EditBookCubit>().setBook(finishedBook);
    context.read<EditBookCubit>().updateBook(null, context);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Book marked as finished!")),
    );
  }

  void _showUpdatePageDialog(BuildContext context) {
    final controller = TextEditingController(text: book.currentPage.toString());
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Update Progress"),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: "Current Page",
            helperText: book.pages != null ? "Max: ${book.pages}" : null,
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          TextButton(
            onPressed: () {
              final newPage = int.tryParse(controller.text) ?? book.currentPage;
              final totalPages = book.pages;
              if (totalPages != null && newPage > totalPages) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Page number cannot exceed $totalPages")),
                );
                return;
              }

              if (totalPages != null && newPage == totalPages) {
                Navigator.pop(context);
                _finishWithReview(context);
              } else {
                context.read<EditBookCubit>().setBook(book.copyWith(currentPage: newPage));
                context.read<EditBookCubit>().updateBook(null, context);
                Navigator.pop(context);
              }
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  Widget _buildInteractiveRating(BuildContext context) {
    return BlocBuilder<RatingTypeBloc, RatingTypeState>(
      builder: (context, state) {
        return RatingBar.builder(
          initialRating: (book.rating == null) ? 0 : (book.rating! / 10),
          allowHalfRating: true,
          unratedColor: Theme.of(context).colorScheme.surfaceContainerLow,
          glow: false,
          glowRadius: 1,
          itemSize: 24,
          ignoreGestures: false,
          itemPadding: const EdgeInsets.only(right: 3),
          itemBuilder: (context, _) => const FaIcon(
            FontAwesomeIcons.solidStar,
            color: Colors.amber,
          ),
          onRatingUpdate: (rating) {
            final updatedBook = book.copyWith(rating: (rating * 10).toInt());
            context.read<EditBookCubit>().setBook(updatedBook);
            context.read<EditBookCubit>().updateBook(null, context);
            
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("Rating updated to $rating stars!"),
                duration: const Duration(seconds: 1),
              ),
            );
          },
        );
      },
    );
  }
}
