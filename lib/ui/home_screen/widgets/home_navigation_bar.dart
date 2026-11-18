import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:readmate/generated/locale_keys.g.dart';

class HomeNavigationBar extends StatefulWidget {
  const HomeNavigationBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final Function(int) onTap;

  @override
  State<HomeNavigationBar> createState() => _HomeNavigationBarState();
}

class _HomeNavigationBarState extends State<HomeNavigationBar> {

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      onDestinationSelected: (int index) {
        widget.onTap(index);
      },
      indicatorColor: Theme.of(context).colorScheme.primaryContainer,
      selectedIndex: widget.currentIndex,
      destinations: <Widget>[
        NavigationDestination(
          icon: FaIcon(
            FontAwesomeIcons.bars,
            color: widget.currentIndex == 0
                ? Theme.of(context).colorScheme.onPrimaryContainer
                : Theme.of(context).colorScheme.onSurface,
          ),
          label: LocaleKeys.books_settings.tr(),
        ),
        NavigationDestination(
          icon: FaIcon(
            FontAwesomeIcons.chartSimple,
            color: widget.currentIndex == 1
                ? Theme.of(context).colorScheme.onPrimaryContainer
                : Theme.of(context).colorScheme.onSurface,
          ),
          label: LocaleKeys.statistics.tr(),
        ),
      ],
    );
  }
}
