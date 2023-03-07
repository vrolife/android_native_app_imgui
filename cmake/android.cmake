set(__DEFAULT_NDK "25.1.8937393")
set(__DEFAULT_BUILD_TOOLS "33.0.2")

# Check SDK

if(NOT ANDROID_SDK_HOME)
    set(ANDROID_SDK_HOME $ENV{ANDROID_SDK_HOME})
endif()

if (NOT ANDROID_NDK_HOME)
    set(ANDROID_NDK_HOME $ENV{ANDROID_NDK_HOME})
endif()

if(NOT ANDROID_SDK_HOME AND ANDROID_NDK_HOME AND EXISTS ${ANDROID_NDK_HOME}/../../build-tools)
    set(ANDROID_SDK_HOME "${ANDROID_NDK_HOME}/../..")
endif()

if(NOT ANDROID_SDK_HOME)
    message(FATAL_ERROR "Missing ANDROID_SDK_HOME")
endif()

if (NOT ANDROID_BUILD_TOOLS_DIR)
    file(GLOB __VERS "${ANDROID_SDK_HOME}/build-tools/*")
    list(POP_BACK __VERS __VER)
    set(ANDROID_BUILD_TOOLS_DIR ${__VER})
endif()

if (NOT ANDROID_BUILD_TOOLS_DIR)
    message(STATUS "Downloading build-tools;${__DEFAULT_BUILD_TOOLS}")
    execute_process(
        COMMAND ${ANDROID_SDK_HOME}/cmdline-tools/latest/bin/sdkmanager "'build-tools;${__DEFAULT_BUILD_TOOLS}'"
    )
    set(ANDROID_BUILD_TOOLS_DIR "${ANDROID_SDK_HOME}/build-tools/${__DEFAULT_BUILD_TOOLS}")
endif()

set(ANDROID_D8 ${ANDROID_BUILD_TOOLS_DIR}/d8)
set(ANDROID_AAPT2 ${ANDROID_BUILD_TOOLS_DIR}/aapt2)
set(ANDROID_APKSIGNER ${ANDROID_BUILD_TOOLS_DIR}/apksigner)

if(NOT ANDROID_D8 OR NOT ANDROID_AAPT2 OR NOT ANDROID_APKSIGNER)
    message(FATAL_ERROR "Invalid build tools ${ANDROID_BUILD_TOOLS_DIR}")
endif()

# Check NDK

if(NOT ANDROID_NDK_HOME)
    file(GLOB __VERS "${ANDROID_SDK_HOME}/ndk/*")
    list(POP_BACK __VERS __VER)
    set(ANDROID_NDK_HOME ${__VER})
endif()

if (NOT ANDROID_NDK_HOME)
    message(STATUS "Downloading ndk;${__DEFAULT_NDK}")
    execute_process(
        COMMAND ${ANDROID_SDK_HOME}/cmdline-tools/latest/bin/sdkmanager "'ndk;${__DEFAULT_NDK}'"
    )
    set(ANDROID_NDK_HOME "${ANDROID_SDK_HOME}/ndk/${__DEFAULT_NDK}")
endif()

if(NOT EXISTS ${ANDROID_NDK_HOME}/ndk-build)
    message(FATAL_ERROR "Invalid NDK ${ANDROID_NDK_HOME}")
endif()

# Check platform

if(NOT ANDROID_PLATFORM)
    message(WARNING "Missing ANDROID_PLATFORM, use \"android-26\" as default")
    set(ANDROID_PLATFORM android-26)
endif()

if(NOT ANDROID_ABI)
    message(WARNING "Missing ANDROID_ABI, use \"arm64-v8a\" as default")
    set(ANDROID_ABI arm64-v8a)
endif()

if(NOT ANDROID_STL)
    set(ANDROID_STL c++_static)
endif()

if(ANDROID_PLATFORM MATCHES "android-[0-9]+")
    string(REPLACE "android-" "" ANDROID_API_LEVEL "${ANDROID_PLATFORM}")
else()
    set(ANDROID_API_LEVEL ${ANDROID_PLATFORM})
    set(ANDROID_PLATFORM "android-${ANDROID_PLATFORM}")
endif()

set(ANDROID_PALTFORM_DIR ${ANDROID_SDK_HOME}/platforms/${ANDROID_PLATFORM})
set(ANDROID_CLASSPATH ${ANDROID_PALTFORM_DIR}/android.jar)
string(REPLACE "android-" "" ANDROID_API_LEVEL "${ANDROID_PLATFORM}")

if (NOT EXISTS ${ANDROID_PALTFORM_DIR})
    message(STATUS "Downloading platforms;${ANDROID_PLATFORM}")
    execute_process(
        COMMAND ${ANDROID_SDK_HOME}/cmdline-tools/latest/bin/sdkmanager "'platforms;${ANDROID_PLATFORM}'"
    )
endif()

set(CMAKE_TOOLCHAIN_FILE ${ANDROID_NDK_HOME}/build/cmake/android.toolchain.cmake)

function(sign_apk)
    cmake_parse_arguments(ARG "" "TARGET;TAG;KEYSTORE;PASSWORD" "" ${ARGN})

    get_target_property(APK_PATH ${ARG_TARGET} APK)
    
    if (NOT ARG_TAG)
        set(ARG_TAG signed)
    endif()
    
    string(REPLACE ".apk" "_${ARG_TAG}.apk" OUTPUT ${APK_PATH})

    add_custom_command(
        OUTPUT ${OUTPUT}
        DEPENDS ${APK_PATH}
        BYPRODUCTS ${OUTPUT}.idsig
        COMMAND ${ANDROID_APKSIGNER} sign 
            --ks ${ARG_KEYSTORE}
            --ks-pass pass:android
            --out ${OUTPUT}
            --min-sdk-version ${ANDROID_API_LEVEL}
            ${APK_PATH}
    )
    add_custom_target(
        ${ARG_TARGET}_${ARG_TAG}_apk
        DEPENDS ${OUTPUT}
    )
endfunction()

function(sign_debug_apk ARG_TARGET)
    if (NOT EXISTS ${CMAKE_CURRENT_BINARY_DIR}/app_debug.ks)
        execute_process(
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
    endif()

    sign_apk(
        TARGET ${ARG_TARGET}
        TAG debug
        KEYSTORE ${CMAKE_CURRENT_BINARY_DIR}/app_debug.ks 
        PASSWORD android)
endfunction()

macro(add_apk)
    cmake_parse_arguments(ARG "" "TARGET;JAVA;RES;ASSETS;MANIFEST" "EXTRA_JNI_HEADERS" ${ARGN})

    if(NOT ARG_JAVA)
        set(ARG_JAVA ${CMAKE_CURRENT_SOURCE_DIR}/java)
    endif()
    if(NOT ARG_RES)
        set(ARG_RES ${CMAKE_CURRENT_SOURCE_DIR}/res)
    endif()
    if(NOT ARG_ASSETS)
        set(ARG_ASSETS ${CMAKE_CURRENT_SOURCE_DIR}/assets)
    endif()
    if(NOT ARG_TARGET)
        message(FATAL_ERROR "Missing native target")
    endif()
    if(NOT ARG_MANIFEST)
        set(ARG_MANIFEST ${CMAKE_CURRENT_SOURCE_DIR}/AndroidManifest.xml)
    endif()
    set(APP_CLASS_DIR ${CMAKE_CURRENT_BINARY_DIR}/classes)
    set(APP_JNI_DIR ${CMAKE_CURRENT_BINARY_DIR}/jni)
    
    set(ARG_EXTRA_JNI_HEADERS "${ARG_EXTRA_JNI_HEADERS};${APP_JNI_DIR}/org_napp_NativeApp.h")

    file(GLOB_RECURSE __JAVA_FILES "${ARG_JAVA}/*.java")

    foreach(JAVA_FILE ${__JAVA_FILES})
        file(RELATIVE_PATH JAVA_FILE ${ARG_JAVA} ${JAVA_FILE})
        string(REPLACE ".java" ".class" CLASS_FILE ${JAVA_FILE})
        list(APPEND __CLASS_FILES ${APP_CLASS_DIR}/${CLASS_FILE})
    endforeach()

    add_custom_command(
        OUTPUT
            ${CMAKE_CURRENT_BINARY_DIR}/apk/classes.dex
            ${ARG_EXTRA_JNI_HEADERS}
        DEPENDS ${__JAVA_FILES}
        BYPRODUCTS ${__CLASS_FILES}
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

    get_target_property(___PROJECT_SOURCES ${ARG_TARGET} SOURCES)

    file(GLOB_RECURSE __JNI_FILES "${APP_JNI_DIR}/*.h")

    list(APPEND ___PROJECT_SOURCES ${ARG_EXTRA_JNI_HEADERS})

    set_target_properties(${ARG_TARGET} PROPERTIES SOURCES "${___PROJECT_SOURCES}")

    target_include_directories(${ARG_TARGET} PRIVATE ${APP_JNI_DIR})

    file(GLOB_RECURSE __ASSETS_FILES "${ARG_ASSETS}/*")
    file(GLOB_RECURSE __RES_FILES "${ARG_RES}/*")
    
    add_custom_command(
        OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/intermediate-resource.zip
        DEPENDS ${__RES_FILES}
        COMMAND ${ANDROID_AAPT2} compile 
            --dir ${ARG_RES}
            -o ${CMAKE_CURRENT_BINARY_DIR}/intermediate-resource.zip
    )
    
    add_custom_command(
        OUTPUT
            ${CMAKE_CURRENT_BINARY_DIR}/apk/resources.arsc
            ${CMAKE_CURRENT_BINARY_DIR}/apk/AndroidManifest.xml
        DEPENDS
            ${CMAKE_CURRENT_BINARY_DIR}/intermediate-resource.zip
            ${ARG_MANIFEST}
            ${__ASSETS_FILES} 
        COMMAND ${ANDROID_AAPT2} link 
            -I ${ANDROID_SDK_HOME}/platforms/${ANDROID_PLATFORM}/android.jar
            -A ${ARG_ASSETS}
            ${CMAKE_CURRENT_BINARY_DIR}/intermediate-resource.zip
            --manifest ${ARG_MANIFEST}
            -o ${CMAKE_CURRENT_BINARY_DIR}/apk
            --output-to-dir
    )
    add_custom_command(
        OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/${ARG_TARGET}.apk 
        DEPENDS
            ${ARG_TARGET}
            ${CMAKE_CURRENT_BINARY_DIR}/apk/resources.arsc
            ${CMAKE_CURRENT_BINARY_DIR}/apk/AndroidManifest.xml
            ${CMAKE_CURRENT_BINARY_DIR}/apk/classes.dex
        WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/apk
        COMMAND ${CMAKE_COMMAND} -E tar cf
            ${CMAKE_CURRENT_BINARY_DIR}/${ARG_TARGET}.apk 
            --format=zip
            .
    )
    add_custom_command(
        TARGET ${ARG_TARGET}
        POST_BUILD
        DEPENDS ${CMAKE_CURRENT_BINARY_DIR}/${ARG_TARGET}.apk 
    )
    set_target_properties(${ARG_TARGET} PROPERTIES APK ${CMAKE_CURRENT_BINARY_DIR}/${ARG_TARGET}.apk)
endmacro()
