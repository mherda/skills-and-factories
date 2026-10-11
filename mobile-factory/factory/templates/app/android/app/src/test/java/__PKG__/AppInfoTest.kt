package {{APPLICATION_ID}}

import org.junit.Assert.assertEquals
import org.junit.Test

class AppInfoTest {
    @Test
    fun versionShowsVersionNameAndCode() {
        assertEquals("1.2 (34)", AppInfo.versionText("1.2", 34))
    }

    @Test
    fun versionCopesWithMissingValues() {
        assertEquals("? (?)", AppInfo.versionText(null, null))
    }
}
