cat > $D/ui/MemoriesScreen.kt <<'EOF'
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
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.FloatingActionButton
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.drago.offlinememory.data.Memory
import com.drago.offlinememory.ui.theme.BorderBlue
import com.drago.offlinememory.ui.theme.Cyan
import com.drago.offlinememory.ui.theme.ElectricBlue
import com.drago.offlinememory.ui.theme.Navy
import com.drago.offlinememory.ui.theme.NavyCard
import com.drago.offlinememory.ui.theme.TextMain
import com.drago.offlinememory.ui.theme.TextMuted
import com.drago.offlinememory.ui.theme.dragoFieldColors
import com.drago.offlinememory.viewmodel.MemoryViewModel
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

@Composable
fun MemoriesScreen(viewModel: MemoryViewModel) {
    val memories by viewModel.memories.collectAsStateWithLifecycle()
    val query by viewModel.query.collectAsStateWithLifecycle()

    var showAdd by remember { mutableStateOf(false) }
    var editing by remember { mutableStateOf<Memory?>(null) }
    var deleting by remember { mutableStateOf<Memory?>(null) }

    Box(Modifier.fillMaxSize()) {
        Column(Modifier.fillMaxSize()) {
            OutlinedTextField(
                value = query,
                onValueChange = viewModel::setQuery,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(16.dp),
                placeholder = { Text("Search memories…") },
                leadingIcon = { Icon(Icons.Default.Search, contentDescription = null) },
                singleLine = true,
                shape = RoundedCornerShape(24.dp),
                colors = dragoFieldColors()
            )

            if (memories.isEmpty()) {
                Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    Text(
                        text = if (query.isBlank()) "No memories yet.\nTap + or use the Chat tab."
                        else "No memories match your search.",
                        color = TextMuted
                    )
                }
            } else {
                LazyColumn(
                    contentPadding = PaddingValues(start = 16.dp, end = 16.dp, bottom = 96.dp),
                    verticalArrangement = Arrangement.spacedBy(10.dp)
                ) {
                    items(memories, key = { it.id }) { memory ->
                        MemoryCard(
                            memory = memory,
                            onEdit = { editing = memory },
                            onDelete = { deleting = memory }
                        )
                    }
                }
            }
        }

        FloatingActionButton(
            onClick = { showAdd = true },
            containerColor = ElectricBlue,
            contentColor = Navy,
            modifier = Modifier
                .align(Alignment.BottomEnd)
                .padding(20.dp)
        ) {
            Icon(Icons.Default.Add, contentDescription = "Add memory")
        }
    }

    if (showAdd) {
        MemoryDialog(
            title = "New memory",
            initial = "",
            confirmLabel = "Save",
            onConfirm = {
                viewModel.addMemory(it)
                showAdd = false
            },
            onDismiss = { showAdd = false }
        )
    }

    editing?.let { memory ->
        MemoryDialog(
            title = "Edit memory",
            initial = memory.text,
            confirmLabel = "Update",
            onConfirm = {
                viewModel.updateMemory(memory, it)
                editing = null
            },
            onDismiss = { editing = null }
        )
    }

    deleting?.let { memory ->
        AlertDialog(
            onDismissRequest = { deleting = null },
            containerColor = NavyCard,
            title = { Text("Delete memory?", color = TextMain) },
            text = { Text(memory.text, color = TextMuted) },
            confirmButton = {
                TextButton(onClick = {
                    viewModel.deleteMemory(memory)
                    deleting = null
                }) { Text("Delete") }
            },
            dismissButton = {
                TextButton(onClick = { deleting = null }) { Text("Cancel") }
            }
        )
    }
}

@Composable
private fun MemoryCard(memory: Memory, onEdit: () -> Unit, onDelete: () -> Unit) {
    val date = remember(memory.createdAt) {
        SimpleDateFormat("dd MMM yyyy, hh:mm a", Locale.getDefault()).format(Date(memory.createdAt))
    }
    Surface(
        color = NavyCard,
        shape = RoundedCornerShape(16.dp),
        border = BorderStroke(1.dp, BorderBlue)
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(start = 16.dp, top = 8.dp, bottom = 8.dp, end = 4.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Column(Modifier.weight(1f)) {
                Text(memory.text, color = TextMain)
                Text(date, color = TextMuted, style = MaterialTheme.typography.labelSmall)
            }
            IconButton(onClick = onEdit) {
                Icon(Icons.Default.Edit, contentDescription = "Edit", tint = Cyan)
            }
            IconButton(onClick = onDelete) {
                Icon(Icons.Default.Delete, contentDescription = "Delete", tint = ElectricBlue)
            }
        }
    }
}

@Composable
private fun MemoryDialog(
    title: String,
    initial: String,
    confirmLabel: String,
    onConfirm: (String) -> Unit,
    onDismiss: () -> Unit
) {
    var text by remember { mutableStateOf(initial) }
    AlertDialog(
        onDismissRequest = onDismiss,
        containerColor = NavyCard,
        title = { Text(title, color = TextMain) },
        text = {
            OutlinedTextField(
                value = text,
                onValueChange = { text = it },
                minLines = 2,
                colors = dragoFieldColors()
            )
        },
        confirmButton = {
            TextButton(onClick = { if (text.isNotBlank()) onConfirm(text.trim()) }) {
                Text(confirmLabel)
            }
        },
        dismissButton = { TextButton(onClick = onDismiss) { Text("Cancel") } }
    )
}
EOF
