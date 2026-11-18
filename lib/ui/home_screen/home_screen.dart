import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:readmate/core/constants/constants.dart';
import 'package:readmate/core/constants/enums/enums.dart';
import 'package:readmate/core/themes/app_theme.dart';
import 'package:readmate/generated/locale_keys.g.dart';
import 'package:readmate/logic/bloc/theme_bloc/theme_bloc.dart';
import 'package:readmate/logic/cubit/auth_cubit.dart';
import 'package:readmate/logic/cubit/edit_book_cubit.dart';
import 'package:readmate/logic/cubit/selected_books_cubit.dart';
import 'package:readmate/model/book.dart';
import 'package:readmate/ui/add_book_screen/add_book_screen.dart';
import 'package:readmate/ui/books_screen/books_screen.dart';
import 'package:readmate/ui/search_ol_screen/search_ol_screen.dart';
import 'package:readmate/ui/settings_screen/settings_screen.dart';
import 'package:readmate/ui/statistics_screen/statistics_screen.dart';

import 'package:readmate/logic/cubit/book_cubit.dart';

import 'widgets/widgets.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int currentPageIndex = 0;

  late List<String> menuOptions;
  late double appBarHeight;

  void openSortFilterSheet() {
    FocusManager.instance.primaryFocus?.unfocus();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return const SortBottomSheet();
      },
    );
  }

  void goToSettingsScreen() {
    FocusManager.instance.primaryFocus?.unfocus();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SettingsScreen(),
      ),
    );
  }

  Future<void> _invokeMenuOption(String choice) async {
    await Future.delayed(const Duration(milliseconds: 0));

    if (!mounted) return;

    if (currentPageIndex == 0) {
      if (choice == menuOptions[0]) {
        openSortFilterSheet();
      } else if (choice == menuOptions[1]) {
        goToSettingsScreen();
      }
    } else {
      if (choice == LocaleKeys.settings.tr()) {
        goToSettingsScreen();
      }
    }
  }

  BookStatus _getStatusForNewBook() {
    return BookStatus.inProgress;
  }

  void _setEmptyBookForEditScreen() {
    final status = _getStatusForNewBook();
    final book = Book.empty(status: status);
    context.read<EditBookCubit>().setBook(book);
  }

  void _onFabPressed() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return AddBookSheet(
          addManually: _addBookManually,
          searchInOpenLibrary: _searchInOpenLibrary,
        );
      },
    );
  }

  Future<void> _addBookManually() async {
    _setEmptyBookForEditScreen();
    context.read<EditBookCoverCubit>().setCover(null);

    Navigator.pop(context);
    await Future.delayed(const Duration(milliseconds: 100));
    if (!mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const AddBookScreen(),
      ),
    );
  }

  Future<void> _searchInOpenLibrary() async {
    _setEmptyBookForEditScreen();
    context.read<EditBookCoverCubit>().setCover(null);

    Navigator.pop(context);
    await Future.delayed(const Duration(milliseconds: 100));
    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SearchOLScreen(
          status: _getStatusForNewBook(),
        ),
      ),
    );
  }

  void _generateMenuOptions() {
    menuOptions = [];

    if (currentPageIndex == 0) {
      menuOptions.add(LocaleKeys.sort_filter.tr());
    }
    menuOptions.add(LocaleKeys.settings.tr());
  }

  @override
  void initState() {
    appBarHeight = AppBar().preferredSize.height;

    super.initState();
  }



  @override
  Widget build(BuildContext context) {
    _generateMenuOptions();

    return BlocBuilder<ThemeBloc, ThemeState>(
      builder: (context, themeState) {
        if (themeState is SetThemeState) {
          AppTheme.init(themeState, context);

          return BlocBuilder<SelectedBooksCubit, List<int>>(
              builder: (context, list) {
            return PopScope(
              canPop: list.isEmpty && currentPageIndex == 0,
              onPopInvokedWithResult: (didPop, result) {
                if (didPop) {
                  return;
                }

                if (currentPageIndex == 0) {
                  context.read<SelectedBooksCubit>().resetSelection();
                } else {
                  setState(() {
                    currentPageIndex = 0;
                  });
                }
              },
              child: Scaffold(
                extendBodyBehindAppBar: true,
                resizeToAvoidBottomInset: true,
                appBar: list.isNotEmpty
                    ? _buildMultiSelectAppBar(context, list)
                    : _buildAppBar(context),
                floatingActionButton: _buildFAB(context, themeState, list),
                body: _buildScaffoldBody(),
                bottomNavigationBar: HomeNavigationBar(
                  currentIndex: currentPageIndex,
                  onTap: (index) {
                    context.read<SelectedBooksCubit>().resetSelection();
                    setState(() {
                      currentPageIndex = index;
                    });
                  },
                ),
              ),
            );
          });
        } else {
          return const SizedBox();
        }
      },
    );
  }

  Widget _buildScaffoldBody() {
    switch (currentPageIndex) {
      case 0:
        return const BooksScreen();
      case 1:
        return const StatisticsScreen();
      default:
        return const SizedBox.shrink();
    }
  }

  AppBar _buildMultiSelectAppBar(
    BuildContext context,
    List<int> multiSelectList,
  ) {
    return AppBar(
        title: Row(
      children: [
        IconButton(
          icon: const FaIcon(FontAwesomeIcons.xmark, size: 18),
          onPressed: () {
            context.read<SelectedBooksCubit>().resetSelection();
          },
        ),
        Text(
          '${LocaleKeys.selected.tr()} ${multiSelectList.length}',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ],
    ));
  }

  Widget _buildFAB(
    BuildContext context,
    SetThemeState state,
    List<int> multiSelectList,
  ) {
    return currentPageIndex != 0
        ? const SizedBox.shrink()
        : multiSelectList.isNotEmpty
            ? MultiSelectFAB()
            : FloatingActionButton(
                onPressed: _onFabPressed,
                child: const FaIcon(FontAwesomeIcons.plus),
              );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    final authState = context.read<AuthCubit>().state;
    String? username;
    if (authState is Authenticated) {
      username = authState.user.username;
    }

    return AppBar(
      elevation: 0,
      scrolledUnderElevation: 0,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (username != null)
            Text(
              '@$username',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.normal,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
          const Text(
            Constants.appName,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ],
      ),
      actions: [
        PopupMenuButton<String>(
          onSelected: (_) {},
          itemBuilder: (_) {
            return menuOptions.map((String choice) {
              return PopupMenuItem<String>(
                value: choice,
                child: Text(
                  choice,
                ),
                onTap: () => _invokeMenuOption(choice),
              );
            }).toList();
          },
        ),
      ],
    );
  }
}
