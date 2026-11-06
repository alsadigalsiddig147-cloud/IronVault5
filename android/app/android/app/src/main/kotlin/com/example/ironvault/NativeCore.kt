package com.example.ironvault

object NativeCore {
    init {
        System.loadLibrary("iron_core")
    }
    external fun nativeEncrypt(path: String, password: String): String
    external fun nativeWipe(path: String): Boolean
}
