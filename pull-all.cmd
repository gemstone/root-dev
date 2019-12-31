@echo off
pushd .
cd ..

pushd .
for /d %%i in (*) do call :$GitPull "%%i"
popd
popd

exit /B

:$GitPull

echo.
echo Executing git pull for %1...
cd %1
git pull
cd ..

exit /B
