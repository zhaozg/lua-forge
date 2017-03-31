@rem Script to build Lua 5.2 under "Visual Studio .NET Command Prompt".
@rem Do not run from this directory; run it from the toplevel: etc\luavs.bat .
@rem It creates lua{V}.dll, lua{V}.lib, lua{V}.exe, and lua{V}c.exe in src.
@rem (contributed by David Manura and Mike Pall)

@setlocal
@set MYCOMPILE=cl /nologo /MT /O2 /W3 /c /D_CRT_SECURE_NO_DEPRECATE
@set MYLINK=link /nologo
@set MYMT=mt /nologo

@set MYVER=53
@if "%1" NEQ "" set MYVER=%1%

%MYCOMPILE% /DLUA_BUILD_AS_DLL l*.c
del lua.obj luac.obj
%MYLINK% /DLL /out:lua%MYVER%.dll l*.obj
if exist lua%MYVER%.dll.manifest^
  %MYMT% -manifest lua%MYVER%.dll.manifest -outputresource:lua%MYVER%.dll;2
%MYCOMPILE% /DLUA_BUILD_AS_DLL lua.c
%MYLINK% /out:lua%MYVER%.exe lua.obj lua%MYVER%.lib
if exist lua.exe%MYVER%.manifest^
  %MYMT% -manifest lua%MYVER%.exe.manifest -outputresource:lua%MYVER%.exe
del *.obj *.manifest
move lua53.* ..\build
