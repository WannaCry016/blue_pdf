# Builds the MuPDF operations test for arm64 and runs it on a connected device.
# Usage: pwsh tool/native_test.ps1 [-Serial <adb serial>]
param([string]$Serial = "")

$ErrorActionPreference = "Stop"
$root = Split-Path $PSScriptRoot -Parent
$cpp = Join-Path $root "android/app/src/main/cpp"
$lib = Join-Path $root "android/app/src/main/jniLibs/arm64-v8a"
$outDir = Join-Path $root "build/native-test"
New-Item -ItemType Directory -Force $outDir | Out-Null

$sdk = if ($env:ANDROID_HOME) { $env:ANDROID_HOME } else { Join-Path $env:LOCALAPPDATA "Android/Sdk" }
$ndkVersion = "28.2.13676358"
$clang = Join-Path $sdk "ndk/$ndkVersion/toolchains/llvm/prebuilt/windows-x86_64/bin/aarch64-linux-android24-clang++.cmd"
if (-not (Test-Path $clang)) { throw "NDK $ndkVersion not found at $clang" }

$binary = Join-Path $outDir "pdf_ops_test"
& $clang -std=c++17 -O1 -Wall -Wno-unused-function `
    -I (Join-Path $cpp "include") `
    (Join-Path $cpp "pdf_ops.cpp") (Join-Path $cpp "tests/pdf_ops_test.cpp") `
    -L $lib -lmupdf_java -static-libstdc++ -o $binary
if ($LASTEXITCODE -ne 0) { throw "Compilation failed" }

$serialArgs = if ($Serial) { @("-s", $Serial) } else { @() }
function Invoke-Adb { & adb @serialArgs @args; if ($LASTEXITCODE -ne 0) { throw "adb $args failed" } }

$remote = "/data/local/tmp/bluepdf-native-test"
Invoke-Adb shell "rm -rf $remote && mkdir -p $remote/out" | Out-Null
Invoke-Adb push $binary (Join-Path $lib "libmupdf_java.so") $remote | Out-Null
& adb @serialArgs shell "cd $remote && chmod 755 pdf_ops_test && LD_LIBRARY_PATH=. ./pdf_ops_test out"
exit $LASTEXITCODE
