cat > $D/viewmodel/MemoryViewModel.kt <<'EOF'
package com.drago.offlinememory.viewmodel

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.drago.offlinememory.data.AppDatabase
import com.drago.offlinememory.data.Memory
import com.drago.offlinememory.data.MemoryRepository
import com.drago.offlinememory.domain.Command
import com.drago.offlinememory.domain.CommandParser
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.flatMapLatest
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch

data class ChatMessage(val text: String, val fromUser: Boolean)

@OptIn(ExperimentalCoroutinesApi::class)
class MemoryViewModel(application: Application) : AndroidViewModel(application) {

    private val repository = MemoryRepository(AppDatabase.get(application).memoryDao())

    private val _messages = MutableStateFlow(
        listOf(
            ChatMessage(
                "DRAGO online. Say \"Remember that ...\" to save something, or ask me a question.",
                fromUser = false
            )
        )
    )
    val messages: StateFlow<List<ChatMessage>> = _messages.asStateFlow()

    private val _query = MutableStateFlow("")
    val query: StateFlow<String> = _query.asStateFlow()

    val memories: StateFlow<List<Memory>> = _query
        .flatMapLatest { repository.search(it) }
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), emptyList())

    fun send(input: String) {
        val text = input.trim()
        if (text.isEmpty()) return
        addMessage(ChatMessage(text, fromUser = true))
        viewModelScope.launch {
            when (val command = CommandParser.parse(text)) {
                is Command.Save -> {
                    repository.add(command.content)
                    addMessage(ChatMessage("Saved successfully.", fromUser = false))
                }
                is Command.Ask -> {
                    val reply = repository.answer(command.question)
                    addMessage(ChatMessage(reply, fromUser = false))
                }
            }
        }
    }

    private fun addMessage(message: ChatMessage) {
        _messages.value = _messages.value + message
    }

    fun setQuery(value: String) {
        _query.value = value
    }

    fun addMemory(text: String) {
        viewModelScope.launch { repository.add(text) }
    }

    fun updateMemory(memory: Memory, newText: String) {
        viewModelScope.launch { repository.update(memory, newText) }
    }

    fun deleteMemory(memory: Memory) {
        viewModelScope.launch { repository.delete(memory) }
    }
}
EOF

cat > $D/ui/theme/Theme.kt <<'EOF'
package com.drago.offlinememory.ui.theme

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.TextFieldColors
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

val Navy = Color(0xFF050B1A)
val NavySurface = Color(0xFF0B1630)
val NavyCard = Color(0xFF111F3F)
val ElectricBlue = Color(0xFF00B4FF)
val Cyan = Color(0xFF00E5FF)
val TextMain = Color(0xFFE6F1FF)
val TextMuted = Color(0xFF8FA6C8)
val BorderBlue = Color(0xFF1E3A6B)
val UserBubble = Color(0xFF0A3A66)

private val DragoColors = darkColorScheme(
    primary = ElectricBlue,
    onPrimary = Navy,
    secondary = Cyan,
    background = Navy,
    onBackground = TextMain,
    surface = NavySurface,
    onSurface = TextMain,
    surfaceVariant = NavyCard,
    onSurfaceVariant = TextMuted,
    outline = BorderBlue
)

@Composable
fun DragoTheme(content: @Composable () -> Unit) {
    MaterialTheme(colorScheme = DragoColors, content = content)
}

@Composable
fun dragoFieldColors(): TextFieldColors = OutlinedTextFieldDefaults.colors(
    focusedTextColor = TextMain,
    unfocusedTextColor = TextMain,
    focusedBorderColor = ElectricBlue,
    unfocusedBorderColor = BorderBlue,
    cursorColor = Cyan,
    focusedPlaceholderColor = TextMuted,
    unfocusedPlaceholderColor = TextMuted,
    focusedLeadingIconColor = ElectricBlue,
    unfocusedLeadingIconColor = TextMuted
)
EOF

cat > $D/ui/DragoApp.kt <<'EOF'
package com.drago.offlinememory.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Face
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.Icon
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.NavigationBarItemDefaults
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.drago.offlinememory.ui.theme.Cyan
import com.drago.offlinememory.ui.theme.ElectricBlue
import com.drago.offlinememory.ui.theme.Navy
import com.drago.offlinememory.ui.theme.NavyCard
import com.drago.offlinememory.ui.theme.NavySurface
import com.drago.offlinememory.ui.theme.TextMuted
import com.drago.offlinememory.viewmodel.MemoryViewModel

@Composable
fun DragoApp(viewModel: MemoryViewModel = viewModel()) {
    var tab by rememberSaveable { mutableIntStateOf(0) }

    val itemColors = NavigationBarItemDefaults.colors(
        selectedIconColor = Navy,
        selectedTextColor = ElectricBlue,
        indicatorColor = ElectricBlue,
        unselectedIconColor = TextMuted,
        unselectedTextColor = TextMuted
    )

    Scaffold(
        modifier = Modifier.imePadding(),
        containerColor = Navy,
        topBar = { DragoHeader() },
        bottomBar = {
            NavigationBar(containerColor = NavySurface) {
                NavigationBarItem(
                    selected = tab == 0,
                    onClick = { tab = 0 },
                    icon = { Icon(Icons.Default.Face, contentDescription = "Chat") },
                    label = { Text("Chat") },
                    colors = itemColors
                )
                NavigationBarItem(
                    selected = tab == 1,
                    onClick = { tab = 1 },
                    icon = { Icon(Icons.Default.Search, contentDescription = "Memories") },
                    label = { Text("Memories") },
                    colors = itemColors
                )
            }
        }
    ) { padding ->
        Box(Modifier.padding(padding)) {
            if (tab == 0) ChatScreen(viewModel) else MemoriesScreen(viewModel)
        }
    }
}

@Composable
private fun DragoHeader() {
    Column(
        Modifier
            .fillMaxWidth()
            .background(NavySurface)
            .statusBarsPadding()
    ) {
        Column(Modifier.padding(horizontal = 20.dp, vertical = 12.dp)) {
            Text(
                text = "DRAGO",
                color = ElectricBlue,
                fontSize = 26.sp,
                fontWeight = FontWeight.Bold,
                letterSpacing = 6.sp
            )
            Text(
                text = "OFFLINE MEMORY",
                color = TextMuted,
                fontSize = 11.sp,
                letterSpacing = 3.sp
            )
        }
        Box(
            Modifier
                .fillMaxWidth()
                .height(2.dp)
                .background(Brush.horizontalGradient(listOf(NavyCard, ElectricBlue, Cyan, NavyCard)))
        )
    }
}
EOF
