package software.mdev.bookstracker.ui.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import software.mdev.bookstracker.data.model.Book
import software.mdev.bookstracker.data.repository.BookRepository

class BookViewModel : ViewModel() {
    private val repository = BookRepository()
    
    private val _books = MutableStateFlow<List<Book>>(emptyList())
    val books: StateFlow<List<Book>> = _books.asStateFlow()

    private val _isLoading = MutableStateFlow(false)
    val isLoading: StateFlow<Boolean> = _isLoading.asStateFlow()

    fun loadBooks() {
        viewModelScope.launch {
            _isLoading.value = true
            _books.value = repository.fetchUserBooks()
            _isLoading.value = false
        }
    }

    fun addBook(title: String, author: String, coverUrl: String?) {
        viewModelScope.launch {
            val result = repository.insertBook(title, author, coverUrl)
            if (result.isSuccess) {
                loadBooks() // Refresh list after success
            }
        }
    }
}
