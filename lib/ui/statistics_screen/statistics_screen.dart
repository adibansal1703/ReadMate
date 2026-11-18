import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:readmate/logic/bloc/stats_bloc/stats_bloc.dart';
import 'package:readmate/logic/bloc/theme_bloc/theme_bloc.dart';
import 'package:readmate/main.dart';
import 'package:readmate/model/book.dart';

import 'package:readmate/ui/statistics_screen/widgets/statistics.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  late FocusNode _focusNode;

  @override
  void initState() {
    _focusNode = FocusNode();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ThemeBloc, ThemeState>(
      builder: (context, state) {
        if (state is SetThemeState) {
          return Padding(
            padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
            child: StreamBuilder<List<Book>>(
                stream: bookCubit.allBooks,
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    return BlocProvider(
                      create: (context) =>
                          StatsBloc()..add(StatsLoad(snapshot.data!)),
                      child: SelectableRegion(
                        selectionControls: materialTextSelectionControls,
                        focusNode: _focusNode,
                        child: BlocBuilder<StatsBloc, StatsState>(
                          builder: (context, state) {
                            if (state is StatsLoaded) {
                              return Statistics(
                                state: state,
                              );
                            } else if (state is StatsError) {
                              return Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(50),
                                  child: Text(
                                    state.msg,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                                ),
                              );
                            } else {
                              return Center(
                                child: LoadingAnimationWidget.fourRotatingDots(
                                  color: Theme.of(context).primaryColor,
                                  size: 42,
                                ),
                              );
                            }
                          },
                        ),
                      ),
                    );
                  } else {
                    return const SizedBox();
                  }
                }),
          );
        } else {
          return const SizedBox();
        }
      },
    );
  }
}
