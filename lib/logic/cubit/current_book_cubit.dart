import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:readmate/model/book.dart';

class CurrentBookCubit extends Cubit<Book> {
  CurrentBookCubit() : super(Book.empty());

  setBook(Book book) => emit(book);
}
