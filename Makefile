dart:
	mkdir dist || exit 0;
	dart compile exe ./src-dart/lnstat.dart
	mkdir ./dist/dart || exit 0;
	mv ./src-dart/lnstat.exe ./dist/dart/lnstat

ts:
	mkdir dist || exit 0;
	rm ./dist/node -r || exit 0;
	rm ./dist/standalone -r || exit 0;
	mkdir ./dist/node
	mkdir ./dist/standalone
	npx esbuild --minify --loader=ts < ./src-ts/lnstat.ts > ./dist/node/lnstat.js
	zig build-exe -O ReleaseSmall -femit-bin=dist/node/lnstat ./src-ts/main.zig
	rm dist/node/lnstat.o
	pkg -t node16 -o ./dist/standalone/lnstat ./dist/node/lnstat.js

shermes:
	cd src-shermes && bash build.sh
	rm ./dist/shermes -r || exit 0;
	mkdir ./dist/shermes
	mv ./src-shermes/lnstat ./dist/shermes/lnstat

_build:
	chmod 755 ./build.sh
	./build.sh

deb-ts-node:
	bun run deb-metadata-generator.ts node
	$(MAKE) _build
	
deb-ts-standalone:
	bun run deb-metadata-generator.ts node-standalone
	$(MAKE) _build

deb-dart:
	bun run deb-metadata-generator.ts dart
	$(MAKE) _build
