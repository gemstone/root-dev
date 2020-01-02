@echo off
pushd .
cd ..

pushd .
for /d %%i in (*) do call :$GitCommit "%%i" %1
popd
popd

exit /B

:$GitCommit

echo.
echo Executing git add . && git commit -m %2 for %1...
cd %1
git add . && git commit -m %2
cd ..

exit /B
