allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// --- BUILD DIRECTORY REDIRECTION ---
val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

// --- PLUGIN COMPATIBILITY INJECTION ---
// This block fixes the "Namespace not specified" error for older plugins like tflite_flutter
subprojects {
    afterEvaluate {
        if (project.hasProperty("android")) {
            val android = project.extensions.getByName("android") as com.android.build.gradle.BaseExtension
            // If the plugin hasn't defined a namespace, use its project group ID
            if (android.namespace == null) {
                android.namespace = project.group.toString()
            }
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}