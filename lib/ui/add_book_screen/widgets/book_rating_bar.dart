import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:readmate/core/themes/app_theme.dart';
import 'package:readmate/logic/cubit/edit_book_cubit.dart';
import 'package:readmate/model/book.dart';

class BookRatingBar extends StatelessWidget {
  const BookRatingBar({
    super.key,
    required this.animDuration,
  });

  final Duration animDuration;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<EditBookCubit, Book>(
      builder: (context, state) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                clipBehavior: Clip.hardEdge,
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceVariant
                      .withOpacity(0.5),
                  borderRadius: BorderRadius.circular(cornerRadius),
                ),
                child: Center(
                  child: RatingBar.builder(
                    unratedColor: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerLow,
                    initialRating:
                        (state.rating == null) ? 0.0 : (state.rating ?? 0) / 10,
                    allowHalfRating: true,
                    glow: false,
                    glowRadius: 1,
                    itemSize: 42,
                    itemPadding: const EdgeInsets.all(5),
                    wrapAlignment: WrapAlignment.center,
                    itemBuilder: (_, __) => const Icon(
                      Icons.star_rounded,
                      color: Colors.amber,
                    ),
                    onRatingUpdate: (rating) {
                      FocusManager.instance.primaryFocus?.unfocus();

                      context.read<EditBookCubit>().setRating(rating);
                    },
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
