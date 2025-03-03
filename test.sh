#!/bin/bash -eux
case "$OSTYPE" in
    darwin*) case "$HOSTTYPE" in
		 arm64) LIBDIR=/opt/homebrew/lib;INCLUDE=/opt/homebrew/include;;
		 *)	LIBDIR=/usr/local/lib;INCLUDE=/usr/local/include;;
	     esac ;;
     *) LIBDIR=/usr/lib;INCLUDE=/usr/include;;
esac

if [ $# -eq 0 ]; then
    OPTS=-Doptimize=Debug
else
    OPTS=-Doptimize=$1
fi
for i in src/*_test.zig; do
    zig test $OPTS $i -I$INCLUDE -L$LIBDIR -lturbojpeg -lc
done

