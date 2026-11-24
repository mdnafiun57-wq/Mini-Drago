cat > $D/domain/CommandParser.kt <<'EOF'
package com.drago.offlinememory.domain

sealed interface Command {
    data class Save(val content: String) : Command
    data class Ask(val question: String) : Command
}

object CommandParser {

    private val saveStarts = listOf(
        "remember that", "remember", "save that", "save", "note that", "note",
        "মনে রাখো যে", "মনে রাখো", "মনে রাখুন", "মনে রেখো", "মনে রাখবে"
    ).sortedByDescending { it.length }

    private val saveEnds = listOf("মনে রাখো", "মনে রাখুন", "মনে রেখো", "মনে রাখবে")

    private val englishQuestionWords = setOf(
        "what", "who", "whom", "where", "when", "which", "how", "why",
        "do", "does", "did", "is", "are", "can", "tell", "show", "find"
    )

    private val bengaliQuestionWords = setOf(
        "কি", "কী", "কে", "কাকে", "কোথায়", "কবে", "কখন",
        "কোন", "কত", "কেন", "কেমন", "বলো", "বলুন"
    )

    private val bengaliSplit = Regex("[^\\p{L}\\p{M}]+")

    fun parse(input: String): Command {
        val text = input.trim()

        for (p in saveStarts) {
            if (text.startsWith(p, ignoreCase = true) &&
                (text.length == p.length || text[p.length].isWhitespace() || text[p.length] == ':')
            ) {
                var content = text.substring(p.length).trim().trimStart(':').trim()
                for (w in listOf("that ", "যে ")) {
                    if (content.startsWith(w, ignoreCase = true)) {
                        content = content.substring(w.length).trim()
                    }
                }
                if (content.isNotBlank()) return Command.Save(content)
            }
        }

        val trimmedEnd = text.trimEnd('.', '!', '।', ' ')
        for (s in saveEnds) {
            if (trimmedEnd.endsWith(s)) {
                val content = trimmedEnd.removeSuffix(s).trim()
                if (content.isNotBlank()) return Command.Save(content)
            }
        }

        val firstWord = text.lowercase().split(Regex("\\s+")).firstOrNull() ?: ""
        val isQuestion = text.endsWith("?") || text.endsWith("？") ||
            firstWord in englishQuestionWords ||
            text.split(bengaliSplit).any { it in bengaliQuestionWords }
        if (isQuestion) return Command.Ask(text)

        return Command.Save(text)
    }
}
EOF

cat > $D/domain/MemoryAnswerer.kt <<'EOF'
package com.drago.offlinememory.domain

import com.drago.offlinememory.data.Memory

object MemoryAnswerer {

    private val basicStop = setOf(
        "what", "whats", "is", "are", "was", "were", "my", "me", "i", "the", "an",
        "of", "to", "in", "on", "at", "and", "for", "do", "does", "did", "tell",
        "about", "who", "whom", "where", "when", "which", "how", "why", "your",
        "you", "am", "it", "this", "that", "please", "show", "find", "give",
        "know", "remember", "can", "could", "should", "have", "has", "there",
        "কি", "কী", "কে", "কাকে", "কোথায়", "কবে", "কখন", "কোন", "কত", "কেন",
        "কেমন", "আমার", "আমি", "আমাকে", "বলো", "বলুন", "বল", "হয়", "হল", "হলো",
        "এর", "তার", "কিনা", "আছে", "ছিল", "মনে"
    )

    private val weakWords = setOf("name", "number", "নাম", "নম্বর")

    private val tokenSplit = Regex("[^\\p{L}\\p{M}\\p{N}]+")
    private val bengaliSuffixes = listOf("গুলো", "গুলি", "ের", "কে", "তে", "টি", "টা", "র", "ে")

    private fun rawTokens(text: String): List<String> =
        text.lowercase().split(tokenSplit).filter { it.length >= 2 }

    private fun stem(word: String): String {
        for (s in bengaliSuffixes) {
            if (word.endsWith(s) && word.length > s.length + 1) return word.dropLast(s.length)
        }
        if (word.length > 3 && word.endsWith("s") && !word.endsWith("ss")) return word.dropLast(1)
        return word
    }

    private fun keywords(question: String): List<String> {
        val raw = rawTokens(question).filter { it !in basicStop }
        val strong = raw.filter { it !in weakWords }
        return (if (strong.isNotEmpty()) strong else raw).map(::stem).distinct()
    }

    private fun same(a: String, b: String): Boolean =
        a == b || (a.length >= 3 && b.length >= 3 && (a.startsWith(b) || b.startsWith(a)))

    private fun score(memory: Memory, keywords: List<String>): Int {
        val memoryTokens = rawTokens(memory.text).map(::stem)
        return keywords.count { k -> memoryTokens.any { same(k, it) } }
    }

    private fun hasBengali(text: String) = text.any { it in '\u0980'..'\u09FF' }

    fun answer(question: String, memories: List<Memory>): String {
        val notFound = if (hasBengali(question)) {
            "আমার কাছে এটি সংরক্ষিত নেই।"
        } else {
            "I don't have that saved yet."
        }

        val kws = keywords(question)
        if (kws.isEmpty() || memories.isEmpty()) return notFound

        val scored = memories.map { it to score(it, kws) }.filter { it.second > 0 }
        if (scored.isEmpty()) return notFound

        val best = scored.maxOf { it.second }
        return scored
            .filter { it.second == best }
            .sortedByDescending { it.first.createdAt }
            .take(3)
            .joinToString("\n") { toSecondPerson(it.first.text) }
    }

    private fun toSecondPerson(text: String): String {
        var t = text.trim().trimEnd('.', '।')
        t = t.replace(Regex("\\bI am\\b|\\bI'm\\b", RegexOption.IGNORE_CASE), "you are")
        t = t.replace(Regex("\\bmy\\b", RegexOption.IGNORE_CASE), "your")
        t = t.replace(Regex("\\bmine\\b", RegexOption.IGNORE_CASE), "yours")
        t = t.replace(Regex("\\bmyself\\b", RegexOption.IGNORE_CASE), "yourself")
        t = t.replace(Regex("\\bme\\b", RegexOption.IGNORE_CASE), "you")
        t = t.replace(Regex("\\bI\\b"), "you")
        t = t.replace("আমাকে", "আপনাকে").replace("আমার", "আপনার").replace("আমি", "আপনি")
        t = t.replaceFirstChar { it.uppercase() }
        return t + if (hasBengali(t)) "।" else "."
    }
}
EOF
