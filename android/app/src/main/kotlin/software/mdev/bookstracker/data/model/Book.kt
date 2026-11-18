package software.mdev.bookstracker.data.model

import kotlinx.serialization.Serializable
import kotlinx.serialization.SerialName

@Serializable
data class Book(
    @SerialName("id")
    val id: String? = null,
    @SerialName("user_id")
    val userId: String,
    @SerialName("title")
    val title: String,
    @SerialName("author")
    val author: String? = null,
    @SerialName("cover_url")
    val coverUrl: String? = null,
    @SerialName("created_at")
    val createdAt: String? = null
)
