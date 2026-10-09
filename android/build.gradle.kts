group = "com.permate.attribution.permate_attribution"
version = "3.2.1-preview.37888476087"

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
                maven { url = uri("https://sdk.dev.pmcdn1.com/maven/previews/ffed40d538d495adfa45214cba3610f4afd38e0f-37886593916-1/") }
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
