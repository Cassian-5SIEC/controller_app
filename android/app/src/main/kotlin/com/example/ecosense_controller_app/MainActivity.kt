package fr.chourret.ecosense_controller_app

import android.os.Bundle // <--- THIS WAS MISSING
import io.flutter.embedding.android.FlutterActivity
import org.freedesktop.gstreamer.GStreamer
import java.lang.Exception

class MainActivity: FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        try {
            // Initialize GStreamer Env
            System.setProperty("gst.debug", "3")   // Preferred on Android GStreamer
            System.setProperty("GST_DEBUG", "3")   // Fallback, some builds use this

            // Optional: dump pipeline graphs (very useful)
            System.setProperty("GST_DEBUG_DUMP_DOT_DIR", filesDir.absolutePath)

            // Initialize GStreamer
            GStreamer.init(this)
        } catch (e: Exception) {
            // Helps debug if GStreamer fails to load (common issue)
            e.printStackTrace()
        }
    }
}