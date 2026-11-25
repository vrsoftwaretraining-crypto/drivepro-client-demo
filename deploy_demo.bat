@echo off
REM DrivePro DEMO: build + publish to a separate Firebase preview link (your live site is not touched)
echo === 1/3 flutter pub get ===
call flutter pub get
if errorlevel 1 goto err
echo === 2/3 building DEMO web build ===
call flutter build web --release --dart-define=DEMO_MODE=true
if errorlevel 1 goto err
echo === 3/3 publishing to preview channel "demo" (30 days) ===
call firebase hosting:channel:deploy demo --expires 30d
if errorlevel 1 goto err
echo.
echo DONE. Send the "Channel URL" printed above to the client.
pause
goto :eof
:err
echo.
echo FAILED. Copy the error message above and send it.
pause
