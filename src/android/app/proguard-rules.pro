# 抑制 javax.annotation 相关的警告
-dontwarn javax.annotation.Nullable
-dontwarn javax.annotation.concurrent.GuardedBy

# 抑制 javax.lang.model 相关的警告
-dontwarn javax.lang.model.element.Modifier

# 保留 javax.annotation 包中的所有类
-keep class javax.annotation.** { *; }

# 保留 javax.lang.model 包中的所有类
-keep class javax.lang.model.** { *; }

# 保留 Flutter 相关的类
-keep class io.flutter.** { *; }
-dontwarn io.flutter.**


