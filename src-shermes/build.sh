CWD=$(pwd)
export CPATH=$CWD/include
export LIBRARY_PATH=$CWD/lib
zig build-obj -fno-stack-check -fPIC fs-polyfill.zig
rm fs-polyfill.o.o
mkdir lib || true
mv fs-polyfill.o ./lib/fs-polyfill.o
shermes -typed -Wc,lib/fs-polyfill.o -o=lnstat ./lnstat.ts
rm ./lib/fs-polyfill.o