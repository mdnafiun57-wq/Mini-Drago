D=app/src/main/java/com/drago/offlinememory
mkdir -p $D/data $D/domain $D/viewmodel $D/ui/theme
mkdir -p app/src/main/res/values app/src/main/res/drawable

cat > settings.gradle.kts <<'EOF'
pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}
dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
    }
}
rootProject.name = "DRAGO Offline Memory"
include(":app")
EOF

cat > build.gradle.kts <<'EOF'
plugins {
    id("com.android.application") version "8.7.3" apply false
    id("org.jetbrains.kotlin.android") version "2.0.21" apply false
    id("org.jetbrains.kotlin.plugin.compose") version "2.0.21" apply false
    id("com.google.devtools.ksp") version "2.0.21-1.0.28" apply false
}
EOF

cat > gradle.properties <<'EOF'
org.gradle.jvmargs=-Xmx3g -Dfile.encoding=UTF-8
android.useAndroidX=true
kotlin.code.style=official
android.nonTransitiveRClass=true
EOF

cat > app/build.gradle.kts <<'EOF'
plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.compose")
    id("com.google.devtools.ksp")
}

android {
    namespace = "com.drago.offlinememory"
    compileSdk = 35

    defaultConfig {
        applicationId = "com.drago.offlinememory"
        minSdk = 24
        targetSdk = 35
        versionCode = 1
        versionName = "1.0"
    }

    buildTypes {
        release {
            isMinifyEnabled = false
        }
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions {
        jvmTarget = "17"
    }
    buildFeatures {
        compose = true
    }
}

dependencies {
    implementation("androidx.core:core-ktx:1.15.0")
    implementation("androidx.activity:activity-compose:1.9.3")
    implementation("androidx.lifecycle:lifecycle-viewmodel-compose:2.8.7")
    implementation("androidx.lifecycle:lifecycle-runtime-compose:2.8.7")

    val composeBom = platform("androidx.compose:compose-bom:2024.12.01")
    implementation(composeBom)
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.foundation:foundation")
    implementation("androidx.compose.material3:material3")

    val roomVersion = "2.6.1"
    implementation("androidx.room:room-runtime:$roomVersion")
    implementation("androidx.room:room-ktx:$roomVersion")
    ksp("androidx.room:room-compiler:$roomVersion")
}
EOF

cat > app/src/main/AndroidManifest.xml <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <application
        android:allowBackup="true"
        android:icon="@drawable/ic_launcher"
        android:label="@string/app_name"
        android:supportsRtl="true"
        android:theme="@style/Theme.DragoOfflineMemory">
        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:theme="@style/Theme.DragoOfflineMemory">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>
    </application>
</manifest>
EOF

cat > app/src/main/res/values/strings.xml <<'EOF'
<resources>
    <string name="app_name">DRAGO Offline Memory</string>
</resources>
EOF

cat > app/src/main/res/values/themes.xml <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <style name="Theme.DragoOfflineMemory" parent="android:Theme.Material.NoActionBar">
        <item name="android:windowBackground">#050B1A</item>
        <item name="android:statusBarColor">@android:color/transparent</item>
        <item name="android:navigationBarColor">@android:color/transparent</item>
    </style>
</resources>
EOF

cat > app/src/main/res/drawable/ic_launcher.xml <<'EOF'
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="108dp"
    android:height="108dp"
    android:viewportWidth="108"
    android:viewportHeight="108">
    <path android:fillColor="#050B1A" android:pathData="M0,0h108v108h-108z"/>
    <path android:fillColor="#00B4FF" android:pathData="M54,54m-34,0a34,34 0,1 1,68 0a34,34 0,1 1,-68 0"/>
    <path android:fillColor="#050B1A" android:pathData="M54,54m-22,0a22,22 0,1 1,44 0a22,22 0,1 1,-44 0"/>
    <path android:fillColor="#00E5FF" android:pathData="M54,54m-9,0a9,9 0,1 1,18 0a9,9 0,1 1,-18 0"/>
</vector>
EOF

cat > $D/data/Memory.kt <<'EOF'
package com.drago.offlinememory.data

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "memories")
data class Memory(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val text: String,
    val createdAt: Long = System.currentTimeMillis()
)
EOF

cat > $D/data/MemoryDao.kt <<'EOF'
package com.drago.offlinememory.data

import androidx.room.Dao
import androidx.room.Delete
import androidx.room.Insert
import androidx.room.Query
import androidx.room.Update
import kotlinx.coroutines.flow.Flow

@Dao
interface MemoryDao {

    @Query("SELECT * FROM memories WHERE text LIKE '%' || :query || '%' ORDER BY createdAt DESC")
    fun search(query: String): Flow<List<Memory>>

    @Query("SELECT * FROM memories")
    suspend fun getAll(): List<Memory>

    @Insert
    suspend fun insert(memory: Memory): Long

    @Update
    suspend fun update(memory: Memory)

    @Delete
    suspend fun delete(memory: Memory)
}
EOF

cat > $D/data/AppDatabase.kt <<'EOF'
package com.drago.offlinememory.data

import android.content.Context
import androidx.room.Database
import androidx.room.Room
import androidx.room.RoomDatabase

@Database(entities = [Memory::class], version = 1, exportSchema = false)
abstract class AppDatabase : RoomDatabase() {

    abstract fun memoryDao(): MemoryDao

    companion object {
        @Volatile
        private var INSTANCE: AppDatabase? = null

        fun get(context: Context): AppDatabase =
            INSTANCE ?: synchronized(this) {
                INSTANCE ?: Room.databaseBuilder(
                    context.applicationContext,
                    AppDatabase::class.java,
                    "drago_memory.db"
                ).build().also { INSTANCE = it }
            }
    }
}
EOF

cat > $D/data/MemoryRepository.kt <<'EOF'
package com.drago.offlinememory.data

import com.drago.offlinememory.domain.MemoryAnswerer
import kotlinx.coroutines.flow.Flow

class MemoryRepository(private val dao: MemoryDao) {

    fun search(query: String): Flow<List<Memory>> = dao.search(query.trim())

    suspend fun add(text: String) {
        dao.insert(Memory(text = text.trim()))
    }

    suspend fun update(memory: Memory, newText: String) {
        dao.update(memory.copy(text = newText.trim()))
    }

    suspend fun delete(memory: Memory) {
        dao.delete(memory)
    }

    suspend fun answer(question: String): String =
        MemoryAnswerer.answer(question, dao.getAll())
}
EOF
