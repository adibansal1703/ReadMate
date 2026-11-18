enum BookStatus {
  read,
  inProgress,
  forLater,
  unfinished,
}

extension BookStatusExtension on BookStatus {
  int get value {
    switch (this) {
      case BookStatus.read:
        return 0;
      case BookStatus.inProgress:
        return 1;
      case BookStatus.forLater:
        return 2;
      case BookStatus.unfinished:
        return 3;
    }
  }
}

BookStatus parseBookStatus(dynamic value) {
  final stringVal = value?.toString().toLowerCase();
  switch (stringVal) {
    case '0':
    case 'read':
      return BookStatus.read;
    case '1':
    case 'inprogress':
    case 'in_progress':
      return BookStatus.inProgress;
    case '2':
    case 'forlater':
    case 'for_later':
      return BookStatus.forLater;
    case '3':
    case 'unfinished':
      return BookStatus.unfinished;
    default:
      return BookStatus.read;
  }
}
