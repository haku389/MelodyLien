package com.melodylien.app.ui.home

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.melodylien.app.data.model.Track
import com.melodylien.app.ui.components.ArtBlock
import com.melodylien.app.ui.components.ProgressBar
import com.melodylien.app.ui.theme.MelodyColors
import com.melodylien.app.viewmodel.AppViewModel
import com.melodylien.app.viewmodel.Screen
import com.melodylien.app.viewmodel.Tab

@Composable
fun HomeScreen(vm: AppViewModel) {
    val user        by vm.user.collectAsState()
    val collection  by vm.collection.collectAsState()
    val mission     by vm.mission.collectAsState()
    val homeState   by vm.homeState.collectAsState()
    val tracks      by vm.tracks.collectAsState()

    LazyColumn(
        contentPadding = PaddingValues(start = 18.dp, end = 18.dp, top = 22.dp, bottom = 112.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        // Header
        item {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                Box(
                    Modifier.size(54.dp).clip(CircleShape)
                        .background(Color(0xFFE8DFF7)),
                    contentAlignment = Alignment.Center
                ) { Text("🎵", fontSize = 22.sp) }

                Column(Modifier.weight(1f)) {
                    Text(user?.name ?: "—", fontSize = 15.sp, fontWeight = FontWeight.Black)
                    Text("Lv.${user?.level ?: 0}", fontSize = 10.sp, fontWeight = FontWeight.ExtraBold, color = MelodyColors.Muted)
                    Spacer(Modifier.height(4.dp))
                    ProgressBar(progress = (user?.level ?: 0) / 100f)
                }

                CoinPill(coins = user?.coins ?: 0)
            }
        }

        // Hero panel
        item {
            val hero = homeState.heroTrack
            MlCard {
                Row(Modifier.padding(16.dp), horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                    ArtBlock(color = hero?.color ?: "violet", thumbnailUrl = hero?.artworkUrl, modifier = Modifier.size(132.dp))
                    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        Text("今日のメロディ", fontSize = 10.sp, fontWeight = FontWeight.ExtraBold, color = MelodyColors.Muted)
                        Text(hero?.displayTitle ?: "—", fontSize = 14.sp, fontWeight = FontWeight.Black, maxLines = 1, overflow = TextOverflow.Ellipsis)
                        if (hero != null) {
                            Row(verticalAlignment = Alignment.Bottom, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                                Text("${hero.ownedPieces.size} / ${hero.pieceCount}", fontSize = 20.sp, fontWeight = FontWeight.Black, lineHeight = 20.sp)
                                Text("ピース", fontSize = 10.sp, fontWeight = FontWeight.ExtraBold, color = MelodyColors.Muted)
                            }
                            ProgressBar(progress = hero.progress)
                            val rem = maxOf(hero.pieceCount - hero.ownedPieces.size, 0)
                            Text(if (rem > 0) "あと${rem}ピースで完成！" else "完成！", fontSize = 10.sp, fontWeight = FontWeight.ExtraBold, color = MelodyColors.Muted)
                        }
                        Button(
                            onClick = { vm.setTab(Tab.EXCHANGE) },
                            modifier = Modifier.fillMaxWidth(),
                            shape = RoundedCornerShape(16.dp),
                            colors = ButtonDefaults.buttonColors(containerColor = MelodyColors.Primary)
                        ) {
                            Text("📍 近距離交換をはじめる", fontSize = 12.sp, fontWeight = FontWeight.Black)
                        }
                    }
                }
            }
        }

        // Collection
        item {
            MlCard {
                Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    Text("コレクション", fontSize = 14.sp, fontWeight = FontWeight.Black)
                    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                        StatTile("曲パズル", "${collection?.completedPuzzles ?: 0} / ${collection?.totalPuzzles ?: 0}", Modifier.weight(1f))
                        StatTile("アーティスト", "${collection?.completedArtists ?: 0} / ${collection?.totalArtists ?: 0}", Modifier.weight(1f))
                        StatTile("プレイリスト", "${collection?.playlists ?: 0}", Modifier.weight(1f))
                    }
                }
            }
        }

        // Mission
        item {
            MlCard {
                Row(Modifier.padding(16.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                        Text("${mission?.label ?: "デイリー"}ミッション", fontSize = 13.sp, fontWeight = FontWeight.Black)
                        ProgressBar(progress = mission?.progress ?: 0f)
                    }
                    Text("${mission?.current ?: 0} / ${mission?.target ?: 5}", fontSize = 14.sp, fontWeight = FontWeight.Black)
                }
            }
        }

        // Recent tracks
        item {
            MlCard {
                Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
                        Text("最近追加した曲", fontSize = 14.sp, fontWeight = FontWeight.Black)
                        TextButton(onClick = { vm.setTab(Tab.PLAYLIST) }) {
                            Text("すべて見る", fontSize = 11.sp, fontWeight = FontWeight.ExtraBold, color = MelodyColors.Primary)
                        }
                    }
                    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                        homeState.recentTracks.forEach { track ->
                            SongTile(track = track, modifier = Modifier.weight(1f)) {
                                val screen = if (track.isUnlocked) Screen.Puzzle(track.id) else Screen.Mystery(track.id)
                                vm.navigate(screen)
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun CoinPill(coins: Int) {
    Row(
        modifier = Modifier
            .clip(CircleShape)
            .background(Color.White.copy(alpha = 0.86f))
            .padding(horizontal = 12.dp, vertical = 8.dp),
        horizontalArrangement = Arrangement.spacedBy(6.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text("🪙")
        Text("$coins", fontSize = 12.sp, fontWeight = FontWeight.Black)
    }
}

@Composable
private fun StatTile(label: String, value: String, modifier: Modifier = Modifier) {
    Column(
        modifier = modifier
            .clip(RoundedCornerShape(18.dp))
            .background(MelodyColors.Surface2)
            .padding(horizontal = 8.dp, vertical = 12.dp),
    ) {
        Text(label, fontSize = 10.sp, fontWeight = FontWeight.ExtraBold, color = MelodyColors.Muted, maxLines = 1)
        Spacer(Modifier.height(5.dp))
        Text(value, fontSize = 13.sp, fontWeight = FontWeight.Black)
    }
}

@Composable
private fun SongTile(track: Track, modifier: Modifier = Modifier, onClick: () -> Unit) {
    Column(modifier = modifier.clickable(onClick = onClick)) {
        ArtBlock(color = track.color, thumbnailUrl = track.artworkUrl, modifier = Modifier.fillMaxWidth().aspectRatio(1f))
        Spacer(Modifier.height(8.dp))
        Text(if (track.isUnlocked) track.title ?: "—" else "未解放メロディ",
            fontSize = 11.sp, fontWeight = FontWeight.Black, maxLines = 1, overflow = TextOverflow.Ellipsis)
        Text(if (track.isUnlocked) track.artistName ?: "—" else "???",
            fontSize = 10.sp, fontWeight = FontWeight.ExtraBold, color = MelodyColors.Muted, maxLines = 1)
    }
}

@Composable
fun MlCard(modifier: Modifier = Modifier, content: @Composable () -> Unit) {
    Surface(
        modifier = modifier.fillMaxWidth(),
        shape = RoundedCornerShape(24.dp),
        color = Color.White.copy(alpha = 0.82f),
        shadowElevation = 4.dp,
        tonalElevation = 0.dp,
    ) { content() }
}
