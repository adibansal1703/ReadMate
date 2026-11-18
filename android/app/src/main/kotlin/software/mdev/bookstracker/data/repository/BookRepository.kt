package software.mdev.bookstracker.data.repository

import android.util.Log
import io.ktor.client.request.headers
import io.ktor.client.request.get
import io.ktor.client.request.post
import io.ktor.client.request.setBody
import io.ktor.client.statement.bodyAsText
import io.ktor.http.ContentType
import io.ktor.http.contentType
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonArray
import software.mdev.bookstracker.data.model.Book
import software.mdev.bookstracker.data.network.ApiClient

class BookRepository {
    private val TAG = "API_DEBUG"
    private val jsonParser = Json { ignoreUnknownKeys = true }

    suspend fun insertBook(title: String, author: String, coverUrl: String?): Result<Unit> {
        return try {
            val token = ApiClient.authToken
            if (token == null) {
                Log.e(TAG, "Insert failed: No auth token found.")
                return Result.failure(Exception("User not authenticated"))
            }

            Log.d(TAG, "Inserting book: $title by $author")
            val payload = """
                {
                    "title": "$title",
                    "author": "${author.replace("\"", "\\\"")}",
                    "cover_url": ${if (coverUrl != null) "\"$coverUrl\"" else "null"}
                }
            """.trimIndent()

            val response = ApiClient.httpClient.post("${ApiClient.BASE_URL}/books/upsert") {
                contentType(ContentType.Application.Json)
                headers {
                    append("Authorization", "Bearer $token")
                }
                setBody(payload)
            }

            if (response.status.value in 200..299) {
                Log.d(TAG, "Insert SUCCESS: $title")
                Result.success(Unit)
            } else {
                val errBody = response.bodyAsText()
                Log.e(TAG, "Insert ERROR: $errBody")
                Result.failure(Exception("Failed to insert book: $errBody"))
            }
        } catch (e: Exception) {
            Log.e(TAG, "Insert ERROR: ${e.message}", e)
            Result.failure(e)
        }
    }

    suspend fun fetchUserBooks(): List<Book> {
        return try {
            val token = ApiClient.authToken
            if (token == null) {
                Log.e(TAG, "Fetch failed: No auth token found.")
                return emptyList()
            }

            val response = ApiClient.httpClient.get("${ApiClient.BASE_URL}/books") {
                headers {
                    append("Authorization", "Bearer $token")
                }
            }

            if (response.status.value == 200) {
                val responseBody = response.bodyAsText()
                val json = jsonParser.parseToJsonElement(responseBody).jsonObject
                val booksArray = json["books"]?.jsonArray ?: return emptyList()

                val books = booksArray.map { element ->
                    jsonParser.decodeFromJsonElement(Book.serializer(), element)
                }

                Log.d(TAG, "Fetch SUCCESS: Found ${books.size} books.")
                books
            } else {
                Log.e(TAG, "Fetch ERROR status: ${response.status.value}")
                emptyList()
            }
        } catch (e: Exception) {
            Log.e(TAG, "Fetch ERROR: ${e.message}", e)
            emptyList()
        }
    }
}
