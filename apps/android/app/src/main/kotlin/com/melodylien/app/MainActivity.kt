package com.melodylien.app

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.viewModels
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.res.vectorResource
import com.melodylien.app.ui.home.HomeScreen
import com.melodylien.app.ui.theme.MelodyLienTheme
import com.melodylien.app.viewmodel.AppViewModel
import com.melodylien.app.viewmodel.Tab

class MainActivity : ComponentActivity() {

    private val vm: AppViewModel by viewModels()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            MelodyLienTheme {
                MelodyLienApp(vm = vm)
            }
        }
    }
}

@Composable
fun MelodyLienApp(vm: AppViewModel) {
    val activeTab by vm.activeTab.collectAsState()
    val toast by vm.toast.collectAsState()

    Scaffold(
        bottomBar = { BottomNavBar(activeTab = activeTab, onTabSelected = vm::setTab) }
    ) { padding ->
        Box(Modifier.fillMaxSize().padding(padding)) {
            when (activeTab) {
                Tab.HOME     -> HomeScreen(vm)
                Tab.EXCHANGE -> Text("ピース選択画面 (実装予定)", Modifier.align(Alignment.Center))
                Tab.PUZZLE   -> Text("パズル画面 (実装予定)",   Modifier.align(Alignment.Center))
                Tab.ARTIST   -> Text("アーティスト画面 (実装予定)", Modifier.align(Alignment.Center))
                Tab.PLAYLIST -> Text("プレイリスト画面 (実装予定)", Modifier.align(Alignment.Center))
            }

            // Toast
            if (toast != null) {
                Surface(
                    modifier = Modifier.align(Alignment.BottomCenter),
                    shape = MaterialTheme.shapes.extraLarge,
                    shadowElevation = 8.dp,
                ) {
                    Text(toast!!, modifier = Modifier.padding(horizontal = 16.dp, vertical = 12.dp),
                        style = MaterialTheme.typography.labelLarge)
                }
            }
        }
    }
}

@Composable
private fun BottomNavBar(activeTab: Tab, onTabSelected: (Tab) -> Unit) {
    val items = listOf(
        Triple(Tab.HOME,     "home",         "ホーム"),
        Triple(Tab.EXCHANGE, "swap_horiz",   "届いた"),
        Triple(Tab.PUZZLE,   "extension",    "パズル"),
        Triple(Tab.ARTIST,   "star",         "アーティスト"),
        Triple(Tab.PLAYLIST, "queue_music",  "プレイリスト"),
    )
    NavigationBar {
        items.forEach { (tab, _, label) ->
            NavigationBarItem(
                selected = activeTab == tab,
                onClick  = { onTabSelected(tab) },
                icon     = { Text(tabEmoji(tab)) },
                label    = { Text(label, style = MaterialTheme.typography.labelSmall) },
            )
        }
    }
}

private fun tabEmoji(tab: Tab) = when (tab) {
    Tab.HOME     -> "🏠"
    Tab.EXCHANGE -> "🔄"
    Tab.PUZZLE   -> "🧩"
    Tab.ARTIST   -> "⭐"
    Tab.PLAYLIST -> "🎵"
}
