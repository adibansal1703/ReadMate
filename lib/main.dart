import 'dart:io';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:path_provider/path_provider.dart';
import 'package:readmate/core/constants/constants.dart';
import 'package:readmate/core/themes/app_theme.dart';
import 'package:readmate/logic/bloc/open_library_search_bloc/open_library_search_bloc.dart';
import 'package:readmate/logic/bloc/rating_type_bloc/rating_type_bloc.dart';
import 'package:readmate/logic/bloc/sort_bloc/sort_finished_books_bloc.dart';
import 'package:readmate/logic/bloc/sort_bloc/sort_for_later_books_bloc.dart';
import 'package:readmate/logic/bloc/sort_bloc/sort_in_progress_books_bloc.dart';
import 'package:readmate/logic/bloc/sort_bloc/sort_unfinished_books_bloc.dart';
import 'package:readmate/logic/bloc/theme_bloc/theme_bloc.dart';
import 'package:readmate/logic/cubit/book_cubit.dart';
import 'package:readmate/logic/cubit/book_lists_order_cubit.dart';
import 'package:readmate/logic/cubit/challenge_cubit.dart';
import 'package:readmate/logic/cubit/current_book_cubit.dart';
import 'package:readmate/logic/cubit/display_cubit.dart';
import 'package:readmate/logic/cubit/edit_book_cubit.dart';
import 'package:readmate/logic/cubit/selected_books_cubit.dart';
import 'package:readmate/resources/open_library_service.dart';
import 'package:readmate/ui/auth_screen/login_screen.dart';
import 'package:readmate/ui/auth_screen/reset_password_screen.dart';
import 'package:readmate/ui/auth_screen/awaiting_email_screen.dart';
import 'package:readmate/ui/auth_screen/user_not_found_screen.dart';
import 'package:readmate/ui/home_screen/home_screen.dart';

import 'package:readmate/resources/api_book_repository.dart';
import 'package:readmate/resources/api_auth_repository.dart';
import 'package:readmate/logic/cubit/auth_cubit.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

late BookCubit bookCubit;
late ChallengeCubit challengeCubit;
late Directory appDocumentsDirectory;
late GlobalKey<ScaffoldMessengerState> snackbarKey;
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
late DateFormat dateFormat;

void main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  
  try {
    final authRepo = ApiAuthRepository();
    await authRepo.init();
    
    final repo = ApiBookRepository();
    final connected = await repo.checkConnection();
    debugPrint("REST API connection status: ${connected ? 'CONNECTED' : 'FAILED'}");
  } catch (e) {
    debugPrint("REST API init error: $e");
  }

  await EasyLocalization.ensureInitialized();
  HydratedBloc.storage = await HydratedStorage.build(
    storageDirectory: HydratedStorageDirectory(
      (await getApplicationDocumentsDirectory()).path,
    ),
  );
  appDocumentsDirectory = await getApplicationDocumentsDirectory();
  snackbarKey = GlobalKey<ScaffoldMessengerState>();
  bookCubit = BookCubit();
  challengeCubit = ChallengeCubit();

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('en', 'US')],
      path: 'assets/translations',
      fallbackLocale: const Locale('en', 'US'),
      startLocale: const Locale('en', 'US'),
      useFallbackTranslations: true,
      child: const App(),
    ),
  );
}

class App extends StatelessWidget {
  const App({super.key});
  _listOfBlocProviders(BuildContext context) {
    return [
      BlocProvider(create: (_) => AuthCubit(RepositoryProvider.of<ApiAuthRepository>(context))),
      BlocProvider(
        lazy: false,
        create: (context) {
          bookCubit.setRepository(RepositoryProvider.of<ApiBookRepository>(context));
          return bookCubit;
        },
      ),
      BlocProvider(create: (_) => EditBookCubit()),
      BlocProvider(create: (_) => EditBookCoverCubit()),
      BlocProvider(create: (_) => CurrentBookCubit()),
      BlocProvider(create: (_) => SelectedBooksCubit()),
      BlocProvider(
        lazy: false,
        create: (context) {
          challengeCubit.setRepository(RepositoryProvider.of<ApiBookRepository>(context));
          return challengeCubit;
        },
      ),
      BlocProvider(create: (_) => BookListsOrderCubit()),
      BlocProvider(create: (_) => ThemeBloc()),
      BlocProvider(create: (_) => DisplayCubit()),
      BlocProvider(create: (_) => RatingTypeBloc()),
      BlocProvider(create: (_) => SortFinishedBooksBloc()),
      BlocProvider(create: (_) => SortInProgressBooksBloc()),
      BlocProvider(create: (_) => SortForLaterBooksBloc()),
      BlocProvider(create: (_) => SortUnfinishedBooksBloc()),
      BlocProvider(create: (_) => OpenLibrarySearchBloc()),
    ];
  }
  _listOfRepositoryProviders(BuildContext context) {
    return [
      RepositoryProvider<ApiAuthRepository>(create: (_) => ApiAuthRepository()),
      RepositoryProvider<ApiBookRepository>(create: (_) => ApiBookRepository()),
      RepositoryProvider<OpenLibraryService>(create: (_) => OpenLibraryService()),
    ];
  }
  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: _listOfRepositoryProviders(context),
      child: Builder(builder: (context) {
        return MultiBlocProvider(
          providers: _listOfBlocProviders(context),
          child: BlocBuilder<ThemeBloc, ThemeState>(
            builder: (_, themeState) {
              if (themeState is SetThemeState) {
                return ReadMateApp(
                  themeState: themeState,
                );
              } else {
                return const SizedBox();
              }
            },
          ),
        );
      }),
    );
  }
}

class ReadMateApp extends StatefulWidget {
  const ReadMateApp({
    super.key,
    required this.themeState,
  });
  final SetThemeState themeState;
  @override
  State<ReadMateApp> createState() => _ReadMateAppState();
}

class _ReadMateAppState extends State<ReadMateApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    _removeSplash();
  }

  Future<void> _removeSplash() async {
    await Future.delayed(const Duration(milliseconds: 800));
    FlutterNativeSplash.remove();
  }

  @override
  Widget build(BuildContext context) {
    _initDateFormat(context);
    AppTheme.init(widget.themeState, context);
    final localizationsDelegates = context.localizationDelegates;
    return DynamicColorBuilder(builder: (lightScheme, darkScheme) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      final themeMode = widget.themeState.themeMode;

      final lightColorScheme = widget.themeState.useMaterialYou
          ? lightScheme ??
              ColorScheme.fromSeed(
                seedColor: widget.themeState.primaryColor,
                brightness: Brightness.light,
              )
          : ColorScheme.fromSeed(
              seedColor: widget.themeState.primaryColor,
              brightness: Brightness.light,
            );

      final lightTheme = ThemeData(
        colorScheme: lightColorScheme,
        brightness: Brightness.light,
        fontFamily: widget.themeState.fontFamily,
      ).copyWith(
        scaffoldBackgroundColor: lightColorScheme.surfaceContainerLowest,
        appBarTheme: AppBarTheme(
          backgroundColor: lightColorScheme.surfaceContainerLowest,
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: lightColorScheme.surfaceContainerLow,
        ),
      );

      final darkColorScheme = widget.themeState.useMaterialYou
          ? darkScheme ??
              ColorScheme.fromSeed(
                seedColor: widget.themeState.primaryColor,
                brightness: Brightness.dark,
                surface: widget.themeState.amoledDark ? Colors.black : null,
              )
          : ColorScheme.fromSeed(
              seedColor: widget.themeState.primaryColor,
              brightness: Brightness.dark,
              surface: widget.themeState.amoledDark ? Colors.black : null,
            );

      final darkTheme = ThemeData(
        colorScheme: darkColorScheme,
        brightness: Brightness.dark,
        fontFamily: widget.themeState.fontFamily,
      ).copyWith(
        scaffoldBackgroundColor: widget.themeState.amoledDark
            ? Colors.black
            : darkColorScheme.surfaceContainerLowest,
        appBarTheme: AppBarTheme(
          backgroundColor: widget.themeState.amoledDark
              ? Colors.black
              : darkColorScheme.surfaceContainerLowest,
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: widget.themeState.amoledDark
              ? Colors.black
              : darkColorScheme.surfaceContainerLow,
        ),
      );
      return AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: Colors.transparent,
          statusBarBrightness: Brightness.light,
          statusBarIconBrightness: Brightness.light,
          systemNavigationBarIconBrightness: Brightness.light,
        ),
        child: BlocBuilder<AuthCubit, AuthCubitState>(
          builder: (context, authState) {
            debugPrint("Current AuthState: $authState");
            return BlocListener<AuthCubit, AuthCubitState>(
              listener: (context, state) {
                if (state is Authenticated && (state.message != null || state.error != null)) {
                  snackbarKey.currentState?.hideCurrentSnackBar();
                  snackbarKey.currentState?.showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          if (state.error != null) const Icon(Icons.error_outline, color: Colors.white),
                          if (state.error != null) const SizedBox(width: 10),
                          Expanded(child: Text(state.error ?? state.message!)),
                        ],
                      ),
                      backgroundColor: state.error != null ? Colors.redAccent : Colors.green,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                } else if (state is Unauthenticated && state.message != null) {
                  snackbarKey.currentState?.hideCurrentSnackBar();
                  snackbarKey.currentState?.showSnackBar(
                    SnackBar(
                      content: Text(state.message!),
                      backgroundColor: state.isEmailUnconfirmed ? Colors.orange.shade800 : Colors.green,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                } else if (state is AuthError) {
                  snackbarKey.currentState?.hideCurrentSnackBar();
                  snackbarKey.currentState?.showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.white),
                          const SizedBox(width: 10),
                          Expanded(child: Text(state.message)),
                        ],
                      ),
                      backgroundColor: Colors.redAccent,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              child: MaterialApp(
                title: Constants.appName,
                debugShowCheckedModeBanner: false,
                navigatorKey: navigatorKey,
                scaffoldMessengerKey: snackbarKey,
                theme: lightTheme,
                darkTheme: darkTheme,
                themeMode: themeMode,
                home: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 600),
                  switchInCurve: Curves.easeIn,
                  switchOutCurve: Curves.easeOut,
                  child: _getHomeWidget(authState),
                ),
                localizationsDelegates: localizationsDelegates,
                supportedLocales: context.supportedLocales,
                locale: context.locale,
              ),
            );
          },
        ),
      );
    });
  }

  Widget _getHomeWidget(AuthCubitState state) {
    if (state is Authenticated) {
      return const HomeScreen(key: ValueKey('home'));
    } else if (state is UserNotFound) {
      return UserNotFoundScreen(
        key: const ValueKey('user_not_found'),
        identifier: state.identifier,
      );
    } else if (state is AwaitingEmailConfirmation) {
      return const AwaitingEmailScreen(key: ValueKey('awaiting_email'));
    } else if (state is PasswordRecovery) {
      return const ResetPasswordScreen(key: ValueKey('reset_password'));
    } else {
      return const LoginScreen(key: ValueKey('login'));
    }
  }
}

Future _initDateFormat(BuildContext context) async {
  await initializeDateFormatting();
  dateFormat = DateFormat.yMMMMd('en_US');
}
