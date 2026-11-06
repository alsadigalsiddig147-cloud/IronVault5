package com.example.ironvault

object NativeCore {
    init {
        // تحميل مكتبة C++ (iron_core.so)
        System.loadLibrary("iron_core")
    }

    // دالة المسح العسكري (7 تمريرات) - التشفير يتم في Dart
    external fun nativeWipe(path: String): Boolean
}
