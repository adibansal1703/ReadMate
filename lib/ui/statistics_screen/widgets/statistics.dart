import 'dart:math';
import 'package:confetti/confetti.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:readmate/generated/locale_keys.g.dart';
import 'package:readmate/logic/bloc/stats_bloc/stats_bloc.dart';
import 'package:readmate/logic/cubit/challenge_cubit.dart';
import 'package:readmate/ui/statistics_screen/widgets/widgets.dart';

class Statistics extends StatefulWidget {
  final StatsLoaded state;

  const Statistics({
    super.key,
    required this.state,
  });

  @override
  State<Statistics> createState() => _StatisticsState();
}

class _StatisticsState extends State<Statistics> {
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  int _getBooksFinishedThisYear() {
    final currentYear = DateTime.now().year;
    int booksThisYear = 0;
    for (var book in widget.state.finishedBooks) {
      bool countedForChallenge = false;
      
      for (var reading in book.readings) {
        if (reading.startDate != null && 
            reading.finishDate != null && 
            reading.finishDate!.year == currentYear) {
          countedForChallenge = true;
          break;
        }
      }
      
      if (countedForChallenge) booksThisYear++;
    }
    return booksThisYear;
  }

  @override
  Widget build(BuildContext context) {
    final totalBooks = widget.state.finishedBooksAll + 
                      widget.state.inProgressBooks.length + 
                      widget.state.forLaterBooks.length + 
                      widget.state.unfinishedBooks.length;

    if (totalBooks == 0) {
      return _buildEmptyState(context);
    }

    return Stack(
      children: [
        SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _buildYearlyChallenge(context),
                const SizedBox(height: 20),
                ReadStats(
                  title: LocaleKeys.finished_books.tr(),
                  value: widget.state.finishedBooksAll.toString(),
                ),
                const SizedBox(height: 10),
                ReadStats(
                  title: LocaleKeys.finished_pages.tr(),
                  value: widget.state.finishedPagesAll.toString(),
                ),
                const SizedBox(height: 10),
                ReadStats(
                  title: LocaleKeys.avg_books_per_month.tr(),
                  value: widget.state.avgBooksPerMonth.toStringAsFixed(1),
                ),
                const SizedBox(height: 10),
                ReadStats(
                  title: LocaleKeys.avg_pages_per_day.tr(),
                  value: widget.state.avgPagesPerDay.toStringAsFixed(1),
                ),
                const SizedBox(height: 10),
                ReadStats(
                  title: LocaleKeys.avg_rating.tr(),
                  value: widget.state.avgRating > 0
                      ? "${widget.state.avgRating.toStringAsFixed(1)} ★"
                      : "N/A",
                  secondValue: widget.state.ratedBooksCount > 0
                      ? "Based on ${widget.state.ratedBooksCount} rated ${widget.state.ratedBooksCount == 1 ? 'book' : 'books'}"
                      : "No rated books yet",
                  iconData: Icons.star_rounded,
                ),
                const SizedBox(height: 20),
                MonthlyBarChart(
                  monthlyStats: widget.state.monthlyStats,
                ),
              ],
            ),
          ),
        ),
        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: _confettiController,
            blastDirectionality: BlastDirectionality.explosive,
            shouldLoop: false,
            colors: const [Colors.green, Colors.blue, Colors.pink, Colors.orange, Colors.purple],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.auto_stories_outlined,
              size: 80,
              color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
            ),
            const SizedBox(height: 20),
            Text(
              "No books added yet",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              "Start your journey by setting a goal for this year!",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              onPressed: () => _showSetGoalDialog(context, context.read<ChallengeCubit>().state),
              icon: const Icon(Icons.add_task, size: 24),
              label: const Text(
                "Start a new reading challenge",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildYearlyChallenge(BuildContext context) {
    return BlocConsumer<ChallengeCubit, int>(
      listener: (context, goal) {
        if (goal > 0 && _getBooksFinishedThisYear() >= goal) {
          _confettiController.play();
        }
      },
      builder: (context, goal) {
        final currentYear = DateTime.now().year;
        final booksThisYear = _getBooksFinishedThisYear();
        final isFinished = goal > 0 && booksThisYear >= goal;

        return InkWell(
          onTap: () {
            if (goal > 0) {
              if (isFinished) {
                _showSuccessDialog(context);
              } else {
                _showSadEmojiDialog(context);
              }
            } else {
              _showSetGoalDialog(context, goal);
            }
          },
          child: Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: isFinished 
                  ? Colors.green.withOpacity(0.2)
                  : Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
              borderRadius: BorderRadius.circular(15),
              border: isFinished ? Border.all(color: Colors.green, width: 2) : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "$currentYear ${LocaleKeys.books_challenge.tr()}",
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    if (isFinished) 
                      const Icon(Icons.stars, color: Colors.orange)
                    else
                      const Icon(Icons.edit, size: 16),
                  ],
                ),
                const SizedBox(height: 10),
                if (goal > 0) ...[
                  LinearProgressIndicator(
                    value: (booksThisYear / goal).clamp(0.0, 1.0),
                    borderRadius: BorderRadius.circular(10),
                    minHeight: 10,
                    backgroundColor: Colors.grey.withOpacity(0.2),
                    valueColor: AlwaysStoppedAnimation<Color>(isFinished ? Colors.green : Theme.of(context).primaryColor),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("$booksThisYear / $goal ${LocaleKeys.books_settings.tr()}"),
                      if (!isFinished) 
                        const Text("Keep going! 📚", style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
                    ],
                  ),
                ] else
                  Text(LocaleKeys.click_here_to_set_challenge.tr()),
              ],
            ),
          ),
        );
      },
    );
  }



  void _showSadEmojiDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("😢", style: TextStyle(fontSize: 60)),
            const SizedBox(height: 20),
            const Text(
              "Keep pushing!",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
            const SizedBox(height: 10),
            const Text(
              "You haven't reached your yearly goal yet. Every page counts!",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showSetGoalDialog(context, context.read<ChallengeCubit>().state);
            },
            child: const Text("Adjust Goal"),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("I'll do it!"),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog(BuildContext context) {
    _confettiController.play();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("🎉", style: TextStyle(fontSize: 60)),
            const SizedBox(height: 20),
            const Text(
              "Amazing Job!",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
            const SizedBox(height: 10),
            const Text(
              "You've officially completed your reading challenge for this year!",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
        actions: [
          Center(
            child: FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Celebrate!"),
            ),
          ),
        ],
      ),
    );
  }

  void _showSetGoalDialog(BuildContext context, int currentGoal) {
    final controller = TextEditingController(text: currentGoal > 0 ? currentGoal.toString() : "");
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(LocaleKeys.books_challenge.tr()),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(hintText: LocaleKeys.books_settings.tr()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              final newGoal = int.tryParse(controller.text) ?? 0;
              context.read<ChallengeCubit>().setGoal(newGoal);
              Navigator.pop(context);
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }
}
