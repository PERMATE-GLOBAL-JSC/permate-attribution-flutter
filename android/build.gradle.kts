group = "com.permate.attribution.permate_attribution"
version = "3.2.0-preview.38352787576"

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.allprojects {
    repositories {
        exclusiveContent {
            forRepository {
                maven { url = uri("https://sdk.dev.pmcdn1.com/maven/previews/5e6f3ebdf14350bc53ca852aba1dbf3c03f7ebce-38352218669-1/") }
            }
            filter { includeGroup("com.permate") }
        }
    }
}

plugins {
    id("com.android.library")
}

// AGP 9 ships built-in Kotlin (registers the `kotlin` extension and rejects the kotlin-android plugin);
// AGP 8, or AGP 9 with android.builtInKotlin=false, needs the host's Kotlin plugin applied here.
if (extensions.findByName("kotlin") == null) {
    apply(plugin = "org.jetbrains.kotlin.android")
}

android {
    namespace = "com.permate.attribution.permate_attribution"

    compileSdk = 36

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    sourceSets {
        getByName("main") {
            java.srcDirs("src/main/kotlin")
        }
        getByName("test") {
            java.srcDirs("src/test/kotlin")
        }
    }

    defaultConfig {
        minSdk = 23
    }

    testOptions {
        unitTests {
            isIncludeAndroidResources = true
            all {
                it.useJUnitPlatform()

                it.outputs.upToDateWhen { false }

                it.testLogging {
                    events("passed", "skipped", "failed", "standardOut", "standardError")
                    showStandardStreams = true
                }
            }
        }
    }
}

dependencies {
    api("com.permate:permate-attribution") { version { strictly("3.2.0") } }
    testImplementation("org.jetbrains.kotlin:kotlin-test")
    testImplementation("org.mockito:mockito-core:5.0.0")
}

// Task-level jvmTarget (not `kotlinOptions` / `jvmToolchain`): must match Java 17 even when the host
// app's Kotlin/AGP ignores `android.kotlinOptions` or the build JDK is newer (e.g. 21).
tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
    compilerOptions {
        jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
    }
}
