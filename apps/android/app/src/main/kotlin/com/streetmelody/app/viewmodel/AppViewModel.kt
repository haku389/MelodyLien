package com.streetmelody.app.viewmodel

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.streetmelody.app.data.model.*
import com.streetmelody.app.data.repository.MelodyRepository
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.launch

// MARK: - Navigation

sealed class Screen {
    data object Home      : Screen()
    data object Exchange  : Screen()
    data class Mystery(val trackId: String) : Screen()
    data class Puzzle(val trackId: String)  : Screen()
    data class Artist(val artistId: String) : Screen()
    data object Playlist  : Screen()
}

enum class Tab { HOME, EXCHANGE, PUZZLE, ARTIST, PLAYLIST }

// MARK: - UI State

data class HomeUiState(
    val user: User? = null,
    val collection: CollectionSummary? = null,
    val mission: Mission? = null,
    val heroTrack: Track? = null,
    val recentTracks: List<Track> = emptyList(),
)

// MARK: - AppViewModel

class AppViewModel(app: Application) : AndroidViewModel(app) {

    private val repository = MelodyRepository()

    // Nav
    private val _activeTab = MutableStateFlow(Tab.HOME)
    val activeTab: StateFlow<Tab> = _activeTab

    private val _navStack = MutableStateFlow<List<Screen>>(emptyList())
    val navStack: StateFlow<List<Screen>> = _navStack

    // Data
    private val _tracks = MutableStateFlow<Map<String, Track>>(emptyMap())
    val tracks: StateFlow<Map<String, Track>> = _tracks

    private val _encounter = MutableStateFlow<Encounter?>(null)
    val encounter: StateFlow<Encounter?> = _encounter

    private val _playlist = MutableStateFlow<DailyPlaylist?>(null)
    val playlist: StateFlow<DailyPlaylist?> = _playlist

    val homeState: StateFlow<HomeUiState> = combine(
        _tracks, _encounter, _playlist
    ) { tracks, _, playlist ->
        val heroTrackId = playlist?.tracks?.firstOrNull()?.trackId
        HomeUiState(
            heroTrack = heroTrackId?.let { tracks[it] },
            recentTracks = tracks.values.take(3).toList(),
        )
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), HomeUiState())

    // UI state
    private val _selectedCandidate = MutableStateFlow<Int?>(null)
    val selectedCandidate: StateFlow<Int?> = _selectedCandidate

    private val _toast = MutableStateFlow<String?>(null)
    val toast: StateFlow<String?> = _toast

    private val _user = MutableStateFlow<User?>(null)
    val user: StateFlow<User?> = _user

    private val _collection = MutableStateFlow<CollectionSummary?>(null)
    val collection: StateFlow<CollectionSummary?> = _collection

    private val _mission = MutableStateFlow<Mission?>(null)
    val mission: StateFlow<Mission?> = _mission

    init { loadAll() }

    // MARK: - Load

    fun loadAll() {
        viewModelScope.launch {
            launch { runCatching { _user.value = repository.fetchMe() } }
            launch { runCatching { _collection.value = repository.fetchCollection() } }
            launch { runCatching { _mission.value = repository.fetchMission() } }
            launch { runCatching {
                val list = repository.fetchTracks()
                _tracks.value = list.associateBy { it.id }
            }}
            launch { runCatching { _encounter.value = repository.fetchTodayEncounter() } }
            launch { runCatching { _playlist.value = repository.fetchDailyPlaylist() } }
        }
    }

    // MARK: - Actions

    fun selectCandidate(index: Int) { _selectedCandidate.value = index }

    fun confirmPiece() {
        val enc = _encounter.value ?: return
        val idx = _selectedCandidate.value ?: return
        viewModelScope.launch {
            runCatching { repository.selectPiece(enc.id, idx) }.onSuccess { result ->
                _tracks.value = _tracks.value.toMutableMap().also { map ->
                    map[result.trackId]?.let { track ->
                        if (result.added && !track.ownedPieces.contains(result.pieceNumber)) {
                            map[result.trackId] = track.copy(ownedPieces = (track.ownedPieces + result.pieceNumber).sorted())
                        }
                    }
                }
                _selectedCandidate.value = null
                showToast(if (result.added) "ピースを獲得しました！" else "所持済みのピースです")
                val screen = if (result.nextScreen == "puzzle") Screen.Puzzle(result.trackId)
                             else Screen.Mystery(result.trackId)
                _navStack.value = _navStack.value + screen
            }
        }
    }

    fun applyHint(trackId: String, kind: HintKind) {
        viewModelScope.launch {
            runCatching { repository.applyHint(trackId, kind) }.onSuccess { result ->
                _tracks.value = _tracks.value.toMutableMap().also { map ->
                    map[trackId]?.let {
                        map[trackId] = it.copy(hintLevel = result.hintLevel, answerReady = result.answerReady)
                    }
                }
                showToast(if (kind == HintKind.ANSWER) "YouTubeリンクを表示しました" else "ヒントを解放しました")
            }
        }
    }

    fun unlockTrack(trackId: String) {
        viewModelScope.launch {
            runCatching { repository.unlockTrack(trackId) }.onSuccess {
                _tracks.value = _tracks.value.toMutableMap().also { map ->
                    map[trackId]?.let { map[trackId] = it.copy(isUnlocked = true) }
                }
                showToast("曲が解放されました！")
                val newStack = _navStack.value.dropLast(1) + Screen.Puzzle(trackId)
                _navStack.value = newStack
            }
        }
    }

    fun navigate(screen: Screen) { _navStack.value = _navStack.value + screen }
    fun goBack()                  { _navStack.value = _navStack.value.dropLast(1) }
    fun setTab(tab: Tab)          { _activeTab.value = tab }

    private fun showToast(msg: String) {
        _toast.value = msg
        viewModelScope.launch {
            kotlinx.coroutines.delay(2500)
            _toast.value = null
        }
    }
}

enum class HintKind { HINT1, HINT2, ANSWER }
