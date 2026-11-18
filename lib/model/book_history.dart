class BookHistory {
  final int id;
  final int bookId;
  final String userId;
  final String eventType;
  final String? description;
  final int? pageNumber;
  final String? noteContent;
  final DateTime createdAt;

  BookHistory({
    required this.id,
    required this.bookId,
    required this.userId,
    required this.eventType,
    this.description,
    this.pageNumber,
    this.noteContent,
    required this.createdAt,
  });

  factory BookHistory.fromJSON(Map<String, dynamic> json) {
    return BookHistory(
      id: json['id'] is int ? json['id'] as int : int.parse(json['id'].toString()),
      bookId: json['book_id'] is int ? json['book_id'] as int : int.parse(json['book_id'].toString()),
      userId: json['user_id'] as String,
      eventType: json['event_type'] as String? ?? 'event',
      description: json['description'] as String?,
      pageNumber: json['page_number'] != null ? int.tryParse(json['page_number'].toString()) : null,
      noteContent: json['note_content'] as String?,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'].toString()) : DateTime.now(),
    );
  }
}
