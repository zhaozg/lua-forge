#!/bin/sh

#~ * $0 ：即命令本身，相当于c/c++中的argv[0]
#~ * $1 ：第一个参数.
#~ * $2, $3, $4 ... ：第2、3、4个参数，依次类推。
#~ * $#  参数的个数，不包括命令本身
#~ * $@ ：参数本身的列表，也不包括命令本身
#~ * $* ：和$@相同，但"$*" 和 "$@"(加引号)并不同，"$*"将所有的参数解释成一个字符串，而"$@"是一个参数数组。

### Process arguments

#Variable list
## LUA, ANDROID

#default
Lua=lua

#process arguments
while [ -n "$1" ]
do
  case "$1" in
    -?|-h)
	return;;
    -L)
      Lua="$2"
      shift 2;;
    -N)
      NDK="$2"
      shift 2;;
    -A)
      NDKABI="$2"
      shift 2;;
    -V)
      NDKVER="$2"
      shift 2;;
    -P)
      NDKP="$2"
      shift 2;;
    -X)
      shift 2;
      EXTRAS="$*"
      break
      ;;
 esac
done

#check
echo "$Lua $NDK $NDKABI $NDKVER $EXTRAS"

if [ "$NDK" == "" ]
then
  cd $Lua
  make $EXTRAS
else

#  NDK=/e/tools/android/android-ndk-r15c
  if [  "$NDKABI" == ""  ]
  then
    NDKABI=19
  fi

  #NDKVER=$NDK/toolchains/arm-linux-androideabi-4.9
  if [ "$NDKVER" == "" ]
  then
    NDKVER=$NDK/toolchains/arm-linux-androideabi-4.9
  fi

  #NDKP=$NDKVER/prebuilt/windows-x86_64/bin/arm-linux-androideabi-
  if [ "$NDKP" == "" ]
  then
    echo Please given  NDKP follow by -V
    return
  fi
  NDKF="--sysroot=$NDK/platforms/android-$NDKABI/arch-arm"

  if [ "$Lua" == "lua" ]
  then
    CC=${NDKP}gcc
    AR="${NDKP}ar rcu"
    RANLIB=${NDKP}ranlib
    CFLAGS="-I$NDK/platforms/android-$NDKABI/arch-arm/usr/include -L$NDK/platforms/android-$NDKABI/arch-arm/usr/lib"
    cd $lua
    make CC=$CC AR="$AR" CFLAGS="$CFLAGS -D\"lua_getlocaledecpoint()='.'\"" RANLIB=$RANLIB $EXTRAS
  else
    cd $Lua
    make HOST_CC="gcc -m32" CROSS=$NDKP TARGET_FLAGS="$NDKF" TARGET_SYS=LINUX  $EXTRAS
  fi
fi

# build wluajit
#~ LUAJIT_SRC=../luajit/src/src
#~ BIN_DIR=../../bin/mingw32
#~ windres luajit.rc luajit.o
#~ gcc -O2 -s -static-libgcc wmain.c luajit.o $LUAJIT_SRC/luajit.c -o $BIN_DIR/wluajit.exe -mwindows -llua51 -I$LUAJIT_SRC -L$BIN_DIR
#~ rm luajit.o
