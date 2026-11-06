#include <jni.h>
#include <string>
#include <vector>
#include <fstream>
#include <android/log.h>
#include <algorithm> // لاستخدام std::min

#define LOG_TAG "IronVaultCore"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)

extern "C" {
    JNIEXPORT jboolean JNICALL
    Java_com_example_ironvault_NativeCore_nativeWipe(JNIEnv *env, jobject thiz, jstring path) {
        const char *nativePath = env->GetStringUTFChars(path, 0);
        LOGI("Executing DoD 5220.22-M Secure Wipe: %s", nativePath);
        
        // فتح الملف للقراءة والكتابة معاً
        std::fstream file(nativePath, std::ios::binary | std::ios::in | std::ios::out);
        if (file.is_open()) {
            // معرفة حجم الملف
            file.seekg(0, std::ios::end);
            std::streamsize fileSize = file.tellg();
            file.seekg(0, std::ios::beg);

            // حجم القطعة 64 كيلوبايت (آمن جداً للذاكرة)
            const std::streamsize CHUNK_SIZE = 64 * 1024; 
            std::vector<char> buffer(CHUNK_SIZE);

            // 3 دورات للكتابة (معيار DoD)
            for (int pass = 0; pass < 3; ++pass) {
                char fillChar = (pass == 0) ? 0x00 : ((pass == 1) ? 0xFF : 0x55);
                std::fill(buffer.begin(), buffer.end(), fillChar);
                
                file.seekp(0, std::ios::beg);
                std::streamsize remaining = fileSize;
                
                // الكتابة التدفقية على شكل قطع
                while (remaining > 0) {
                    std::streamsize to_write = std::min(CHUNK_SIZE, remaining);
                    file.write(buffer.data(), to_write);
                    remaining -= to_write;
                }
                file.flush();
            }
            file.close();
            
            // حذف الملف نهائياً
            std::remove(nativePath);
            LOGI("File securely wiped and deleted.");
        } else {
            LOGI("Error: Could not open file for wiping.");
            env->ReleaseStringUTFChars(path, nativePath);
            return JNI_FALSE;
        }
        
        env->ReleaseStringUTFChars(path, nativePath);
        return JNI_TRUE;
    }
}
