package com.melodylien.app.ui.theme

import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

// MelodyLienカラーパレット
object MelodyColors {
    val Primary    = Color(0xFF8F6DF4)
    val Primary2   = Color(0xFFB79CFF)
    val Pink       = Color(0xFFFF7FA6)
    val Gold       = Color(0xFFFFD35B)
    val Mint       = Color(0xFF76D6AE)
    val Blue       = Color(0xFF73C5FF)
    val Surface    = Color(0xFFFFFefd)
    val Surface2   = Color(0xFFF8F1FF)
    val Ink        = Color(0xFF302944)
    val Muted      = Color(0xFF817992)
    val Line       = Color(0xFFEADFF3)
    val BgGradient1 = Color(0xFFFF7FA6)  // top-left
    val BgGradient2 = Color(0xFF8F6DF4)  // top-right

    // Art gradients
    val Sunset = listOf(Color(0xFFFF9A6C), Color(0xFFFFCA7A), Color(0xFF6B468C))
    val Violet = listOf(Color(0xFFC0ADFF), Color(0xFF9271F0), Color(0xFF4F3B82))
    val Berry  = listOf(Color(0xFFFF8EB5), Color(0xFFBB74FF), Color(0xFF39436F))
    val Magic  = listOf(Color(0xFF8EE7FF), Color(0xFF80D8B5), Color(0xFF365A70))
    val Default = listOf(Color(0xFFA892FF), Color(0xFFFFB0BF), Color(0xFF33465F))

    fun artColors(color: String) = when (color) {
        "sunset" -> Sunset
        "violet" -> Violet
        "berry"  -> Berry
        "magic"  -> Magic
        else     -> Default
    }
}

private val LightColorScheme = lightColorScheme(
    primary         = MelodyColors.Primary,
    secondary       = MelodyColors.Pink,
    tertiary        = MelodyColors.Gold,
    background      = MelodyColors.Surface,
    surface         = MelodyColors.Surface,
    onPrimary       = Color.White,
    onBackground    = MelodyColors.Ink,
    onSurface       = MelodyColors.Ink,
)

@Composable
fun MelodyLienTheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = LightColorScheme,
        typography = Typography(),
        content = content
    )
}
