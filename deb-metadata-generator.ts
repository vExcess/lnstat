const fs = require("fs");

function trimLines(str: string): string {
    return str.trim().split("\n").map(s => s.trimStart()).join("\n");
}

const mappings = {
    "node": {
        size: 35,
        code: trimLines(`
            cp ./dist/node/lnstat $debPkgName/usr/local/bin/lnstat
            cp ./dist/node/lnstat.js $debPkgName/usr/local/bin/lnstat.js
        `)
    },
    "node-standalone": {
        size: 42669,
        code: trimLines(`
	        cp ./dist/standalone/lnstat $debPkgName/usr/local/bin/lnstat
        `)
    },
    "dart": {
        size: 5765,
        code: trimLines(`
	        cp ./dist/dart/lnstat $debPkgName/usr/local/bin/lnstat
        `)
    }
};

const data = mappings[process.argv[2] as keyof typeof mappings];

fs.writeFileSync("./deb-metadata.yaml", `Package: lnstat
Version: 1.2-1
Installed-Size: ${data.size}
Section: base
Priority: optional
Architecture: i386
Depends: 
Maintainer: VExcess <github.com/vExcess>
Description: lnstat
 Utility for counting lines of source code,
 number of comment lines, and blank lines.
`);

fs.writeFileSync("./build.sh", `
# init variables
debMetaDataFile=deb-metadata.yaml
pkgVersion=$(sed -n '2p' $debMetaDataFile | cut -d' ' -f 2)
debPkgName="lnstat_$pkgVersion"

# setup deb filetree
rm $debPkgName -r || true
mkdir $debPkgName
mkdir $debPkgName/usr
mkdir $debPkgName/usr/local
mkdir $debPkgName/usr/local/bin

# copy over compiled binaries
${data.code}

# build package and cleanup
mkdir $debPkgName/DEBIAN
cp ./$debMetaDataFile $debPkgName/DEBIAN/control
dpkg-deb --build $debPkgName
mv ./$debPkgName.deb ./dist/$debPkgName.deb
rm -r $debPkgName

rm ./build.sh
rm ./deb-metadata.yaml
`);

