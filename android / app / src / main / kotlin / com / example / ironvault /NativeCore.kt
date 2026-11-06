package com.example.ironvault

object NativeCore {
    init {
        // تحميل مكتبة C++ التي تم بناؤها
        System.loadLibrary("iron_core")
    }

    // دالة المسح العسكري فقط
    external fun nativeWipe(path: String): Boolean
}
