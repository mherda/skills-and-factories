package {{APPLICATION_ID}}

import android.content.Intent
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.v2.createEmptyComposeRule
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.test.core.app.ActivityScenario
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/**
 * Acceptance criteria that need a tap ("tap X, then Y happens") are proven
 * here, on the job's emulator: a screenshot can't show what a tap does, and a
 * UI test repeats every review round.
 */
@RunWith(AndroidJUnit4::class)
class FlowTest {
    @get:Rule
    val compose = createEmptyComposeRule()

    /** Launches with `factoryNoPrompts`, so permission dialogs don't block taps. */
    private fun launch(screen: String? = null): ActivityScenario<MainActivity> {
        val intent = Intent(ApplicationProvider.getApplicationContext(), MainActivity::class.java)
            .putExtra("factoryNoPrompts", true)
        if (screen != null) intent.putExtra("factoryScreen", screen)
        return ActivityScenario.launch(intent)
    }

    @Test
    fun settingsOpensAndCloses() {
        launch().use {
            compose.onNodeWithContentDescription("Settings").performClick()
            compose.onNodeWithText("Version").assertIsDisplayed()
            compose.onNodeWithContentDescription("Back").performClick()
            compose.onNodeWithText("Nothing here yet.").assertIsDisplayed()
        }
    }
}
