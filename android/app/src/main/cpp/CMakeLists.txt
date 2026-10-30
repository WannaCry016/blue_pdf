cmake_minimum_required(VERSION 3.18.1)
project(bluepdf CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

add_library(native-lib SHARED native-lib.cpp pdf_ops.cpp)

# Prebuilt MuPDF (libmupdf_java.so from MuPDF's Android build).
add_library(mupdf SHARED IMPORTED)
set_target_properties(mupdf PROPERTIES
    IMPORTED_LOCATION ${CMAKE_SOURCE_DIR}/../jniLibs/${ANDROID_ABI}/libmupdf_java.so
)

target_include_directories(native-lib PRIVATE ${CMAKE_SOURCE_DIR}/include)
target_compile_options(native-lib PRIVATE -Wall)
target_link_libraries(native-lib mupdf)
