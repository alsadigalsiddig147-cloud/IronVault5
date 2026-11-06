package com.example.ironvault

object NativeCore {
    init {
        // تحميل مكتبة C++ التي تم بناؤها
        System.loadLibrary("iron_core")
    }

    // تعريف الدوال التي تم بناؤها في C++
    external fun nativeEncrypt(path: String, password: String): String
    external fun nativeWipe(path: String): Boolean
}
