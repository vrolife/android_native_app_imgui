#include <stdlib.h>
#include <string.h>
#include <android/native_activity.h>
#include <android/native_window_jni.h>
#include <android/input.h>
#include <android/asset_manager_jni.h>

#include <string>

#include "org_napp_NativeService.h"

struct NativeService {
    ANativeActivity activity;
    ANativeActivityCallbacks callbacks;

    std::string internal_data_path;
    std::string external_data_path;
    std::string obb_path;

    NativeService(jobject self) {
        memset(&activity, 0, sizeof(ANativeActivity));
        memset(&callbacks, 0, sizeof(ANativeActivityCallbacks));
    }

    ~NativeService() {

    }
};

static std::string jstring_to_std_string(JNIEnv* jenv, jstring str)
{
    std::string s;
    auto size = jenv->GetStringUTFLength(str);
    s.resize(size);
    jenv->GetStringUTFRegion(str, 0, size, s.data());
    return s;
}

JNIEXPORT jlong JNICALL 
Java_org_napp_NativeService_native_1on_1create(
    JNIEnv *jenv, jobject self, jobject asset_manager,
    jstring internal_data_path, jstring external_data_path, 
    jstring obb_path,
    jint sdk_version)
{
    auto* service = new NativeService(self);
    service->activity.callbacks = &service->callbacks;
    
    jenv->GetJavaVM(&service->activity.vm);
    
    service->activity.env = jenv;
    service->activity.clazz = self;
    
    service->internal_data_path = jstring_to_std_string(jenv, internal_data_path);
    service->external_data_path = jstring_to_std_string(jenv, external_data_path);
    service->activity.internalDataPath = service->internal_data_path.c_str();
    service->activity.externalDataPath = service->external_data_path.c_str();

    service->activity.sdkVersion = sdk_version;

    service->activity.assetManager = AAssetManager_fromJava(jenv, asset_manager);

    service->obb_path = jstring_to_std_string(jenv, obb_path);
    service->activity.obbPath = service->obb_path.c_str();

    ANativeActivity_onCreate(&service->activity, nullptr, 0);

    if (service->activity.callbacks->onStart) {
        service->activity.callbacks->onStart(&service->activity);
    }

    return static_cast<jlong>(reinterpret_cast<uintptr_t>(service));
}

JNIEXPORT void JNICALL 
Java_org_napp_NativeService_native_1on_1destroy(JNIEnv *, jobject, jlong ptr)
{
    auto* service = reinterpret_cast<NativeService*>(static_cast<uintptr_t>(ptr));
    if (service->activity.callbacks->onStop) {
        service->activity.callbacks->onStop(&service->activity);
    }
    if (service->activity.callbacks->onDestroy) {
        service->activity.callbacks->onDestroy(&service->activity);
    }
    delete service;
}

JNIEXPORT void JNICALL
Java_org_napp_NativeService_native_1on_1low_1memory(JNIEnv *, jobject, jlong ptr)
{
    auto* service = reinterpret_cast<NativeService*>(static_cast<uintptr_t>(ptr));
    if (service->activity.callbacks->onLowMemory) {
        service->activity.callbacks->onLowMemory(&service->activity);
    }
}

JNIEXPORT void JNICALL Java_org_napp_NativeService_native_1surface_1created
  (JNIEnv *jenv, jobject, jlong ptr, jobject surface)
{
    auto* service = reinterpret_cast<NativeService*>(static_cast<uintptr_t>(ptr));
    if (service->activity.callbacks->onNativeWindowCreated) {
        service->activity.callbacks->onNativeWindowCreated(&service->activity, ANativeWindow_fromSurface(jenv, surface));
    }
}

JNIEXPORT void JNICALL Java_org_napp_NativeService_native_1surface_1changed
  (JNIEnv *jenv, jobject, jlong ptr, jobject surface, jint, jint, jint)
{
    auto* service = reinterpret_cast<NativeService*>(static_cast<uintptr_t>(ptr));
    if (service->activity.callbacks->onNativeWindowResized) {
        service->activity.callbacks->onNativeWindowResized(&service->activity, ANativeWindow_fromSurface(jenv, surface));
    }
}

JNIEXPORT void JNICALL Java_org_napp_NativeService_native_1surface_1destroyed
  (JNIEnv *jenv, jobject, jlong ptr, jobject surface)
{
    auto* service = reinterpret_cast<NativeService*>(static_cast<uintptr_t>(ptr));
    if (service->activity.callbacks->onNativeWindowDestroyed) {
        service->activity.callbacks->onNativeWindowDestroyed(&service->activity, ANativeWindow_fromSurface(jenv, surface));
    }
}
