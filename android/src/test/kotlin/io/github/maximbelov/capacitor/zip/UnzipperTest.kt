package io.github.maximbelov.capacitor.zip

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import java.io.File

class UnzipperTest {
    @get:Rule
    val temp = TemporaryFolder()

    // The fixtures are shared with the iOS tests, in test/fixtures at the repository root
    private fun fixture(name: String): File = File("../test/fixtures/$name").absoluteFile.also { assertTrue("missing fixture $it", it.isFile) }

    private fun expectCode(code: String, block: () -> Unit) {
        try {
            block()
            fail("expected $code")
        } catch (e: UnzipException) {
            assertEquals(e.message, code, e.code)
        }
    }

    @Test
    fun extractsFilesAndDirectories() {
        val out = File(temp.root, "out")
        val events = mutableListOf<Pair<Int, Int>>()
        val count = Unzipper.unzip(fixture("basic.zip"), out) { loaded, total -> events += loaded to total }

        assertEquals(5, count)
        assertEquals("Hello, zip!\n", File(out, "hello.txt").readText())
        assertEquals("<!doctype html><title>t</title>\n", File(out, "www/index.html").readText())
        assertEquals("console.log(\"app\");\n".repeat(50), File(out, "www/js/app.js").readText())
        assertTrue(File(out, "empty").isDirectory)
        assertEquals((1..5).map { it to 5 }, events)
    }

    @Test
    fun acceptsAFileUrl() {
        val out = File(temp.root, "url out")
        val source = Unzipper.resolvePath(fixture("basic.zip").toURI().toString(), "source")
        val destination = Unzipper.resolvePath(out.toURI().toString(), "destination")
        assertEquals(out.absolutePath, destination.absolutePath.trimEnd('/'))
        Unzipper.unzip(source, destination)
        assertTrue(File(out, "hello.txt").isFile)
    }

    @Test
    fun refusesRelativeAndForeignPaths() {
        expectCode("INVALID_ARGUMENT") { Unzipper.resolvePath("relative/a.zip", "source") }
        expectCode("INVALID_ARGUMENT") { Unzipper.resolvePath("content://media/a.zip", "source") }
        expectCode("INVALID_ARGUMENT") { Unzipper.resolvePath("", "source") }
        expectCode("INVALID_ARGUMENT") { Unzipper.resolvePath(null, "source") }
    }

    @Test
    fun refusesZipSlipAndWritesNothing() {
        val parent = File(temp.root, "parent").apply { mkdirs() }
        val out = File(parent, "out")
        expectCode("UNSAFE_ENTRY") { Unzipper.unzip(fixture("slip.zip"), out) }
        assertFalse(File(parent, "evil.txt").exists())
        assertFalse("the safe entry must not be written either", File(out, "safe.txt").exists())
    }

    @Test
    fun refusesAnAbsoluteEntry() {
        expectCode("UNSAFE_ENTRY") { Unzipper.unzip(fixture("absolute.zip"), File(temp.root, "out")) }
    }

    @Test
    fun flagsUnsafeNames() {
        assertTrue(Unzipper.isUnsafeEntryName("../a"))
        assertTrue(Unzipper.isUnsafeEntryName("a/../../b"))
        assertTrue(Unzipper.isUnsafeEntryName("..\\a"))
        assertTrue(Unzipper.isUnsafeEntryName("/etc/passwd"))
        assertFalse(Unzipper.isUnsafeEntryName("a/b..c/d"))
        assertFalse(Unzipper.isUnsafeEntryName("..a"))
    }

    @Test
    fun reportsAMissingSource() {
        expectCode("NOT_FOUND") { Unzipper.unzip(File(temp.root, "nope.zip"), File(temp.root, "out")) }
    }

    @Test
    fun reportsSomethingThatIsNotAZip() {
        expectCode("BAD_ARCHIVE") { Unzipper.unzip(fixture("not-a-zip.zip"), File(temp.root, "out")) }
    }

    @Test
    fun overwritesByDefaultAndRefusesWhenAskedNotTo() {
        val out = File(temp.root, "out").apply { mkdirs() }
        File(out, "hello.txt").writeText("old")
        Unzipper.unzip(fixture("basic.zip"), out)
        assertEquals("Hello, zip!\n", File(out, "hello.txt").readText())

        File(out, "hello.txt").writeText("old")
        expectCode("EXISTS") { Unzipper.unzip(fixture("basic.zip"), out, overwrite = false) }
        assertEquals("old", File(out, "hello.txt").readText())
    }
}
