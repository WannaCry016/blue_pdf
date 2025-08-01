cmake_minimum_required(VERSION 3.4.1)

# Create shared library from your native C++ source
add_library(native-lib SHARED native-lib.cpp)

# Import the prebuilt MuPDF shared library
add_library(mupdf SHARED IMPORTED)

# Set path to the prebuilt MuPDF .so file
set_target_properties(mupdf PROPERTIES
    IMPORTED_LOCATION ${CMAKE_SOURCE_DIR}/../jniLibs/${ANDROID_ABI}/libmupdf_java.so
)

# Find the log library for Android
find_library(log-lib log)

# Include headers from your MuPDF include folder
include_directories(${CMAKE_SOURCE_DIR}/include)

# Link your native library with MuPDF and log-lib
target_link_libraries(
    native-lib
    mupdf
    ${log-lib}
)
