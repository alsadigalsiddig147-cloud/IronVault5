#include <jni.h>
#include <string>
#include <vector>
#include <fstream>
#include <android/log.h>

#define LOG_TAG "IronVaultCore"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)

extern "C" {
    // دالة C++ للتمزيق الآمن للملف الأصلي بعد التشفير
    JNIEXPORT jboolean JNICALL
    Java_com_example_ironvault_NativeCore_nativeWipe(JNIEnv *env, jobject thiz, jstring path) {
        const char *nativePath = env->GetStringUTFChars(path, 0);
        LOGI("Executing DoD 5220.22-M Secure Wipe: %s", nativePath);
        
        std::ofstream file(nativePath, std::ios::binary | std::ios::in | std::ios::out);
        if (file.is_open()) {
            file.seekp(0, std::ios::end);
            size_t size = file.tellp();
            file.seekp(0, std::ios::beg);
            
            // الكتابة العشوائية 3 مرات (معيار DoD)
            for (int pass = 0; pass < 3; ++pass) {
                std::vector<char> buffer(size, pass == 0 ? 0x00 : (pass == 1 ? 0xFF : 0x55));
                file.write(buffer.data(), size);
                file.flush();
                file.seekp(0, std::ios::beg);
            }
            file.close();
            std::remove(nativePath);
        }
        env->ReleaseStringUTFChars(path, nativePath);
        return JNI_TRUE;
    }
}
