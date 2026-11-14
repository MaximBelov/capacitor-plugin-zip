package io.github.maximbelov.capacitor.zip

import java.io.File
import java.io.IOException
import java.net.URI
import java.net.URISyntaxException
import java.util.zip.ZipException
import java.util.zip.ZipFile

/** A failed unzip, with the code the JavaScript side receives. */
class UnzipException(val code: String, message: String, cause: Throwable? = null) : Exception(message, cause)

/** Extracts a zip archive with java.util.zip. Knows nothing of Capacitor, so it runs in a plain JVM test. */
object Unzipper {
    private const val BUFFER_SIZE = 32 * 1024

    /** An absolute path or a `file://` URL as a File; anything else is refused. */
    fun resolvePath(value: String?, name: String): File {
        if (value.isNullOrEmpty()) {
            throw UnzipException("INVALID_ARGUMENT", "$name is required")
        }
        if (value.startsWith("file:")) {
            val uri = try {
                URI(value)
            } catch (e: URISyntaxException) {
                throw UnzipException("INVALID_ARGUMENT", "$name is not a valid file URL: $value", e)
            }
            val path = uri.path
            if (path.isNullOrEmpty()) {
                throw UnzipException("INVALID_ARGUMENT", "$name is not a valid file URL: $value")
            }
            return File(path)
        }
        if (value.contains("://")) {
            throw UnzipException("INVALID_ARGUMENT", "$name must be a path or a file:// URL: $value")
        }
        if (!value.startsWith("/")) {
            throw UnzipException("INVALID_ARGUMENT", "$name must be an absolute path: $value")
        }
        return File(value)
    }

    /** True when an entry name would leave the destination: an absolute path, or a `..` segment anywhere. */
    fun isUnsafeEntryName(name: String): Boolean {
        val normalised = name.replace('\\', '/')
        if (normalised.startsWith("/")) {
            return true
        }
        return normalised.split('/').any { it == ".." }
    }

    /**
     * Extracts [source] into [destination] and returns how many entries it extracted. [onProgress] is called with
     * (extracted, total) after each entry. Every entry name is checked before anything is written.
     */
    fun unzip(source: File, destination: File, overwrite: Boolean = true, onProgress: (Int, Int) -> Unit = { _, _ -> }): Int {
        if (!source.isFile) {
            throw UnzipException("NOT_FOUND", "No zip file at ${source.path}")
        }
        val zip = try {
            ZipFile(source)
        } catch (e: ZipException) {
            // Android 14 refuses an archive with a `..` or absolute entry name when it opens it
            if (e.message?.contains("Invalid zip entry path") == true) {
                throw UnzipException("UNSAFE_ENTRY", "The archive has an entry outside the destination", e)
            }
            throw UnzipException("BAD_ARCHIVE", "Not a zip archive: ${source.path}", e)
        } catch (e: IOException) {
            throw UnzipException("IO", "Could not read ${source.path}", e)
        }
        zip.use {
            val entries = zip.entries().toList()
            if (entries.isEmpty()) {
                throw UnzipException("BAD_ARCHIVE", "The archive is empty: ${source.path}")
            }
            if (!destination.isDirectory && !destination.mkdirs()) {
                throw UnzipException("IO", "Could not create ${destination.path}")
            }
            val root = destination.canonicalFile
            val targets = entries.map { entry ->
                val target = File(root, entry.name).canonicalFile
                if (isUnsafeEntryName(entry.name) || !target.path.startsWith(root.path + File.separator)) {
                    throw UnzipException("UNSAFE_ENTRY", "The entry ${entry.name} would be written outside the destination")
                }
                target
            }
            val buffer = ByteArray(BUFFER_SIZE)
            entries.forEachIndexed { index, entry ->
                val target = targets[index]
                try {
                    if (entry.isDirectory) {
                        if (!target.isDirectory && !target.mkdirs()) {
                            throw UnzipException("IO", "Could not create ${target.path}")
                        }
                    } else {
                        val parent = target.parentFile
                        if (parent != null && !parent.isDirectory && !parent.mkdirs()) {
                            throw UnzipException("IO", "Could not create ${parent.path}")
                        }
                        if (target.exists() && !overwrite) {
                            throw UnzipException("EXISTS", "${target.path} already exists")
                        }
                        zip.getInputStream(entry).use { input ->
                            target.outputStream().use { output ->
                                while (true) {
                                    val count = input.read(buffer)
                                    if (count < 0) break
                                    output.write(buffer, 0, count)
                                }
                            }
                        }
                    }
                } catch (e: UnzipException) {
                    throw e
                } catch (e: ZipException) {
                    throw UnzipException("BAD_ARCHIVE", "The entry ${entry.name} is corrupt", e)
                } catch (e: IOException) {
                    throw UnzipException("IO", "Could not write ${target.path}", e)
                }
                onProgress(index + 1, entries.size)
            }
            return entries.size
        }
    }
}
