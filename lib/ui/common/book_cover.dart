import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:readmate/model/book.dart';
import 'package:readmate/resources/api_auth_repository.dart';

class BookCover extends StatelessWidget {
  final Book book;
  final double? width;
  final double? height;
  final double borderRadius;
  final String? heroTag;
  final BoxFit fit;
  final Widget? placeholder;

  const BookCover({
    super.key,
    required this.book,
    this.width,
    this.height,
    this.borderRadius = 4.0,
    this.heroTag,
    this.fit = BoxFit.cover,
    this.placeholder,
  });

  @override
  Widget build(BuildContext context) {
    final coverFile = book.getCoverFile();
    
    Widget content;
    
    if (book.cover != null) {
      content = Image.memory(
        book.cover!,
        width: width,
        height: height,
        fit: fit,
      );
    } else if (coverFile != null) {
      content = Image.file(
        coverFile,
        width: width,
        height: height,
        fit: fit,
      );
    } else {
      String? remoteUrl = _getEffectiveCoverUrl();
      if (remoteUrl != null) {
        content = CachedNetworkImage(
          imageUrl: remoteUrl,
          width: width,
          height: height,
          fit: fit,
          placeholder: (context, url) => placeholder ?? _buildPlaceholder(context),
          errorWidget: (context, url, error) {
            debugPrint("Image Loading Error for Book ${book.id} (${book.title}): $error \nURL: $url");
            return placeholder ?? _buildPlaceholder(context);
          },
        );
      } else {
        content = placeholder ?? _buildPlaceholder(context);
      }
    }

    if (heroTag != null) {
      content = Hero(
        tag: heroTag!,
        child: content,
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: content,
    );
  }

  String? _getEffectiveCoverUrl() {
    if (book.coverUrl != null && book.coverUrl!.isNotEmpty) {
      String url = book.coverUrl!;
      if (url.contains('/uploads/')) {
        final serverHost = ApiAuthRepository.baseUrl.replaceAll('/api', '');
        final filename = url.split('/uploads/')[1];
        return '$serverHost/uploads/$filename';
      }
      return url;
    }
    if (book.olid != null && book.olid!.isNotEmpty) {
      final cleanOlid = book.olid!
          .replaceAll('/books/', '')
          .replaceAll('/works/', '')
          .replaceAll('/', '')
          .trim();
      if (cleanOlid.isNotEmpty) {
        return 'https://covers.openlibrary.org/b/olid/$cleanOlid-M.jpg';
      }
    }
    if (book.isbn != null && book.isbn!.isNotEmpty) {
      final cleanIsbn = book.isbn!.replaceAll(RegExp(r'[\s\-]'), '').trim();
      if (cleanIsbn.isNotEmpty) {
        return 'https://covers.openlibrary.org/b/isbn/$cleanIsbn-M.jpg';
      }
    }
    return null;
  }

  Widget _buildPlaceholder(BuildContext context) {
    final isSmall = width != null && width! < 100;
    return Container(
      width: width,
      height: height,
      padding: EdgeInsets.all(isSmall ? 6 : 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.primaryContainer,
            Theme.of(context).colorScheme.surfaceContainerHighest,
          ],
        ),
        borderRadius: BorderRadius.circular(borderRadius),
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
              size: isSmall ? 16 : 22,
              color: Theme.of(context).colorScheme.primary.withOpacity(0.8),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                book.title,
                maxLines: isSmall ? 2 : 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: isSmall ? 10 : 13,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
              if (book.author.isNotEmpty && !isSmall) ...[
                const SizedBox(height: 2),
                Text(
                  book.author,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.8),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
