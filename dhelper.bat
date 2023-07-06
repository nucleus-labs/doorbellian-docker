@echo off

REM ================================================================================================

echo Windows is incapable of performing USB passthrough with windows.
echo Please confirm you understand that this will not work before continuing.
@REM set /p understand="Do you understand? [y/N] "

@REM if /i "%understand%"=="y" goto understands

@REM exit /b 1

REM ================================================================================================

:understands
set "valid_targets=build run bar"
set valid_target_found=0

REM ================================================================================================

REM Was exactly one argument supplied? If not, print usage and error.
if "%~1"=="" (
    echo Usage: %~nx0 ^<%valid_targets%^>
    exit /b 2
)

REM ================================================================================================

set "target=%~1"

REM Check if the supplied target is valid
for %%i in (%valid_targets%) do (
    if "%target%"=="%%i" (
        set valid_target_found=1
        goto :target_found
    )
)

REM If no valid target matching the supplied target is found, error
echo Error: '%target%' is not a valid target.
echo Usage: %~nx0 ^<%valid_targets%^>
exit /b 2

:target_found

REM ================================================================================================

if "%target%"=="build" (
    docker build -t doorbellian:dev .
)

if "%target%"=="run" (
    docker run --rm -it ^
        -p 1935:1935 ^
        -p 8000:8000 ^
        -p 8001:8001 ^
        -p 8554:8554 ^
        -p 8888:8888 ^
        -p 8889:8889 ^
        doorbellian:dev
)

if "%target%"=="bar" (
    docker build -t doorbellian:dev .
    docker run --rm -it ^
        -p 1935:1935 ^
        -p 8000:8000 ^
        -p 8001:8001 ^
        -p 8554:8554 ^
        -p 8888:8888 ^
        -p 8889:8889 ^
        doorbellian:dev
)