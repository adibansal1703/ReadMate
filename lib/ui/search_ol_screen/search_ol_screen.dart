import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:readmate/core/constants/enums/enums.dart';
import 'package:readmate/core/themes/app_theme.dart';
import 'package:readmate/generated/locale_keys.g.dart';
import 'package:readmate/logic/bloc/open_library_search_bloc/open_library_search_bloc.dart';
import 'package:readmate/logic/cubit/edit_book_cubit.dart';
import 'package:readmate/model/ol_edition_result.dart';
import 'package:readmate/model/book.dart';
import 'package:readmate/model/ol_search_result.dart';
import 'package:readmate/resources/open_library_service.dart';
import 'package:readmate/ui/add_book_screen/add_book_screen.dart';
import 'package:readmate/ui/add_book_screen/widgets/widgets.dart';
import 'package:readmate/ui/common/keyboard_dismissable.dart';
import 'package:readmate/ui/search_ol_editions_screen/search_ol_editions_screen.dart';
import 'package:readmate/ui/search_ol_screen/widgets/widgets.dart';

class SearchOLScreen extends StatefulWidget {
  const SearchOLScreen({
    super.key,
    required this.status,
  });

  final BookStatus status;

  @override
  State<SearchOLScreen> createState() => _SearchOLScreenState();
}

class _SearchOLScreenState extends State<SearchOLScreen>
    with AutomaticKeepAliveClientMixin {
  final _searchController = TextEditingController();
  int offset = 0;
  final _pageSize = 10;
  String? _searchTerm;
  int? numberOfResults;
  int searchTimestamp = 0;

  bool searchActivated = false;
  bool _searchingISBN = false;
  bool _searchingISBNError = false;

  List<OLSearchResultDoc> _trendingBooks = [];
  bool _isLoadingTrending = false;

  late final _pagingController = PagingController<int, OLSearchResultDoc>(
    fetchPage: (pageKey) => _fetchPage(pageKey),
    getNextPageKey: (state) =>
        state.lastPageIsEmpty ? null : state.nextIntPageKey,
  );

  void _saveNoEdition({
    required List<String> editions,
    required String title,
    String? subtitle,
    required String author,
    int? firstPublishYear,
    int? pagesMedian,
    int? cover,
    List<String>? isbn,
    String? olid,
  }) async {
    final book = Book(
      title: title,
      subtitle: subtitle,
      author: author,
      status: widget.status,
      favourite: false,
      pages: pagesMedian,
      isbn: (isbn != null && isbn.isNotEmpty) ? isbn[0] : null,
      olid: (olid != null) ? olid.replaceAll('/works/', '') : null,
      publicationYear: firstPublishYear,
      readings: const [],
      dateAdded: DateTime.now(),
      dateModified: DateTime.now(),
    );

    context.read<EditBookCubit>().setBook(book);

    if (book.isbn != null) {
      final coverBytes = await OpenLibraryService().getCover(book.isbn!);
      if (mounted) {
        context.read<EditBookCoverCubit>().setCover(coverBytes);
      }
    }

    if (mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const AddBookScreen(),
        ),
      );
    }
  }

  void _saveEdition({
    required OLEditionResult result,
    required int? cover,
    String? work,
    String? authors,
  }) async {
    if (!mounted) return;

    final addDate = DateTime.now();
    final isbn = (result.isbn13 != null && result.isbn13!.isNotEmpty)
          ? result.isbn13![0]
          : (result.isbn10 != null && result.isbn10!.isNotEmpty)
              ? result.isbn10![0]
              : null;

    final book = Book(
      title: result.title!,
      subtitle: result.subtitle,
      author: authors ?? '',
      pages: result.numberOfPages,
      status: widget.status,
      favourite: false,
      isbn: isbn,
      olid: (result.key != null) ? result.key!.replaceAll('/books/', '') : null,
      publicationYear: int.tryParse(result.publishDate ?? ''),
      readings: const [],
      dateAdded: addDate,
      dateModified: addDate,
    );

    context.read<EditBookCubit>().setBook(book);

    if (isbn != null) {
      final coverBytes = await OpenLibraryService().getCover(isbn);
      if (mounted) {
        context.read<EditBookCoverCubit>().setCover(coverBytes);
      }
    }

    if (mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const AddBookScreen(),
        ),
      );
    }
  }

  Future<List<OLSearchResultDoc>> _fetchPage(int pageKey) async {
    final searchTimestampSaved = DateTime.now().millisecondsSinceEpoch;
    searchTimestamp = searchTimestampSaved;

    try {
      if (_searchTerm == null) return [];

      final newItems = await OpenLibraryService().getResults(
        query: _searchTerm!,
        offset: (pageKey - 1) * _pageSize,
        limit: _pageSize,
        searchType: _getOLSearchTypeEnum(
          context.read<OpenLibrarySearchBloc>().state,
        ),
      );

      if (searchTimestamp != searchTimestampSaved) return [];

      setState(() {
        numberOfResults = newItems.numFound;
      });

      return newItems.docs;
    } catch (error) {
      return [];
    }
  }

  void _startNewSearch() {
    if (_searchController.text.isEmpty) return;

    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _searchingISBNError = false;
      _searchingISBN = false;
      searchActivated = true;
    });

    if (context.read<OpenLibrarySearchBloc>().state is OpenLibrarySearchISBN) {
      final isbn = _searchController.text.replaceAll('-', '').trim();
      _searchByISBN(isbn);
    } else {
      _searchTerm = _searchController.text;

      _pagingController.refresh();
    }
  }

  void _searchByISBN(String isbn) async {
    setState(() {
      _searchingISBNError = false;
      _searchingISBN = true;
    });
    final edition = await OpenLibraryService().getEditionByISBN(isbn: isbn);

    final authors = List<String>.empty(growable: true);
    for (final author in edition?.authors ?? []) {
      final authorResult =
          await OpenLibraryService().getAuthor(key: author.key);

      if (authorResult?.name != null) {
        authors.add(authorResult!.name!);
      }
    }

    if (edition != null) {
      setState(() {
        searchActivated = false;
      });

      _saveEdition(
        result: edition,
        cover: edition.covers != null && edition.covers!.isNotEmpty
            ? edition.covers![0]
            : null,
        work: edition.works != null && edition.works!.isNotEmpty
            ? edition.works![0].key
            : null,
        authors: authors.join(', '),
      );
    } else {
      setState(() {
        _searchingISBN = false;
        _searchingISBNError = true;
      });
    }
  }

  OLSearchType _getOLSearchTypeEnum(OpenLibrarySearchState state) {
    if (state is OpenLibrarySearchGeneral) {
      return OLSearchType.general;
    } else if (state is OpenLibrarySearchAuthor) {
      return OLSearchType.author;
    } else if (state is OpenLibrarySearchTitle) {
      return OLSearchType.title;
    } else if (state is OpenLibrarySearchISBN) {
      return OLSearchType.isbn;
    } else {
      return OLSearchType.general;
    }
  }

  _changeSearchType(OLSearchType? value) async {
    final openLibrarySearchBloc = context.read<OpenLibrarySearchBloc>();

    switch (value) {
      case OLSearchType.author:
        openLibrarySearchBloc.add(const OpenLibrarySearchSetAuthor());
        break;
      case OLSearchType.title:
        openLibrarySearchBloc.add(const OpenLibrarySearchSetTitle());
        break;
      case OLSearchType.isbn:
        openLibrarySearchBloc.add(const OpenLibrarySearchSetISBN());
        break;
      default:
        openLibrarySearchBloc.add(const OpenLibrarySearchSetGeneral());
        break;
    }

    await Future.delayed(const Duration(milliseconds: 100));

    _startNewSearch();
  }

  _onChooseEditionPressed(OLSearchResultDoc item) async {
    FocusManager.instance.primaryFocus?.unfocus();

    List<String> editions = item.editionKey ?? [];
    
    if (editions.isEmpty && item.key != null) {
      final fetchedEditions = await OpenLibraryService().getWorkEditions(item.key!);
      editions = fetchedEditions;
    }

    if (!mounted) return;

    if (editions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No editions found for this book.")),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SearchOLEditionsScreen(
          status: widget.status,
          editions: editions,
          title: item.title!,
          subtitle: item.subtitle,
          author: (item.authorName != null && item.authorName!.isNotEmpty)
              ? item.authorName![0]
              : '',
          pagesMedian: item.medianPages,
          isbn: item.isbn,
          olid: item.key,
          firstPublishYear: item.firstPublishYear,
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _fetchTrending();
  }

  Future<void> _fetchTrending() async {
    setState(() {
      _isLoadingTrending = true;
    });
    try {
      final results = await OpenLibraryService().getTrending();
      if (mounted) {
        setState(() {
          _trendingBooks = results;
          _isLoadingTrending = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingTrending = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _pagingController.dispose();
    super.dispose();
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return KeyboardDismissible(
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            LocaleKeys.add_search.tr(),
            style: const TextStyle(fontSize: 18),
          ),
        ),
        body: Column(
          children: [
            _buildSearchField(context),
            _buildSearchTypesRadio(),
            _buildDivider(),
            _buildNumberOfResults(),
            (searchActivated)
                ? Expanded(
                    child: _searchingISBN
                        ? _buildFirstPageProgressIndicator(context)
                        : _searchingISBNError
                            ? _buildNoItemsFoundIndicator()
                            : _buildSearchResults(),
                  )
                : Expanded(child: _buildTrendingList()),
          ],
        ),
      ),
    );
  }

  Widget _buildTrendingList() {
    if (_isLoadingTrending) {
      return _buildFirstPageProgressIndicator(context);
    }

    if (_trendingBooks.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Text(
            "Trending Books Today",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _trendingBooks.length,
            itemBuilder: (context, index) {
              return _buildResultCard(_trendingBooks[index]);
            },
          ),
        ),
      ],
    );
  }

  Scrollbar _buildSearchResults() {
    return Scrollbar(
      child: PagingListener(
        controller: _pagingController,
        builder: (context, state, fetchNextPage) =>
            PagedListView<int, OLSearchResultDoc>(
          state: state,
          fetchNextPage: fetchNextPage,
          builderDelegate: PagedChildBuilderDelegate<OLSearchResultDoc>(
            firstPageProgressIndicatorBuilder: (_) =>
                _buildFirstPageProgressIndicator(context),
            newPageProgressIndicatorBuilder: (_) =>
                _buildNewPageProgressIndicator(context),
            noItemsFoundIndicatorBuilder: (_) => _buildNoItemsFoundIndicator(),
            itemBuilder: (context, item, index) => _buildResultCard(item),
          ),
        ),
      ),
    );
  }

  Center _buildFirstPageProgressIndicator(BuildContext context) {
    return Center(
      child: LoadingAnimationWidget.staggeredDotsWave(
        color: Theme.of(context).colorScheme.primary,
        size: 42,
      ),
    );
  }

  Builder _buildResultCard(OLSearchResultDoc item) {
    return Builder(builder: (context) {
      return BookCardOL(
        title: item.title ?? '',
        subtitle: item.subtitle,
        author: (item.authorName != null && item.authorName!.isNotEmpty)
            ? item.authorName![0]
            : '',
        coverKey: item.coverEditionKey,
        editions: item.editionKey,
        pagesMedian: item.medianPages,
        firstPublishYear: item.firstPublishYear,
        onAddBookPressed: () => _saveNoEdition(
          editions: item.editionKey ?? [],
          title: item.title ?? '',
          subtitle: item.subtitle,
          author: (item.authorName != null && item.authorName!.isNotEmpty)
              ? item.authorName![0]
              : '',
          pagesMedian: item.medianPages,
          isbn: item.isbn,
          olid: item.key,
          firstPublishYear: item.firstPublishYear,
          cover: item.coverI,
        ),
        onChooseEditionPressed: () => _onChooseEditionPressed(item),
      );
    });
  }

  Center _buildNoItemsFoundIndicator() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              children: [
                Text(
                  LocaleKeys.no_search_results.tr(),
                  style: const TextStyle(
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Center _buildNewPageProgressIndicator(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: LoadingAnimationWidget.staggeredDotsWave(
          color: Theme.of(context).colorScheme.primary,
          size: 42,
        ),
      ),
    );
  }

  SingleChildRenderObjectWidget _buildNumberOfResults() {
    return (numberOfResults != null && numberOfResults! != 0)
        ? Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '$numberOfResults ${LocaleKeys.results_lowercase.tr()}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          )
        : const SizedBox();
  }

  Padding _buildDivider() {
    return const Padding(
      padding: EdgeInsets.fromLTRB(10, 0, 10, 10),
      child: Divider(height: 3),
    );
  }

  Align _buildSearchTypesRadio() {
    return Align(
      alignment: Alignment.centerLeft,
      child: BlocBuilder<OpenLibrarySearchBloc, OpenLibrarySearchState>(
        builder: (context, state) {
          return Wrap(
            alignment: WrapAlignment.start,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (var i = 0; i < 4; i++) ...[
                if (i != 0) const SizedBox(width: 5),
                OLSearchRadio(
                  searchType: OLSearchType.values[i],
                  activeSearchType: _getOLSearchTypeEnum(state),
                  onChanged: _changeSearchType,
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Padding _buildSearchField(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 10, 10, 5),
      child: Row(
        children: [
          Expanded(
            child: BookTextField(
              controller: _searchController,
              keyboardType: TextInputType.name,
              maxLength: 99,
              autofocus: true,
              textInputAction: TextInputAction.search,
              textCapitalization: TextCapitalization.sentences,
              onSubmitted: (_) => _startNewSearch(),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: _startNewSearch,
              style: ElevatedButton.styleFrom(
                elevation: 0,
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(cornerRadius),
                ),
              ),
              child: Text(
                LocaleKeys.search.tr(),
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
