package {{APPLICATION_ID}}.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

// The app's own colour scheme. Dynamic colour (wallpaper-based) is off, so
// screenshots and the brand look the same on every device.
private val LightColors = lightColorScheme(
    primary = Color(0xFF2F5D50),
    onPrimary = Color(0xFFFFFFFF),
    primaryContainer = Color(0xFFB4EFDC),
    onPrimaryContainer = Color(0xFF002019),
)

private val DarkColors = darkColorScheme(
    primary = Color(0xFF98D3C0),
    onPrimary = Color(0xFF00382C),
    primaryContainer = Color(0xFF15463A),
    onPrimaryContainer = Color(0xFFB4EFDC),
)

@Composable
fun {{APP}}Theme(darkTheme: Boolean = isSystemInDarkTheme(), content: @Composable () -> Unit) {
    MaterialTheme(colorScheme = if (darkTheme) DarkColors else LightColors, content = content)
}
