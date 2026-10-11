package {{APPLICATION_ID}}

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import {{APPLICATION_ID}}.ui.AppRoot
import {{APPLICATION_ID}}.ui.theme.{{APP}}Theme

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        FactoryLaunch.read(intent)
        enableEdgeToEdge()
        setContent {
            {{APP}}Theme {
                AppRoot()
            }
        }
    }
}
