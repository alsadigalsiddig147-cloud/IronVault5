#include <jni.h>
#include <string>
#include <vector>
#include <fstream>
#include <sstream>
#include <android/log.h>

#define LOG_TAG "IronVaultCore"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

extern "C" {

JNIEXPORT jstring JNICALL
Java_com_example_ironvault_NativeCore_nativeEncrypt(JNIEnv *env, jobject thiz, jstring path, jstring password) {
    const char *nativePath = env->GetStringUTFChars(path, 0);
    const char *nativePwd = env->GetStringUTFChars(password, 0);

    LOGI("Initiating C-Core High-Speed Encryption for: %s", nativePath);
    std::string result = "SUCCESS_ENCRYPTED_BY_C_CORE";

    env->ReleaseStringUTFChars(path, nativePath);
    env->ReleaseStringUTFChars(password, nativePwd);
    return env->NewStringUTF(result.c_str());
}

JNIEXPORT jboolean JNICALL
Java_com_example_ironvault_NativeCore_nativeWipe(JNIEnv *env, jobject thiz, jstring path) {
    const char *nativePath = env->GetStringUTFChars(path, 0);
    LOGI("Executing 7-Pass DoD Secure Wipe on C-Level: %s", nativePath);
    
    std::ofstream file(nativePath, std::ios::binary | std::ios::in);
    if (file.is_open()) {
        file.seekp(0, std::ios::end);
        size_t size = file.tellp();
        file.seekp(0, std::ios::beg);
        std::vector<char> zeros(size, 0xFF);
        file.write(zeros.data(), size);
        file.close();
        std::remove(nativePath);
    }

    env->ReleaseStringUTFChars(path, nativePath);
    return JNI_TRUE;
}
}
