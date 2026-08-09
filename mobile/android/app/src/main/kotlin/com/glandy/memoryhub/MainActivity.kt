package com.glandy.memoryhub

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.net.HttpURLConnection
import java.net.URL
import java.security.MessageDigest

class MainActivity : FlutterActivity() {
    private val updateChannel = "com.glandy.memoryhub/update"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, updateChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "currentBuildNumber" -> result.success(currentBuildNumber())
                    "downloadAndInstall" -> {
                        val url = call.argument<String>("url")
                        val sha256 = call.argument<String>("sha256")
                        if (url == null || sha256 == null) {
                            result.error("invalid_update", "更新参数不完整", null)
                        } else {
                            downloadAndInstall(url, sha256, result)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    @Suppress("DEPRECATION")
    private fun currentBuildNumber(): Int {
        val info = packageManager.getPackageInfo(packageName, 0)
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            info.longVersionCode.toInt()
        } else {
            info.versionCode
        }
    }

    private fun downloadAndInstall(
        rawUrl: String,
        expectedSha256: String,
        result: MethodChannel.Result,
    ) {
        val uri = Uri.parse(rawUrl)
        val validSource = uri.scheme == "https" &&
            uri.host == "github.com" &&
            uri.path.orEmpty().startsWith(
                "/Glandy-T/memory-hub-ios/releases/download/",
            )
        if (!validSource || !expectedSha256.matches(Regex("^[0-9A-Fa-f]{64}$"))) {
            result.error("invalid_update", "更新来源或校验值无效", null)
            return
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            !packageManager.canRequestPackageInstalls()
        ) {
            startActivity(
                Intent(
                    Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                    Uri.parse("package:$packageName"),
                ),
            )
            result.success("permissionRequired")
            return
        }

        Thread {
            val updateDirectory = File(cacheDir, "updates")
            val temporary = File(updateDirectory, "memory-hub-update.apk.part")
            val verified = File(updateDirectory, "memory-hub-update.apk")
            try {
                updateDirectory.mkdirs()
                temporary.delete()
                verified.delete()
                val connection = (URL(rawUrl).openConnection() as HttpURLConnection).apply {
                    connectTimeout = 15_000
                    readTimeout = 30_000
                    instanceFollowRedirects = true
                    setRequestProperty("User-Agent", "MemoryHubAndroidUpdater/1.0")
                }
                try {
                    connection.connect()
                    if (connection.responseCode !in 200..299) {
                        throw IllegalStateException("下载服务器返回 ${connection.responseCode}")
                    }
                    val declaredLength = connection.contentLengthLong
                    if (declaredLength > maximumUpdateBytes) {
                        throw IllegalStateException("更新包异常过大")
                    }
                    val digest = MessageDigest.getInstance("SHA-256")
                    var total = 0L
                    connection.inputStream.use { input ->
                        temporary.outputStream().buffered().use { output ->
                            val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
                            while (true) {
                                val count = input.read(buffer)
                                if (count < 0) break
                                total += count
                                if (total > maximumUpdateBytes) {
                                    throw IllegalStateException("更新包异常过大")
                                }
                                digest.update(buffer, 0, count)
                                output.write(buffer, 0, count)
                            }
                        }
                    }
                    val actual = digest.digest().joinToString("") { "%02X".format(it) }
                    if (!actual.equals(expectedSha256, ignoreCase = true)) {
                        throw IllegalStateException("更新包校验失败，已停止安装")
                    }
                    if (!temporary.renameTo(verified)) {
                        throw IllegalStateException("更新包无法安全保存")
                    }
                } finally {
                    connection.disconnect()
                }
                runOnUiThread {
                    val contentUri = FileProvider.getUriForFile(
                        this,
                        "$packageName.update-provider",
                        verified,
                    )
                    val installer = Intent(Intent.ACTION_VIEW).apply {
                        setDataAndType(contentUri, "application/vnd.android.package-archive")
                        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    startActivity(installer)
                    result.success("installerOpened")
                }
            } catch (error: Exception) {
                temporary.delete()
                verified.delete()
                runOnUiThread {
                    result.error(
                        "update_failed",
                        error.message ?: "更新下载或校验失败",
                        null,
                    )
                }
            }
        }.start()
    }

    companion object {
        private const val maximumUpdateBytes = 150L * 1024L * 1024L
    }
}
