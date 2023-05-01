#!/bin/sh -eux
if [ $# -eq 0 ]; then
    OPTS=-Doptimize=Debug
else
    OPTS=-Doptimize=$1
fi
OPTS="$OPTS -I /opt/libjpeg-turbo/include/ -L /opt/libjpeg-turbo/lib64/"
for i in src/*_test.zig; do
    zig test $OPTS $i -lc -lturbojpeg
done

