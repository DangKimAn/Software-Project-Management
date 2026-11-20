import com.android.build.api.variant.LibraryAndroidComponentsExtension

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)

    if (project.name == "file_picker") {
        pluginManager.withPlugin("com.android.library") {
            extensions.configure<LibraryAndroidComponentsExtension> {
                finalizeDsl { android ->
                    // file_picker 8.x uses SDK 34, but its lifecycle dependency requires 36.
                    android.compileSdk = maxOf(android.compileSdk ?: 36, 36)
                }
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
