//plugins {
//    id("com.android.application")
//    id("kotlin-android")
//    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
//    id("dev.flutter.flutter-gradle-plugin")
//}
//
//android {
//    namespace = "com.fxck.washer.washer"
//    compileSdk = flutter.compileSdkVersion
////    ndkVersion = flutter.ndkVersion
//    ndkVersion = "27.0.12077973"
//
//    compileOptions {
//        sourceCompatibility = JavaVersion.VERSION_11
//        targetCompatibility = JavaVersion.VERSION_11
//    }
//
//    kotlinOptions {
//        jvmTarget = JavaVersion.VERSION_11.toString()
//    }
//
//    defaultConfig {
//        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
//        applicationId = "com.fxck.washer.washer"
//        // You can update the following values to match your application needs.
//        // For more information, see: https://flutter.dev/to/review-gradle-config.
//        minSdk = flutter.minSdkVersion
//        targetSdk = flutter.targetSdkVersion
//        versionCode = flutter.versionCode
//        versionName = flutter.versionName
//
//        ndk {
//            // 指定仅编译 arm64-v8a
//            abiFilters.add("arm64-v8a")
//        }
//
//    }
//
//    dependencies {
//        // 添加 Error Prone 注解库
//        implementation("com.google.errorprone:error_prone_annotations:2.23.0")
//
//        // 添加 javax.annotation 库
//        implementation("javax.annotation:javax.annotation-api:1.3.2")
//    }
//
////    buildTypes {
////        release {
////            // TODO: Add your own signing config for the release build.
////            // Signing with the debug keys for now, so `flutter run --release` works.
////            signingConfig = signingConfigs.getByName("debug")
////        }
////    }
//
//    buildTypes {
//        getByName("release") {
//            isMinifyEnabled = true
//            proguardFiles(
//                getDefaultProguardFile("proguard-android-optimize.txt"),
//                "proguard-rules.pro"
//            )
//        }
//    }
//
//    compileOptions {
//        sourceCompatibility = JavaVersion.VERSION_11
//        targetCompatibility = JavaVersion.VERSION_11
//    }
//
//    kotlinOptions {
//        jvmTarget = "11"
//    }
//}
//
//flutter {
//    source = "../.."
//}


plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.fxck.washer.washer"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        applicationId = "com.fxck.washer.washer"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

//        ndk {
//            abiFilters.add("arm64-v8a") //只包含 arm64-v8a 架构
//            abiFilters.add("x86_64")  // 添加这一行支持模拟器
//        }

        ndk {
            // 移除 abiFilters 完全，默认会构建所有架构
            // abiFilters.clear()

            // # 发布时仅构建 arm64（减小包体积）
            // flutter build apk --release --target-platform=android-arm64 --no-tree-shake-icons
        }



    }

    dependencies {
        implementation("com.google.errorprone:error_prone_annotations:2.23.0")
        implementation("javax.annotation:javax.annotation-api:1.3.2")
    }

    signingConfigs {
        create("release") {
            storeFile = file("/YOUR JKS FILE PATH/upload-keystore.jks") // 密钥文件路径（相对项目根目录）
            storePassword = "YOUR JKS FILE storePassword"  // 密钥库密码
            keyAlias = "YOUR JKS FILE ALIAS"                   // 密钥别名
            keyPassword = "YOUR JKS FILE keyPassword"     // 密钥密码
        }
    }

    buildTypes {
        getByName("release") {
            signingConfig = signingConfigs.getByName("release") // 应用签名配置
            isMinifyEnabled = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

flutter {
    source = "../.."
}