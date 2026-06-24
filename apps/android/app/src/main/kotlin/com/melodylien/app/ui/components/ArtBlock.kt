package com.melodylien.app.ui.components

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import coil.compose.AsyncImage
import com.melodylien.app.ui.theme.MelodyColors

@Composable
fun ArtBlock(
    color: String,
    modifier: Modifier = Modifier,
    cornerRadius: Dp = 18.dp,
    thumbnailUrl: String? = null,
) {
    val colors = MelodyColors.artColors(color)
    Box(
        modifier = modifier
            .clip(RoundedCornerShape(cornerRadius))
            .background(Brush.linearGradient(colors))
    ) {
        // Puzzle grid overlay
        Canvas(modifier = Modifier.fillMaxSize()) {
            drawPuzzleGrid(this)
        }
        // YouTube サムネイル（解放済みの曲のみ）
        if (thumbnailUrl != null) {
            AsyncImage(
                model = thumbnailUrl,
                contentDescription = null,
                contentScale = ContentScale.Crop,
                modifier = Modifier.fillMaxSize(),
            )
        }
    }
}

private fun drawPuzzleGrid(scope: DrawScope) {
    val w = scope.size.width
    val h = scope.size.height
    val lineColor = Color.White.copy(alpha = 0.46f)
    val strokeWidth = 1.5f

    // Vertical lines
    listOf(w * 0.33f, w * 0.66f).forEach { x ->
        scope.drawLine(lineColor, Offset(x, 0f), Offset(x, h), strokeWidth)
    }
    // Horizontal lines
    listOf(h * 0.33f, h * 0.66f).forEach { y ->
        scope.drawLine(lineColor, Offset(0f, y), Offset(w, y), strokeWidth)
    }
}

@Composable
fun ProgressBar(
    progress: Float,
    modifier: Modifier = Modifier,
    height: Dp = 8.dp,
) {
    Box(
        modifier = modifier
            .fillMaxWidth()
            .height(height)
            .clip(RoundedCornerShape(999.dp))
            .background(Color(0xFFEEE6FB))
    ) {
        Box(
            modifier = Modifier
                .fillMaxWidth(fraction = progress.coerceIn(0f, 1f))
                .fillMaxHeight()
                .background(
                    Brush.horizontalGradient(
                        listOf(MelodyColors.Primary, MelodyColors.Pink)
                    ),
                    RoundedCornerShape(999.dp)
                )
        )
    }
}
