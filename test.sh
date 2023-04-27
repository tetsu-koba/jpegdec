#!/bin/sh -eux
if [ $# -eq 0 ]; then
    OPTS=-Doptimize=Debug
else
    OPTS=-Doptimize=$1
fi
for i in src/*_test.zig; do
    zig test $OPTS $i -lc -lturbojpeg
done

