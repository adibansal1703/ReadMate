import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:readmate/core/themes/app_theme.dart';
import 'package:readmate/logic/cubit/current_book_cubit.dart';
import 'package:readmate/model/book.dart';
import 'package:readmate/ui/book_screen/book_screen.dart';
import 'package:readmate/ui/common/book_cover.dart';

class ReadStats extends StatelessWidget {
  const ReadStats({
    super.key,
    required this.title,
    required this.value,
    this.secondValue,
    this.iconData,
    this.book,
  });

  final String title;
  final String value;
  final String? secondValue;
  final IconData? iconData;
  final Book? book;

  onTap(BuildContext context, int heroKey) {
    final b = book;
    if (b == null) return;
    context.read<CurrentBookCubit>().setBook(b);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BookScreen(heroTag: '${b.id}-$heroKey'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final heroKey = Random().nextInt(1000000);

    return InkWell(
      borderRadius: BorderRadius.circular(cornerRadius),
      onTap: book != null && book!.id != null
          ? () => onTap(context, heroKey)
          : null,
      child: Card.filled(
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 5),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (book != null && book!.hasCover)
                    Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: BookCover(
                        book: book!,
                        width: 70,
                        height: 70 * 1.5,
                        heroTag: '${book?.id}-$heroKey',
                      ),
                    ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        (iconData == null)
                            ? Text(
                                value,
                                style: const TextStyle(fontSize: 14),
                              )
                            : Row(
                                children: [
                                  Text(
                                    value,
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                  const SizedBox(width: 5),
                                  Icon(
                                    iconData,
                                    size: 18,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primaryContainer,
                                  ),
                                ],
                              ),
                        (secondValue == null)
                            ? const SizedBox()
                            : Text(
                                secondValue!,
                                style: const TextStyle(fontSize: 14),
                              ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
