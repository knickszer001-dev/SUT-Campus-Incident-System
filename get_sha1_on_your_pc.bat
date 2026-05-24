@echo off
title SUT Campus Incident System - SHA-1 Finder
echo ====================================================================
echo   SUT Campus Incident System - SHA-1 Certificate Finder
echo ====================================================================
echo.

rem 1. Check if JDK is already unzipped in build\jdk17
set "JDK_DIR=%~dp0build\jdk17\jdk-17.0.10+7"
if exist "%JDK_DIR%\bin\keytool.exe" (
    goto :jdk_ready
)

echo [INFO] Local Java environment not found. Preparing embedded JDK 17...
echo.

rem 2. Find jdk17.zip in standard archive locations
set "ZIP_PATH="
if exist "%~dp0..\project_archive\jdk17.zip" (
    set "ZIP_PATH=%~dp0..\project_archive\jdk17.zip"
) else if exist "A:\mobile_user_app\project_archive\jdk17.zip" (
    set "ZIP_PATH=A:\mobile_user_app\project_archive\jdk17.zip"
)

if "%ZIP_PATH%"=="" (
    echo [ERROR] Could not locate project_archive\jdk17.zip!
    echo Please make sure the project_archive folder exists in A:\mobile_user_app\
    pause
    exit /b 1
)

echo Found JDK zip archive at: %ZIP_PATH%
echo Unzipping JDK... (This will take a few seconds)
powershell -Command "New-Item -ItemType Directory -Path '%~dp0build\jdk17' -Force | Out-Null; Expand-Archive -Path '%ZIP_PATH%' -DestinationPath '%~dp0build\jdk17' -Force"

if not exist "%JDK_DIR%\bin\keytool.exe" (
    echo [ERROR] Failed to extract JDK 17!
    pause
    exit /b 1
)
echo [SUCCESS] JDK 17 extracted successfully!
echo.

:jdk_ready
set "JAVA_HOME=%JDK_DIR%"
set "PATH=%JDK_DIR%\bin;%PATH%"

rem 3. Ensure .android directory exists
if not exist "%USERPROFILE%\.android" (
    mkdir "%USERPROFILE%\.android"
)

rem 4. Generate debug.keystore if it doesn't exist
if not exist "%USERPROFILE%\.android\debug.keystore" (
    echo [INFO] Generating a new standard Android debug.keystore...
    keytool -genkey -v -keystore "%USERPROFILE%\.android\debug.keystore" -storepass android -alias androiddebugkey -keypass android -keyalg RSA -keysize 2048 -validity 10000 -dname "CN=Android Debug,O=Android,C=US" >nul
    if errorlevel 1 (
        echo [ERROR] Failed to generate debug.keystore!
        pause
        exit /b 1
    )
    echo [SUCCESS] Standard debug.keystore generated successfully!
    echo.
)

echo ====================================================================
echo   YOUR SHA-1 CERTIFICATE FINGERPRINTS:
echo ====================================================================
keytool -list -v -keystore "%USERPROFILE%\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android | findstr /C:"SHA1:" /C:"SHA256:"
echo ====================================================================
echo.
pause
