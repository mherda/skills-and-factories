package {{APPLICATION_ID}}

import android.content.Intent

/**
 * Intent extras the factory uses to take screenshots of any screen (see
 * CLAUDE.md, Screens). Debug builds only: release builds ignore them.
 *
 *     adb shell am start -n <app id>/.MainActivity --es factoryScreen settings --ez factoryNoPrompts true
 */
object FactoryLaunch {
    /** The screen named by `--es factoryScreen <name>`, or null. */
    var screen: String? = null
        private set

    /**
     * `--ez factoryNoPrompts true`: skip permission requests and rationale
     * dialogs (location, notifications, ...) so they don't cover screenshots.
     * Every place that asks for a permission must check this first.
     */
    var noPrompts: Boolean = false
        private set

    /** Called by MainActivity before the first frame. */
    fun read(intent: Intent?) {
        if (!BuildConfig.DEBUG || intent == null) return
        screen = intent.getStringExtra("factoryScreen")
        noPrompts = intent.getBooleanExtra("factoryNoPrompts", false)
    }
}
