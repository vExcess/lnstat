build:
	rm ./dist -r || exit 0;
	mkdir dist
	npx esbuild --minify --loader=ts < index.ts > ./dist/lnstat.js
	zig build-exe -O ReleaseSmall -femit-bin=dist/lnstat main.zig
	rm dist/lnstat.o

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
	mv ./$(debPkgName).deb ./dist/$(debPkgName).deb
	rm -r $(debPkgName)