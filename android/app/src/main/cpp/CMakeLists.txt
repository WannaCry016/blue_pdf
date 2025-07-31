cmake_minimum_required(VERSION 3.4.1)

# Native C++ code
add_library(native-lib SHARED native-lib.cpp)

# PDFium native library
add_library(pdfium SHARED IMPORTED)

# Dynamically set the .so path based on current ABI (arm64-v8a / armeabi-v7a)
set_target_properties(pdfium PROPERTIES
    IMPORTED_LOCATION ${CMAKE_SOURCE_DIR}/../jniLibs/${ANDROID_ABI}/libpdfium.so
    INTERFACE_INCLUDE_DIRECTORIES ${CMAKE_SOURCE_DIR}/include
)

# Android log library
find_library(log-lib log)

# Include directories
target_include_directories(native-lib PRIVATE
    ${CMAKE_SOURCE_DIR}/include
)

# Link everything
target_link_libraries(
    native-lib
    pdfium
    ${log-lib}
)
