allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

// Force compileSdk 36 on every Android library (file_picker etc. still ship 34).
subprojects {
    afterEvaluate {
        val ext = extensions.findByName("android") ?: return@afterEvaluate
        try {
            val clazz = ext.javaClass
            val m =
                clazz.methods.firstOrNull { it.name == "setCompileSdk" && it.parameterCount == 1 }
                    ?: clazz.methods.firstOrNull {
                        it.name == "setCompileSdkVersion" && it.parameterCount == 1
                    }
            if (m != null) {
                val p = m.parameterTypes[0]
                when {
                    p == Integer.TYPE || p == Integer::class.java -> m.invoke(ext, 36)
                    p == String::class.java -> m.invoke(ext, "36")
                    else -> m.invoke(ext, 36)
                }
            }
        } catch (_: Throwable) {
            // Best-effort override for third-party Flutter plugins.
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
