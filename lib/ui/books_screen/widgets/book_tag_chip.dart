import 'package:flutter/material.dart';

class BooksTabChip extends StatefulWidget {
  const BooksTabChip({
    super.key,
    required this.index,
    required this.tabController,
    required this.title,
  });

  final int index;
  final TabController tabController;
  final String title;

  @override
  State<BooksTabChip> createState() => _BookTabChipState();
}

class _BookTabChipState extends State<BooksTabChip> {
  _scrollToChip(int index, BuildContext context) {
    Scrollable.ensureVisible(
      context,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  void initState() {
    super.initState();
    widget.tabController.addListener(() {
      if (widget.index == widget.tabController.index) {
        _scrollToChip(widget.index, context);
      }
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 0, 0),
      child: Builder(
        builder: (context) {
          final isSelected = widget.tabController.index == widget.index;

          return FilterChip(
            selectedColor: Theme.of(context).colorScheme.primaryContainer,
            selected: isSelected,
            label: Text(
              widget.title,
              style: TextStyle(
                color: isSelected
                    ? Theme.of(context).colorScheme.onPrimaryContainer
                    : null,
              ),
            ),
            showCheckmark: false,
            onSelected: (bool _) {
              _scrollToChip(widget.index, context);
              widget.tabController.animateTo(
                widget.index,
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeInOutCubic,
              );
            },
          );
        },
      ),
    );
  }
}
