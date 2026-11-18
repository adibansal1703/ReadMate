import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:readmate/model/book.dart';
import 'package:readmate/model/book_history.dart';
import 'package:readmate/resources/api_book_repository.dart';

class BookHistorySheet extends StatefulWidget {
  final Book book;

  const BookHistorySheet({
    super.key,
    required this.book,
  });

  static void show(BuildContext context, Book book) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => BookHistorySheet(book: book),
    );
  }

  @override
  State<BookHistorySheet> createState() => _BookHistorySheetState();
}

class _BookHistorySheetState extends State<BookHistorySheet> {
  final ApiBookRepository _repository = ApiBookRepository();
  final TextEditingController _noteController = TextEditingController();
  late Future<List<BookHistory>> _historyFuture;
  bool _isAddingNote = false;
  bool _isSavingNote = false;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  void _loadHistory() {
    if (widget.book.id != null) {
      setState(() {
        _historyFuture = _repository.getBookHistory(widget.book.id!);
      });
    } else {
      _historyFuture = Future.value([]);
    }
  }

  Future<void> _submitNote() async {
    final noteText = _noteController.text.trim();
    if (noteText.isEmpty) return;

    if (noteText.length > 5000) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Note cannot exceed 5000 characters.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isSavingNote = true;
    });

    final success = await _repository.addBookNote(widget.book.id!, noteText);

    if (mounted) {
      setState(() {
        _isSavingNote = false;
      });

      if (success) {
        _noteController.clear();
        setState(() {
          _isAddingNote = false;
        });
        _loadHistory();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Note added to history report!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save note.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: mediaQuery.viewInsets.bottom,
            left: 20,
            right: 20,
            top: 16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'History Check & Report',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          widget.book.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(_isAddingNote ? Icons.close : Icons.note_add_outlined),
                    tooltip: 'Add Note',
                    onPressed: () {
                      setState(() {
                        _isAddingNote = !_isAddingNote;
                      });
                    },
                  ),
                ],
              ),
              const Divider(height: 20),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_isAddingNote) ...[
                        _buildAddNoteSection(),
                        const SizedBox(height: 16),
                      ],
                      FutureBuilder<List<BookHistory>>(
                        future: _historyFuture,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Padding(
                              padding: EdgeInsets.all(30.0),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }

                          if (snapshot.hasError) {
                            return Center(
                              child: Text(
                                'Error loading history: ${snapshot.error}',
                                style: const TextStyle(color: Colors.red),
                              ),
                            );
                          }

                          final historyList = snapshot.data ?? [];

                          if (historyList.isEmpty) {
                            return Padding(
                              padding: const EdgeInsets.all(30.0),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.history,
                                    size: 64,
                                    color: Colors.grey.withOpacity(0.5),
                                  ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'No history logs recorded yet.',
                                    style: TextStyle(fontSize: 16, color: Colors.grey),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Activity such as adding the book, updating progress, and adding notes will appear here.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 13, color: Colors.grey),
                                  ),
                                ],
                              ),
                            );
                          }

                          return ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: historyList.length,
                            itemBuilder: (context, index) {
                              final item = historyList[index];
                              final isLast = index == historyList.length - 1;
                              return _buildTimelineItem(item, isLast);
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAddNoteSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Add Note (Max 5,000 chars)',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _noteController,
            maxLines: 4,
            maxLength: 5000,
            decoration: const InputDecoration(
              hintText: 'Type your detailed notes here...',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.all(10),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: _isSavingNote || _noteController.text.trim().isEmpty ? null : _submitNote,
              icon: _isSavingNote
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send, size: 18),
              label: const Text('Save Note'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineItem(BookHistory item, bool isLast) {
    IconData icon;
    Color color;

    switch (item.eventType) {
      case 'added':
        icon = Icons.add_circle_outline;
        color = Colors.green;
        break;
      case 'page_updated':
        icon = Icons.menu_book;
        color = Colors.blue;
        break;
      case 'notes_updated':
      case 'note_added':
        icon = Icons.edit_note;
        color = Colors.orange;
        break;
      case 'finished':
        icon = Icons.emoji_events;
        color = Colors.amber;
        break;
      case 'status_changed':
      default:
        icon = Icons.swap_horiz;
        color = Colors.purple;
        break;
    }

    final formattedDate = DateFormat('dd MMM yyyy, hh:mm a').format(item.createdAt);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: Colors.grey.withOpacity(0.3),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          item.description ?? item.eventType.replaceAll('_', ' ').toUpperCase(),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        formattedDate,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  if (item.pageNumber != null && item.pageNumber! > 0) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Page: ${item.pageNumber}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                  if (item.noteContent != null && item.noteContent!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        item.noteContent!,
                        style: const TextStyle(fontSize: 13, height: 1.4),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
