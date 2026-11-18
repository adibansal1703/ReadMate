import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:readmate/core/constants/constants.dart';
import 'package:readmate/core/constants/enums/book_status.dart';
import 'package:readmate/core/themes/app_theme.dart';
import 'package:readmate/generated/locale_keys.g.dart';
import 'package:readmate/logic/cubit/book_cubit.dart';
import 'package:readmate/logic/cubit/current_book_cubit.dart';
import 'package:readmate/logic/cubit/edit_book_cubit.dart';
import 'package:readmate/model/book.dart';
import 'package:readmate/ui/add_book_screen/widgets/widgets.dart';
import 'package:readmate/ui/book_screen/book_screen.dart';
import 'package:readmate/ui/common/keyboard_dismissable.dart';

class AddBookScreen extends StatefulWidget {
  const AddBookScreen({
    super.key,
    this.editingExistingBook = false,
  });

  final bool editingExistingBook;

  @override
  State<AddBookScreen> createState() => _AddBookScreenState();
}

class _AddBookScreenState extends State<AddBookScreen> {
  final _titleCtrl = TextEditingController();
  final _authorCtrl = TextEditingController();
  final _pagesCtrl = TextEditingController();
  final _currentPageCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  final _animDuration = const Duration(milliseconds: 250);
  bool _isSaving = false;

  void _prefillBookDetails(Book book) {
    _titleCtrl.text = book.title;
    _authorCtrl.text = book.author;
    _pagesCtrl.text = (book.pages ?? '').toString();
    _currentPageCtrl.text = book.currentPage.toString();
    _notesCtrl.text = book.notes ?? '';
  }

  void _showSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
        ),
      ),
    );
  }

  bool _validate() {
    ScaffoldMessenger.of(context).removeCurrentSnackBar();

    final book = context.read<EditBookCubit>().state;

    if (book.title.isEmpty) {
      _showSnackbar(LocaleKeys.title_cannot_be_empty.tr());
      return false;
    }

    if (book.author.isEmpty) {
      _showSnackbar(LocaleKeys.author_cannot_be_empty.tr());
      return false;
    }

    return true;
  }

  Future<bool> _checkDuplicateISBN(Book book) async {
    if (book.isbn == null || book.isbn!.trim().isEmpty) return false;

    final existingBook = context.read<BookCubit>().findBookByISBN(book.isbn);
    if (existingBook != null) {
      final shouldView = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(cornerRadius),
            ),
            title: const Text("Book Already Exists"),
            content: Text(
              "A book with ISBN ${book.isbn} ('${existingBook.title}') is already in your library.",
            ),
            actionsAlignment: MainAxisAlignment.spaceBetween,
            actions: [
              FilledButton.tonal(
                style: ButtonStyle(
                  shape: WidgetStateProperty.all(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(cornerRadius),
                    ),
                  ),
                ),
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(LocaleKeys.cancel.tr()),
                ),
              ),
              FilledButton(
                style: ButtonStyle(
                  shape: WidgetStateProperty.all(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(cornerRadius),
                    ),
                  ),
                ),
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Text("View Existing Entry"),
                ),
              ),
            ],
          );
        },
      );

      if (shouldView == true && mounted) {
        context.read<CurrentBookCubit>().setBook(existingBook);
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => const BookScreen(heroTag: ""),
          ),
          (route) => route.isFirst,
        );
      }
      return true;
    }
    return false;
  }

  void _saveNewBook(Book book) async {
    FocusManager.instance.primaryFocus?.unfocus();

    if (!_validate()) return;
    if (!mounted) return;

    final isDuplicate = await _checkDuplicateISBN(book);
    if (isDuplicate) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final cover = context.read<EditBookCoverCubit>().state;
      
      final newBookID = await context.read<EditBookCubit>().addNewBook(cover);
      
      if (!mounted) return;

      context.read<EditBookCoverCubit>().setCover(null);

      context.read<CurrentBookCubit>().setBook(book.copyWith(id: newBookID, hasCover: cover != null));

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => const BookScreen(heroTag: ""),
        ),
        (route) => route.isFirst,
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        
        final errorMessage = e.toString().contains("Exception:") 
            ? e.toString().split("Exception:").last 
            : e.toString();
            
        _showSnackbar("Could not save book: $errorMessage");
        debugPrint("Save error details: $e");
      }
    }
  }

  void _updateBook(Book book) async {
    FocusManager.instance.primaryFocus?.unfocus();

    if (!_validate()) return;
    if (!mounted) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final cover = context.read<EditBookCoverCubit>().state;
      book = book.copyWith(dateModified: DateTime.now(), hasCover: cover != null);
      context.read<EditBookCubit>().setBook(book);
      await context.read<EditBookCubit>().updateBook(cover, context);

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        _showSnackbar(e.toString());
        debugPrint("Update error: $e");
      }
    }
  }

  _attachListeners() {
    _titleCtrl.addListener(() {
      context.read<EditBookCubit>().setTitle(_titleCtrl.text);
    });

    _authorCtrl.addListener(() {
      context.read<EditBookCubit>().setAuthor(_authorCtrl.text);
    });

    _pagesCtrl.addListener(() {
      context.read<EditBookCubit>().setPages(_pagesCtrl.text);
    });

    _currentPageCtrl.addListener(() {
      context.read<EditBookCubit>().setCurrentPage(_currentPageCtrl.text);
    });

    _notesCtrl.addListener(() {
      context.read<EditBookCubit>().setNotes(_notesCtrl.text);
    });
  }

  @override
  void initState() {
    final book = context.read<EditBookCubit>().state;

    _prefillBookDetails(book);
    _attachListeners();

    if (widget.editingExistingBook && book.hasCover) {
      final cover = book.getCoverBytes();
      context.read<EditBookCoverCubit>().setCover(cover);
    } else if (!widget.editingExistingBook) {
    }

    super.initState();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _authorCtrl.dispose();
    _pagesCtrl.dispose();
    _currentPageCtrl.dispose();
    _notesCtrl.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardDismissible(
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.editingExistingBook
                ? LocaleKeys.edit_book.tr()
                : LocaleKeys.add_new_book.tr(),
            style: const TextStyle(fontSize: 18),
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            child: BlocBuilder<EditBookCubit, Book>(
              builder: (context, book) {
                return Column(
                  children: <Widget>[
                    const SizedBox(height: 20),
                    const BookCoverPicker(),
                    const SizedBox(height: 20),
                    BookTextField(
                      controller: _titleCtrl,
                      hint: "Book Title",
                      icon: Icons.title,
                      keyboardType: TextInputType.text,
                      maxLength: 200,
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: 10),
                    BookTextField(
                      controller: _authorCtrl,
                      hint: "Author Name",
                      icon: Icons.person,
                      keyboardType: TextInputType.text,
                      maxLength: 100,
                      textCapitalization: TextCapitalization.words,
                    ),
                    const Padding(
                      padding: EdgeInsets.all(10),
                      child: Divider(),
                    ),
                    BookStatusRow(
                      animDuration: _animDuration,
                      defaultHeight: Constants.formHeight,
                    ),
                    if (book.status == BookStatus.inProgress) ...[
                      const Padding(
                        padding: EdgeInsets.all(10),
                        child: Divider(),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: BookTextField(
                              controller: _pagesCtrl,
                              hint: "Total Pages",
                              icon: Icons.pages,
                              keyboardType: TextInputType.number,
                              maxLength: 10,
                            ),
                          ),
                          Expanded(
                            child: BookTextField(
                              controller: _currentPageCtrl,
                              hint: "Current Page",
                              icon: Icons.menu_book,
                              keyboardType: TextInputType.number,
                              maxLength: 10,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 10),
                    if (book.status == BookStatus.read || book.status == BookStatus.unfinished) ...[
                      BookRatingBar(animDuration: _animDuration),
                      const Padding(
                        padding: EdgeInsets.all(10),
                        child: Divider(),
                      ),
                    ],
                    const SizedBox(height: 10),
                    BookTextField(
                      controller: _notesCtrl,
                      hint: "Add Comments",
                      icon: Icons.comment_outlined,
                      keyboardType: TextInputType.multiline,
                      maxLength: 5000,
                      hideCounter: false,
                      maxLines: 10,
                      textCapitalization: TextCapitalization.sentences,
                    ),
                    const SizedBox(height: 30),
                    Row(
                      children: [
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 10,
                          child: FilledButton.tonal(
                            onPressed: () => Navigator.pop(context),
                            style: ButtonStyle(
                              shape: WidgetStateProperty.all(
                                  RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(cornerRadius),
                              )),
                            ),
                            child: Center(child: Text(LocaleKeys.cancel.tr())),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 19,
                          child: BlocBuilder<EditBookCubit, Book>(
                            builder: (context, state) {
                              return FilledButton(
                                onPressed: (_isSaving)
                                    ? null
                                    : (state.id != null)
                                        ? () => _updateBook(state)
                                        : () => _saveNewBook(state),
                                style: ButtonStyle(
                                  shape: WidgetStateProperty.all(
                                      RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                        cornerRadius),
                                  )),
                                ),
                                child: Center(
                                  child: _isSaving
                                      ? const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : Text(LocaleKeys.save.tr()),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                    ),
                    const SizedBox(height: 50.0),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
