// ---------- process Polyfill -----------
const process = {
    argv: [
        '/home/vexcess/.nvm/versions/node/v20.16.0/bin/node',
        '/usr/local/bin/lnstat.js',
        './'
    ],
    stdout: {
        write: print
    }
};
// ---------- ----------




// ---------- Zig Bindings ----------
const init = $SHBuiltin.extern_c({ include: "fs-polyfill.h" }, function init(): void {
    throw 0;
});
// ---------- ----------


// ---------- More Polyfills ----------
// NOTE: shermes does not support Array.prototype.slice
function Array_slice(self: string[], start: number, stop: number): string[] {
    let subArr = [];
    for (let i = start; i < stop; i++) {
        subArr.push(self[i]);
    }
    return subArr;
}
// ---------- ----------




init();

function showHelp() {
    
}

function main() {
    print("checkpoint 1")
    print(process.argv.length)
    const args = Array_slice([
        '/home/vexcess/.nvm/versions/node/v20.16.0/bin/node',
        '/usr/local/bin/lnstat.js',
        './'
    ], 2, 3);
    let excludeRegexes = [];
    let filterRegexes = [];
    print("checkpoint 2")
    print(args.length)
    for (let i = 0; i < args.length; i++) {
        print(args[i]);
        const arg = new String(args[i]);
        print("checkpoint 2.5")
        if (arg.startsWith("--exclude=") || arg.startsWith("-e=")) {
            excludeRegexes.push(new RegExp(arg.slice(arg.indexOf("=") + 1)));
        } else if (arg.startsWith("--filter=") || arg.startsWith("-f=")) {
            filterRegexes.push(new RegExp(arg.slice(arg.indexOf("=") + 1)));
        } else if (arg === "--help" || arg === "-h" || arg === "-help") {
            showHelp();
            return;
        }
    }
    print("checkpoint 3");
}
main();