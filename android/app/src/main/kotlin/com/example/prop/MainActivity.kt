package com.example.prob

import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Xml
import android.view.ViewGroup
import io.flutter.embedding.android.FlutterActivity
import org.xmlpull.v1.XmlPullParser

class MainActivity : FlutterActivity() {

    private var splashOverlay: NativeSplashOverlay? = null
    private var isAnimationFinished = false
    private var isFlutterFirstFrameReady = false
    private var isDismissed = false

    private val safetyHandler = Handler(Looper.getMainLooper())
    private val safetyTimeoutRunnable = Runnable {
        forceDismissSplash()
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val appLogoSvgPaths = loadSvgPathsFromAssets("logo.svg")

        val overlay = NativeSplashOverlay(
            context = this,
            svgPathsData = appLogoSvgPaths,
            onAnimationComplete = {
                isAnimationFinished = true
                tryDismissSplash()
            }
        )

        splashOverlay = overlay
        val decorView = window.decorView as ViewGroup
        decorView.addView(
            overlay,
            ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
            )
        )


        // مؤقت أمان أقصى (10 ثوانٍ) متوافق مع التوقيت السريع الجديد
        safetyHandler.postDelayed(safetyTimeoutRunnable, 10000L)
    }

    override fun onFlutterUiDisplayed() {
        super.onFlutterUiDisplayed()
        isFlutterFirstFrameReady = true
        tryDismissSplash()
    }

    private fun tryDismissSplash() {
        if (isAnimationFinished && isFlutterFirstFrameReady) {
            forceDismissSplash()
        }
    }

    private fun forceDismissSplash() {
        if (isDismissed) return
        isDismissed = true
        safetyHandler.removeCallbacks(safetyTimeoutRunnable)

        splashOverlay?.fadeOutAndDestroy {
            splashOverlay = null
        }
    }

    private fun loadSvgPathsFromAssets(fileName: String): List<String> {
        val paths = mutableListOf<String>()
        try {
            assets.open(fileName).use { inputStream ->
                val parser = Xml.newPullParser().apply {
                    setFeature(XmlPullParser.FEATURE_PROCESS_NAMESPACES, false)
                    setInput(inputStream, "UTF-8")
                }

                var eventType = parser.eventType
                while (eventType != XmlPullParser.END_DOCUMENT) {
                    if (eventType == XmlPullParser.START_TAG && parser.name == "path") {
                        parser.getAttributeValue(null, "d")
                            ?.trim()
                            ?.takeIf { it.isNotEmpty() }
                            ?.let { paths.add(it) }
                    }
                    eventType = parser.next()
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
        return paths
    }

    override fun onDestroy() {
        safetyHandler.removeCallbacks(safetyTimeoutRunnable)
        super.onDestroy()
    }
}