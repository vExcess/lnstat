build:
	npx tsc -m amd --outFile dist/index.js index.ts || exit 0;
	zig build-exe -O ReleaseSmall -femit-bin=dist/lnstat main.zig
	rm dist/lnstat.o
	yui-compressor ./dist/index.js > ./dist/lnstat.js
	rm ./dist/index.js

deb:
	$(eval pkgVersion := $(shell sed -n '2p' deb-metadata.yaml | cut -d' ' -f 2))
	$(eval debPkgName := lnstat_$(pkgVersion))
	rm $(debPkgName) -r || exit 0;
	mkdir $(debPkgName)
	mkdir $(debPkgName)/usr
	mkdir $(debPkgName)/usr/local
	mkdir $(debPkgName)/usr/local/bin
	cp ./dist/lnstat $(debPkgName)/usr/local/bin/lnstat
	cp ./dist/lnstat.js $(debPkgName)/usr/local/bin/lnstat.js
	mkdir $(debPkgName)/DEBIAN
	cp ./deb-metadata.yaml $(debPkgName)/DEBIAN/control
	dpkg-deb --build $(debPkgName)
	mv ./$(debPkgName).deb ./dist/$(debPkgName)
	rm -r $(debPkgName)