@if "%SCM_TRACE_LEVEL%" NEQ "4" @echo off

:: ----------------------
:: KUDU Deployment Script
:: Version: 1.0.17
:: ----------------------

:: Prerequisites
:: -------------

:: Verify node.js installed
where node 2>nul >nul
IF %ERRORLEVEL% NEQ 0 (
  echo Missing node.js executable, please install node.js, if already installed make sure it can be reached from current environment.
  goto error
)

:: Setup
:: -----

setlocal enabledelayedexpansion

SET ARTIFACTS=%~dp0%..\artifacts

IF NOT DEFINED DEPLOYMENT_SOURCE (
  SET DEPLOYMENT_SOURCE=%~dp0%.
)

IF NOT DEFINED DEPLOYMENT_TARGET (
  SET DEPLOYMENT_TARGET=%ARTIFACTS%\wwwroot
)

IF NOT DEFINED NEXT_MANIFEST_PATH (
  SET NEXT_MANIFEST_PATH=%ARTIFACTS%\manifest

  IF NOT DEFINED PREVIOUS_MANIFEST_PATH (
    SET PREVIOUS_MANIFEST_PATH=%ARTIFACTS%\manifest
  )
)

SET BUILD_COMMAND=%WEBSITE_BUILD_COMMAND%
SET PUBLISH_DIRECTORY=%WEBSITE_PUBLISH_DIRECTORY%

SET DEPLOYMENT_TEMP=%temp%\___deploymentTemp

IF NOT DEFINED HUGO_VERSION (
  SET HUGO_VERSION=0.55.6
)

SET HUGO_PATH=%appdata%\hugo\%HUGO_VERSION%

SET PATH=%HUGO_PATH%;%PATH%

IF NOT DEFINED KUDU_SYNC_CMD (
  :: Install kudu sync
  echo Installing Kudu Sync
  call npm install kudusync -g --silent
  IF !ERRORLEVEL! NEQ 0 goto error

  :: Locally just running "kuduSync" would also work
  SET KUDU_SYNC_CMD=%appdata%\npm\kuduSync.cmd
)

::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:: Deployment
:: ----------

:Deployment

:: 1. Robocopy
robocopy "%DEPLOYMENT_SOURCE%" "%DEPLOYMENT_TEMP%" /MIR /XD .git > nul
pushd "%DEPLOYMENT_TEMP%"

:: 2. Install Hugo
IF NOT EXIST "%HUGO_PATH%\hugo.exe" (
  curl -Ls -o %temp%\hugo.zip  https://github.com/gohugoio/hugo/releases/download/v%HUGO_VERSION%/hugo_%HUGO_VERSION%_Windows-32bit.zip
  D:\7zip\7za.exe x %temp%\hugo.zip -aoa -o"%HUGO_PATH%" > nul
  rm %temp%\hugo.zip
  IF !ERRORLEVEL! NEQ 0 goto error
)

:: 3. Execute build command
IF /I "%BUILD_COMMAND%" NEQ "" (
  call :ExecuteCmd %BUILD_COMMAND%
  IF !ERRORLEVEL! NEQ 0 goto error
)

:: 4. KuduSync
call :ExecuteCmd "%KUDU_SYNC_CMD%" -v 50 -f "%DEPLOYMENT_TEMP%\%PUBLISH_DIRECTORY%" -t "%DEPLOYMENT_TARGET%" -n "%NEXT_MANIFEST_PATH%" -p "%PREVIOUS_MANIFEST_PATH%" -i ".git;.hg;.deployment;deploy.cmd"
IF !ERRORLEVEL! NEQ 0 goto error

popd

::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
goto end

:: Execute command routine that will echo out when error
:ExecuteCmd
setlocal
set _CMD_=%*
call %_CMD_%
if "%ERRORLEVEL%" NEQ "0" echo Failed exitCode=%ERRORLEVEL%, command=%_CMD_%
exit /b %ERRORLEVEL%

:error
endlocal
echo An error has occurred during web site deployment.
call :exitSetErrorLevel
call :exitFromFunction 2>nul

:exitSetErrorLevel
exit /b 1

:exitFromFunction
()

:end
endlocal
echo Finished successfully.
