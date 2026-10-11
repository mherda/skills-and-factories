package {{APPLICATION_ID}}.ui

import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import {{APPLICATION_ID}}.FactoryLaunch

/**
 * Which screen is showing. `factoryScreen` (debug builds only) opens a screen
 * directly: add a case for every screen worth a screenshot, and list it in
 * CLAUDE.md (Screens) and factory/config.sh (SCREENS).
 */
@Composable
fun AppRoot() {
    var showSettings by rememberSaveable { mutableStateOf(FactoryLaunch.screen == "settings") }
    if (showSettings) {
        SettingsScreen(onBack = { showSettings = false })
    } else {
        HomeScreen(onOpenSettings = { showSettings = true })
    }
}
