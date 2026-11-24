cat > $D/ui/ChatScreen.kt <<'EOF'
package com.drago.offlinememory.ui

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.Send
import androidx.compose.material3.FilledIconButton
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButtonDefaults
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.drago.offlinememory.ui.theme.BorderBlue
import com.drago.offlinememory.ui.theme.ElectricBlue
import com.drago.offlinememory.ui.theme.Navy
import com.drago.offlinememory.ui.theme.NavyCard
import com.drago.offlinememory.ui.theme.TextMain
import com.drago.offlinememory.ui.theme.UserBubble
import com.drago.offlinememory.ui.theme.dragoFieldColors
import com.drago.offlinememory.viewmodel.ChatMessage
import com.drago.offlinememory.viewmodel.MemoryViewModel

@Composable
fun ChatScreen(viewModel: MemoryViewModel) {
    val messages by viewModel.messages.collectAsStateWithLifecycle()
    var input by rememberSaveable { mutableStateOf("") }
    val listState = rememberLazyListState()

    LaunchedEffect(messages.size) {
        listState.animateScrollToItem(messages.lastIndex)
    }

    Column(Modifier.fillMaxSize()) {
        LazyColumn(
            modifier = Modifier
                .weight(1f)
                .fillMaxWidth(),
            state = listState,
            contentPadding = PaddingValues(16.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp)
        ) {
            items(messages) { message -> MessageBubble(message) }
        }

        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 12.dp, vertical = 8.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            OutlinedTextField(
                value = input,
                onValueChange = { input = it },
                modifier = Modifier.weight(1f),
                placeholder = { Text("Type in English or বাংলা…") },
                maxLines = 4,
                shape = RoundedCornerShape(24.dp),
                colors = dragoFieldColors()
            )
            FilledIconButton(
                onClick = {
                    if (input.isNotBlank()) {
                        viewModel.send(input)
                        input = ""
                    }
                },
                colors = IconButtonDefaults.filledIconButtonColors(
                    containerColor = ElectricBlue,
                    contentColor = Navy
                )
            ) {
                Icon(Icons.AutoMirrored.Filled.Send, contentDescription = "Send")
            }
        }
    }
}

@Composable
private fun MessageBubble(message: ChatMessage) {
    Box(
        modifier = Modifier.fillMaxWidth(),
        contentAlignment = if (message.fromUser) Alignment.CenterEnd else Alignment.CenterStart
    ) {
        Surface(
            color = if (message.fromUser) UserBubble else NavyCard,
            shape = RoundedCornerShape(16.dp),
            border = BorderStroke(1.dp, if (message.fromUser) ElectricBlue else BorderBlue)
        ) {
            Text(
                text = message.text,
                color = TextMain,
                modifier = Modifier.padding(horizontal = 14.dp, vertical = 10.dp)
            )
        }
    }
}
EOF

cat > $D/MainActivity.kt <<'EOF'
package com.drago.offlinememory

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.SystemBarStyle
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.ui.graphics.toArgb
import com.drago.offlinememory.ui.DragoApp
import com.drago.offlinememory.ui.theme.DragoTheme
import com.drago.offlinememory.ui.theme.Navy

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge(
            statusBarStyle = SystemBarStyle.dark(Navy.toArgb()),
            navigationBarStyle = SystemBarStyle.dark(Navy.toArgb())
        )
        setContent {
            DragoTheme {
                DragoApp()
            }
        }
    }
}
EOF
