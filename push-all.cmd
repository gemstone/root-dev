@echo off
pushd .
cd ..

pushd .
for /d %%i in (*) do call :$GitPush "%%i"
popd
popd

exit /B

:$GitPush

echo.
echo Executing git push for %1...
cd %1
git push
cd ..

exit /B
