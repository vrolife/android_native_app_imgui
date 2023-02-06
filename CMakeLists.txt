cmake_minimum_required(VERSION 3.16)

if(ANDROID_PLATFORM)
    set(CMAKE_TOOLCHAIN_FILE $ENV{ANDROID_NDK_HOME}/build/cmake/android.toolchain.cmake)
endif()

project(native_app)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_C_STANDARD 11)

# Android
if (NOT ANDROID_SDK_HOME)
    set(ANDROID_SDK_HOME "${ANDROID_NDK}/../../")
endif()

if (NOT ANDROID_BUILD_TOOLS_DIR)
    file(GLOB __VERS "${ANDROID_SDK_HOME}/build-tools/*")
    list(POP_BACK __VERS __VER)
    set(ANDROID_BUILD_TOOLS_DIR ${__VER})
endif()

set(ANDROID_D8 ${ANDROID_BUILD_TOOLS_DIR}/d8)
set(ANDROID_AAPT2 ${ANDROID_BUILD_TOOLS_DIR}/aapt2)
set(ANDROID_APKSIGNER ${ANDROID_BUILD_TOOLS_DIR}/apksigner)
set(ANDROID_PALTFORM_DIR ${ANDROID_SDK_HOME}/platforms/${ANDROID_PLATFORM})
set(ANDROID_CLASSPATH ${ANDROID_PALTFORM_DIR}/android.jar)
string(REPLACE "android-" "" ANDROID_API_LEVEL "${ANDROID_PLATFORM}")

if (NOT EXISTS ${ANDROID_AAPT2})
    message(FATAL_ERROR "Android SDK build tools not found")
endif()

if (NOT EXISTS ${ANDROID_PALTFORM_DIR})
    message(FATAL_ERROR "Android SDK platform ${ANDROID_PLATFORM} not found")
endif()

set(APP_ASSETS_DIR ${CMAKE_CURRENT_SOURCE_DIR}/assets)
set(APP_RES_DIR ${CMAKE_CURRENT_SOURCE_DIR}/res)
set(APP_JAVA_DIR ${CMAKE_CURRENT_SOURCE_DIR}/java)
set(APP_CLASS_DIR ${CMAKE_CURRENT_BINARY_DIR}/classes)
set(APP_JNI_DIR ${CMAKE_CURRENT_BINARY_DIR}/jni)

file(GLOB_RECURSE __JAVA_FILES "${APP_JAVA_DIR}/*.java")

foreach(JAVA_FILE ${__JAVA_FILES})
    file(RELATIVE_PATH JAVA_FILE ${APP_JAVA_DIR} ${JAVA_FILE})
    string(REPLACE ".java" ".class" CLASS_FILE ${JAVA_FILE})
    list(APPEND __CLASS_FILES ${APP_CLASS_DIR}/${CLASS_FILE})
endforeach()

add_custom_command(
    OUTPUT
        ${CMAKE_CURRENT_BINARY_DIR}/apk/classes.dex
        ${APP_JNI_DIR}/org_napp_NativeApp.h
        ${APP_JNI_DIR}/org_napp_NativeService.h
    DEPENDS ${__JAVA_FILES}
    COMMAND javac 
        -bootclasspath ${ANDROID_CLASSPATH}
        -source 7
        -target 7
        -Xlint:-options
        -h ${APP_JNI_DIR}
        -d ${APP_CLASS_DIR}
        ${__JAVA_FILES}
    COMMAND ${ANDROID_D8}
        --classpath ${ANDROID_CLASSPATH}
        --output ${CMAKE_CURRENT_BINARY_DIR}/apk
        ${__CLASS_FILES}
)

# Native
add_library(imgui STATIC
    imgui/backends/imgui_impl_android.cpp
    imgui/backends/imgui_impl_opengl3.cpp
    imgui/imgui_demo.cpp
    imgui/imgui_draw.cpp
    imgui/imgui_tables.cpp
    imgui/imgui_widgets.cpp
    imgui/imgui.cpp
)
target_include_directories(imgui PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/imgui)
target_link_libraries(imgui PUBLIC EGL GLESv2)
target_compile_definitions(imgui PUBLIC -DIMGUI_IMPL_OPENGL_ES2=1)

add_library(napp MODULE
    ${APP_JNI_DIR}/org_napp_NativeApp.h
    ${APP_JNI_DIR}/org_napp_NativeService.h
    ${ANDROID_NDK}/sources/android/native_app_glue/android_native_app_glue.c
    native_app.cpp
    native_service.cpp
    napp.cpp
)
target_link_libraries(napp PRIVATE android log imgui)
target_include_directories(napp PRIVATE ${APP_JNI_DIR} ${ANDROID_NDK}/sources/android/native_app_glue)
set_target_properties(napp PROPERTIES LIBRARY_OUTPUT_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/apk/lib/${ANDROID_ABI})

if (CMAKE_BUILD_TYPE STREQUAL Release)
    target_link_options(napp PRIVATE -s)
endif()

# Resource
file(GLOB_RECURSE __ASSETS_FILES "${APP_ASSETS_DIR}/*")
file(GLOB_RECURSE __RES_FILES "${APP_RES_DIR}/*")

add_custom_command(
    OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/intermediate-resource.zip
    DEPENDS ${__RES_FILES}
    COMMAND ${ANDROID_AAPT2} compile 
        --dir ${APP_RES_DIR}
        -o ${CMAKE_CURRENT_BINARY_DIR}/intermediate-resource.zip
)

add_custom_command(
    OUTPUT
        ${CMAKE_CURRENT_BINARY_DIR}/apk/resources.arsc
        ${CMAKE_CURRENT_BINARY_DIR}/apk/AndroidManifest.xml
    DEPENDS
        ${CMAKE_CURRENT_BINARY_DIR}/intermediate-resource.zip
        ${CMAKE_CURRENT_SOURCE_DIR}/AndroidManifest.xml
        ${__ASSETS_FILES} 
    COMMAND ${ANDROID_AAPT2} link 
        -I ${ANDROID_SDK_HOME}/platforms/${ANDROID_PLATFORM}/android.jar
        -A ${APP_ASSETS_DIR}
        ${CMAKE_CURRENT_BINARY_DIR}/intermediate-resource.zip
        --manifest ${CMAKE_CURRENT_SOURCE_DIR}/AndroidManifest.xml
        -o ${CMAKE_CURRENT_BINARY_DIR}/apk
        --output-to-dir
)

add_custom_command(
    OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/app.apk
    DEPENDS napp
        ${CMAKE_CURRENT_BINARY_DIR}/apk/resources.arsc
        ${CMAKE_CURRENT_BINARY_DIR}/apk/AndroidManifest.xml
        ${CMAKE_CURRENT_BINARY_DIR}/apk/classes.dex
    WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/apk
    COMMAND ${CMAKE_COMMAND} -E tar cf
        ${CMAKE_CURRENT_BINARY_DIR}/app.apk 
        --format=zip
        .
)

add_custom_command(
    OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/app_debug.ks
    COMMAND keytool -genkey -v 
        -keystore ${CMAKE_CURRENT_BINARY_DIR}/app_debug.ks 
        -alias androiddebugkey
        -keyalg RSA 
        -keysize 2048 
        -validity 10000
        -keypass android
        -storepass android
        -dname CN=android
)

add_custom_command(
    OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/app_debug.apk
    DEPENDS ${CMAKE_CURRENT_BINARY_DIR}/app.apk ${CMAKE_CURRENT_BINARY_DIR}/app_debug.ks
    COMMAND ${ANDROID_APKSIGNER} sign 
        --ks ${CMAKE_CURRENT_BINARY_DIR}/app_debug.ks
        --ks-pass pass:android
        --out ${CMAKE_CURRENT_BINARY_DIR}/app_debug.apk
        --min-sdk-version ${ANDROID_API_LEVEL}
        ${CMAKE_CURRENT_BINARY_DIR}/app.apk 
)

add_custom_target(sign_apk_debug DEPENDS ${CMAKE_CURRENT_BINARY_DIR}/app_debug.apk)

add_custom_target(install_apk_debug
    DEPENDS sign_apk_debug
    COMMAND adb install ${CMAKE_CURRENT_BINARY_DIR}/app_debug.apk
)
