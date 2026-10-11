package {{APPLICATION_ID}}

/** Facts about the running build, for Settings and support emails. */
object AppInfo {
    /** "0.1 (12)": version name and version code. */
    val version: String
        get() = versionText(BuildConfig.VERSION_NAME, BuildConfig.VERSION_CODE.toLong())

    fun versionText(name: String?, code: Long?): String = "${name ?: "?"} (${code ?: "?"})"
}
