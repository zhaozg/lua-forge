REM @echo off
set lua=%1
set ver=%2

if "%lua%"=="" goto Usage
if "%lua%"=="LuaJIT" goto luajit
if "%lua%"=="lua" goto lua

:Usage
@echo Usage:
@echo 	%0% path_of_lua [options pass to origin build] 
goto EOF

:luajit
shift
cd %lua%\src
call ..\..\etc\ljvs.bat %1% %2% %3% %4%
move lua51.* ..\..\build
move luajit.exe ..\..\build
cd ..\..
goto EOF

:lua
cd %lua%
call ..\etc\luavs.bat %ver%
cd ..
echo Done
goto EOF

:EOF

REM build wluajit
REM ~ LUAJIT_SRC=../src
REM ~ BIN_DIR=..
REM ~ rc /foluajit.res luajit.rc 
REM ~ cl -O2 wmain.c luajit.res ../src/luajit.c -Fewluajit.exe lua51.lib /link /SUBSYSTEM:WINDOWS
REM ~ del *.obj *.res
