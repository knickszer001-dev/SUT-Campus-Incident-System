@echo off
title SUT Campus Incident System - SHA-1 Finder
echo ====================================================================
echo   SUT Campus Incident System - SHA-1 Certificate Finder (Local PC)
echo ====================================================================
echo.
echo Checking for local debug.keystore...
echo.

if exist "%USERPROFILE%\.android\debug.keystore" (
    echo [SUCCESS] Found debug.keystore at %USERPROFILE%\.android\debug.keystore
    echo.
    echo Extracting SHA-1 and SHA-256 fingerprint:
    echo --------------------------------------------------------------------
    keytool -list -v -keystore "%USERPROFILE%\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android | findstr /C:"SHA1:" /C:"SHA256:"
    echo --------------------------------------------------------------------
) else (
    echo [INFO] Keystore not found in standard user directory.
    echo Attempting to run local gradlew signingReport...
    echo.
    if exist "android\gradlew.bat" (
        cd android
        call gradlew.bat signingReport
    ) else (
        echo [ERROR] Could not find gradlew.bat in this directory. 
        echo Please make sure you are running this file from the root folder of your project!
    )
)

echo.
echo ====================================================================
pause
