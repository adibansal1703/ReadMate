package software.mdev.bookstracker.data.network

import io.ktor.client.HttpClient
import io.ktor.client.engine.android.Android

object ApiClient {
    const val BASE_URL = "http://10.0.2.2:3000/api"
    var authToken: String? = null

    val httpClient = HttpClient(Android)
}
