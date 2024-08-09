build:
	mkdir dist || exit 0;
	rm ./dist/node -r || exit 0;
	rm ./dist/standalone -r || exit 0;
	mkdir ./dist/node
	mkdir ./dist/standalone
	npx esbuild --minify --loader=ts < ./src/lnstat.ts > ./dist/node/lnstat.js
	zig build-exe -O ReleaseSmall -femit-bin=dist/node/lnstat ./src/main.zig
	rm dist/node/lnstat.o
	pkg -t node16 -o ./dist/standalone/lnstat ./dist/node/lnstat.js

shermes:
	cd src-shermes && bash build.sh
	rm ./dist/shermes -r || exit 0;
	mkdir ./dist/shermes
	mv ./src-shermes/lnstat ./dist/shermes/lnstat

_deb-build-start:
	rm $(debPkgName) -r || exit 0;
	mkdir $(debPkgName)
	mkdir $(debPkgName)/usr
	mkdir $(debPkgName)/usr/local
	mkdir $(debPkgName)/usr/local/bin

_deb-build-end:
	mkdir $(debPkgName)/DEBIAN
	cp ./$(debMetaDataFile) $(debPkgName)/DEBIAN/control
	dpkg-deb --build $(debPkgName)
	mv ./$(debPkgName).deb ./dist/$(debPkgName).deb
	rm -r $(debPkgName)

deb-node:
	$(eval debMetaDataFile := deb-metadata-node.yaml)
	$(eval pkgVersion := $(shell sed -n '2p' $(debMetaDataFile) | cut -d' ' -f 2))
	$(eval debPkgName := lnstat_$(pkgVersion))
	$(MAKE) _deb-build-start pkgVersion=$(pkgVersion) debPkgName=$(debPkgName)
	cp ./dist/node/lnstat $(debPkgName)/usr/local/bin/lnstat
	cp ./dist/node/lnstat.js $(debPkgName)/usr/local/bin/lnstat.js
	$(MAKE) _deb-build-end pkgVersion=$(pkgVersion) debPkgName=$(debPkgName) debMetaDataFile=$(debMetaDataFile)

deb-standalone:
	$(eval debMetaDataFile := deb-metadata-standalone.yaml)
	$(eval pkgVersion := $(shell sed -n '2p' $(debMetaDataFile) | cut -d' ' -f 2))
	$(eval debPkgName := lnstat_$(pkgVersion))
	$(MAKE) _deb-build-start pkgVersion=$(pkgVersion) debPkgName=$(debPkgName)
	cp ./dist/standalone/lnstat $(debPkgName)/usr/local/bin/lnstat
	$(MAKE) _deb-build-end pkgVersion=$(pkgVersion) debPkgName=$(debPkgName) debMetaDataFile=$(debMetaDataFile)