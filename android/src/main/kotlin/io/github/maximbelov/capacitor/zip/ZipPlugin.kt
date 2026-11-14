package io.github.maximbelov.capacitor.zip

import com.getcapacitor.JSObject
import com.getcapacitor.Plugin
import com.getcapacitor.PluginCall
import com.getcapacitor.PluginMethod
import com.getcapacitor.annotation.CapacitorPlugin
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

@CapacitorPlugin(name = "Zip")
class ZipPlugin : Plugin() {
    // Off the plugin thread, so a large archive does not hold up every other plugin call
    private val executor: ExecutorService = Executors.newCachedThreadPool()

    @PluginMethod
    fun unzip(call: PluginCall) {
        val destinationArg = call.getString("destination")
        val overwrite = call.getBoolean("overwrite", true) ?: true
        val source = try {
            Unzipper.resolvePath(call.getString("source"), "source")
        } catch (e: UnzipException) {
            call.reject(e.message, e.code)
            return
        }
        val destination = try {
            Unzipper.resolvePath(destinationArg, "destination")
        } catch (e: UnzipException) {
            call.reject(e.message, e.code)
            return
        }
        executor.execute {
            try {
                val count = Unzipper.unzip(source, destination, overwrite) { loaded, total ->
                    notifyListeners(
                        "progress",
                        JSObject().apply {
                            put("destination", destinationArg)
                            put("loaded", loaded)
                            put("total", total)
                        },
                    )
                }
                call.resolve(JSObject().apply { put("entries", count) })
            } catch (e: UnzipException) {
                call.reject(e.message, e.code, e)
            } catch (e: Exception) {
                call.reject("Could not unzip ${source.path}", "IO", e)
            }
        }
    }

    override fun handleOnDestroy() {
        executor.shutdown()
        super.handleOnDestroy()
    }
}
