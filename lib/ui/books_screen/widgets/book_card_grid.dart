import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:readmate/core/constants/enums/enums.dart';
import 'package:readmate/core/themes/app_theme.dart';
import 'package:readmate/logic/cubit/edit_book_cubit.dart';
import 'package:readmate/model/book.dart';
import 'package:readmate/ui/common/book_cover.dart';

class BookCardGrid extends StatelessWidget {
  const BookCardGrid({
    super.key,
    required this.book,
    required this.onPressed,
    required this.heroTag,
    required this.addBottomPadding,
    this.onLongPressed,
  });

  final Book book;
  final String heroTag;
  final bool addBottomPadding;
  final Function() onPressed;
  final Function()? onLongPressed;

  @override
  Widget build(BuildContext context) {
    return Card.filled(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: Stack(
        children: [
          InkWell(
            onTap: onPressed,
            onLongPress: onLongPressed,
            borderRadius: BorderRadius.circular(8),
            child: BookCover(
              book: book,
              heroTag: heroTag,
              borderRadius: 8,
              placeholder: _buildCardWithoutCover(book: book, context: context),
            ),
          ),
          if (book.status == BookStatus.inProgress)
            Positioned(
              bottom: 6,
              right: 6,
              child: Material(
                color: Theme.of(context).colorScheme.primaryContainer,
                shape: const CircleBorder(),
                elevation: 3,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => _showUpdatePageDialog(context),
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Icon(
                      Icons.edit,
                      size: 16,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
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
            helperText: book.pages != null && book.pages! > 0 ? "Max: ${book.pages}" : null,
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          TextButton(
            onPressed: () {
              final newPage = int.tryParse(controller.text) ?? book.currentPage;
              final totalPages = book.pages;
              if (totalPages != null && totalPages > 0 && newPage > totalPages) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Page number cannot exceed $totalPages")),
                );
                return;
              }

              context.read<EditBookCubit>().setBook(book.copyWith(currentPage: newPage));
              context.read<EditBookCubit>().updateBook(null, context);
              Navigator.pop(context);
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  Widget _buildCardWithoutCover({
    required Book book,
    required BuildContext context,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.primaryContainer,
            Theme.of(context).colorScheme.surfaceContainerHighest,
          ],
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Align(
            alignment: Alignment.topRight,
            child: Icon(
              Icons.book_outlined,
              size: 24,
              color: Theme.of(context).colorScheme.primary.withOpacity(0.7),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                book.title,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                book.author,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

}
