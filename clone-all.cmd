@echo off

SetLocal
SET clonefile=%TEMP%\clonefile.bat
COPY /Y clone-commands.txt %clonefile% > NUL

cd ..
CALL %clonefile%
DEL %clonefile%
cd root-dev