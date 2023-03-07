cmake_minimum_required(VERSION 3.16)

include(cmake/android.cmake)

project(native_app)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_C_STANDARD 11)

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
    ${ANDROID_NDK}/sources/android/native_app_glue/android_native_app_glue.c
    native_app.cpp
    napp.cpp
)
target_link_libraries(napp PRIVATE android log imgui)
target_include_directories(napp PRIVATE ${APP_JNI_DIR} ${ANDROID_NDK}/sources/android/native_app_glue)
set_target_properties(napp PROPERTIES LIBRARY_OUTPUT_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/apk/lib/${ANDROID_ABI})

add_apk(TARGET napp)

sign_debug_apk(napp)
