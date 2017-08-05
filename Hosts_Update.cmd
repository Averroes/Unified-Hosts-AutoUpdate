@echo off

rem Check for admin rights, and exit if none present
>nul 2>&1 "%SYSTEMROOT%\system32\cacls.exe" "%SYSTEMROOT%\Prefetch\" || goto Admin

rem Enable delayed expansion to be used during for loops and other parenthetical groups
setlocal ENABLEDELAYEDEXPANSION

rem Set Resource and target locations
set VERSION=%~dp0VERSION
set GH=https://raw.githubusercontent.com/ScriptTiger/Unified-Hosts-AutoUpdate/master
set WGETP=%~dp0wget\x!PROCESSOR_ARCHITECTURE:~-2!\wget.exe
set WGET="%WGETP%" -O- -q -t 0 --retry-connrefused -c -T 0
set HOSTS=C:\Windows\System32\drivers\etc\hosts
set BASE=https://raw.githubusercontent.com/StevenBlack/hosts/master

rem Check if script is returning from being updated and resume
if "%1"=="/U" goto Updated

rem If the URL is sent as a parameter, set the URL variable and turn the script to quiet mode with no prompts
if not "%1"=="" (
	set URL=%1
	set QUIET=1
)

rem Make sure Wget can be found
if not exist "%WGETP%" goto Wget

rem Grab remote script version
rem On error, report connectivity problem
(for /f %%0 in ('%WGET% %GH%/VERSION') do set NEW=%%0) || goto Connectivity

rem Check for emergency stop status
if "%NEW:~,1%"=="X" (
	echo.
	echo **We are currently working to fix a problem**
	echo **Please try again later**
	if not !QUIET!==1 pause
	exit
)

rem Grab local script version
set /p OLD=<"%VERSION%"

rem Strip out emergency status if present in local version
if "%OLD:~,1%"=="X" (
	echo %OLD:~1%>"%VERSION%"
)

rem If the versions don't match, automatically update and continue with updated script
if not "%OLD%"=="%NEW%" (
	echo A new update is available^^!
	echo Updating script...
	timeout /t 3 /nobreak > nul&(for /f "tokens=*" %%0 in ('%WGET% %GH%/Hosts_Update.cmd') do @echo%% 0>"%~0"&echo %NEW%>"%VERSION%"&%0 /U
)

:Updated

rem Initialize MARKED to 0 for no markings yet verified
set MARKED=0

rem Check for begin and end tags in hosts file
for /f "tokens=*" %%0 in (
	'findstr /b /i "####.BEGIN.UNIFIED.HOSTS.#### ####.END.UNIFIED.HOSTS.####" "%HOSTS%"'
) do (
	if !MARKED!==1 if /i "%%0"=="#### END UNIFIED HOSTS ####" (set MARKED=2) else (set MARKED=-1)
	if /i "%%0"=="#### BEGIN UNIFIED HOSTS ####" set MARKED=1
)

rem Assess tags as correct, incorrect, or absent
rem If there are no tags, offer to install them
rem Check to see if the file is null-terminating before appending extra white space
if !MARKED!==0 (
	echo The Unified Hosts has not yet been marked in your local hosts file
	if not !QUIET!==1 (
		choice /m "Automatically insert the Unified Hosts at the bottom of your local hosts?"
		if !ERRORLEVEL!==2 goto Mark
		)
	for /f "tokens=1* delims=:" %%0 in ('findstr /n .* "%HOSTS%"') do set NTF=%%1
	if not "!NTF!"=="" echo.>>"%HOSTS%"
	echo #### BEGIN UNIFIED HOSTS ####>>"%HOSTS%"
	echo #### END UNIFIED HOSTS ####>>"%HOSTS%"
	goto update
)

if !MARKED!==2 (
	echo The Unified Hosts is already installed in your local hosts file
	if not !QUIET!==1 (
		choice /M "Would you like to continue to update it?"
		if !errorlevel!==2 (
			choice /M "Would you like remove the Unified Hosts from your local hosts file?"
			if !errorlevel!==1 (goto Remove) else (exit)
			)
		)
	) else (goto Mark)

echo Checking Unified Hosts version...

rem rem Grab date and URL from the Unified Hosts inside of the local hosts file
for /f "tokens=*" %%0 in (
	'findstr /b "#.Date: #.Fetch.the.latest.version.of.this.file:" "%HOSTS%"'
) do (
	set LINE=%%0
	if "!LINE:~,8!"=="# Date: " set OLD=%%0
	if "!LINE:~,8!"=="# Fetch " (
		set OLD=!OLD!%%0
		if not !QUIET!==1 (
			set URL=%%0
			set URL=!URL:~41!
		)
	)
)

rem If the markings are there but no Unified Hosts, skip the rest of the check and continue to update
if not !QUIET!==1 if "%OLD%"=="" (
	set URL=NUL
	goto Update
)

rem Grab date and URL from remote Unified Hosts
for /f "tokens=*" %%0 in (
	'^(%WGET% %URL% ^| findstr /b "#.Date: #.Fetch.the.latest.version.of.this.file:"^)'
) do (
	set LINE=%%0
	if "!LINE:~,8!"=="# Date: " set NEW=%%0
	if "!LINE:~,8!"=="# Fetch " set NEW=!NEW!%%0
)

rem If the remote and local dates and URLs are not the same, update
if "%OLD%"=="%NEW%" (
	if !QUIET!==1 exit
	echo You already have the latest version.
	choice /M "Would you like to update anyway?"
	if !errorlevel!==1 (goto Update) else (exit)
) else (
	echo Your version is out of date
	
goto Update
)

:Connectivity
echo.
echo This script cannot connect to the Internet^^!
echo This script requires and active Internet connection to update your hosts file^^!
if not !QUIET!==1 pause
exit

:Wget
echo Wget cannot be found
echo You can do either of the following
echo 1.] Put the Wget directory in the same directory as this script
echo 2.] Edit the "WGETP" variable of this script
if not !QUIET!==1 pause
exit

:Admin
echo You must run this with administrator privileges!
if not !QUIET!==1 pause
exit

:Mark
if !MARKED!==-1 echo "#### END UNIFIED HOSTS ####" not properly marked in hosts file^^!
echo.
echo Hosts is not properly marked
echo Please ensure the following lines mark where to insert the blacklist:
echo.
echo #### BEGIN UNIFIED HOSTS ####
echo #### END UNIFIED HOSTS ####
echo.
echo Notes: You should only have to mark this once
echo Updates automatically overwite between the above lines
if not !QUIET!==1 pause
exit

rem Function to remove Unified Hosts from local hosts file
:Remove
set REMOVE=1
call :File
echo The Unified Host has been removed
if not !QUIET!==1 pause
exit

rem Function to update current local hosts with current Unified Hosts
:Update

if not !QUIET!==1 (

	if "%URL:~-6%"=="/hosts" (
		echo Your current preset is to use the following Unified Hosts:
		echo %URL%
		choice /m "Would you like to just stick with that?"
		if !errorlevel!==1 goto Skip_Choice
	)

	echo The Unified Hosts will automatically block malware and adware.
	choice /m "Would you also like to block other categories?"
	if !errorlevel!==1 (

		set CAT=

		choice /m "Would you also like to block fake news?"
		if !errorlevel!==1 set CAT=_fakenews_

		choice /m "Would you also like to block gambling?"
		if !errorlevel!==1 set CAT=!CAT!_gambling_

		choice /m "Would you also like to block porn?"
		if !errorlevel!==1 set CAT=!CAT!_porn_

		choice /m "Would you also like to block social?"
		if !errorlevel!==1 set CAT=!CAT!_social_

		if not "!CAT!"=="" (
			set CAT=!CAT:__=-!
			set CAT=!CAT:_=!
			set URL=%BASE%/alternates/!CAT!/hosts
		) else (set URL=%BASE%/hosts)
	) else (set URL=%BASE%/hosts)
)

rem If the URL is still not complete by this point, just set the default as the basic Unified Hosts with no extensions
if not "%URL:~-6%"=="/hosts" set URL=%BASE%/hosts

:Skip_Choice

echo Updating the hosts file...
call :File

echo Your Unified Hosts has been updated
if not !QUIET!==1 pause
exit

rem File writing function
:File

rem To be disabled later to skip old hosts section, and then re-enable to continue after #### END UNIFIED HOSTS ####
set WRITE=1

rem Rewrite the hosts file to a temporary file and inject new Unified Hosts after #### BEGIN UNIFIED HOSTS ####
rem Filter Unified Hosts to remove localhost/loopback entries, invalid entries, and white space
(
	for /f "tokens=1* delims=:" %%a in (
		'findstr /n .* "%HOSTS%"'
	) do (
		if !WRITE!==1 (
			if "%%b"=="" (echo.) else (
				if /i not "%%b"=="#### BEGIN UNIFIED HOSTS ####" echo %%b
			)
			if /i "%%b"=="#### BEGIN UNIFIED HOSTS ####" (
				if not !REMOVE!==1 (
					echo %%b
					for /f "tokens=*" %%0 in (
						'^(%WGET% %URL% ^| findstr /b /r /v "127[.]0[.]0[.]1 255[.]255[.]255[.]255 ::1 fe80:: 0[.]0[.]0[.]0.[0-9][0-9]*[.][0-9][0-9]*[.][0-9][0-9]*[.][0-9][0-9]*"^)'
					) do @echo %%0
				)
				set WRITE=0
			)
		)
		if /i "%%b"=="#### END UNIFIED HOSTS ####" (
			if not !REMOVE!==1 echo %%b
			set WRITE=1
		)
	)
) > %TEMP%hosts

rem Wait some time to make sure all the processes are done accessing the hosts
rem Overwrite the old hosts with the new one
timeout /t 3 /nobreak > nul
copy "%TEMP%hosts" "%HOSTS%" /y > nul

exit /b
