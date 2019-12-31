@echo off
pushd .
cd ..

pushd .
for /d %%i in (*) do call :$GitStatus "%%i"
popd
popd

exit /B

:$GitStatus

echo.
echo Executing git status for %1...
cd %1
git status
cd ..

exit /B
