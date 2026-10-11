package {{APPLICATION_ID}}

import android.graphics.Bitmap
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.services.storage.TestStorage

/**
 * Screenshots from UI tests, for screens only reachable by taps. A test class
 * named in UI_TEST_SCREENS (factory/config.sh) calls `FactoryShots.save("name")`
 * after `compose.waitForIdle()`; droid.sh copies the PNGs into the round's shots.
 */
object FactoryShots {
    fun save(name: String) {
        val bitmap = InstrumentationRegistry.getInstrumentation().uiAutomation.takeScreenshot()
        TestStorage().openOutputFile("$name.png").use { bitmap.compress(Bitmap.CompressFormat.PNG, 100, it) }
    }
}
