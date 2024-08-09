// ---------- TextDecoder & TextEncoder Polyfill -----------
// adapted from https://github.com/anonyco/FastestSmallestTextEncoderDecoder
const fromCharCode = String.fromCharCode;
// NOTE: shermes doesn't support accessing properties of strings
// so I must access it from the prototype and call it using Function.call
const charCodeAt = String.prototype.charCodeAt;

function decoderReplacer(encoded: string) {
    let cp0 = charCodeAt.call(encoded, 0),
        codePoint = 0x110000,
        i = 0,
        stringLen = new String(encoded).length,
        result = "";
    switch (cp0 >>> 4) {
        // no 1 byte sequences
        case 12:
        case 13:
            codePoint = ((cp0 & 0x1F) << 6) | (charCodeAt.call(encoded, 1) & 0x3F);
            i = codePoint < 0x80 ? 0 : 2;
            break;
        case 14:
            codePoint = ((cp0 & 0x0F) << 12) | ((charCodeAt.call(encoded, 1) & 0x3F) << 6) | (charCodeAt.call(encoded, 2) & 0x3F);
            i = codePoint < 0x800 ? 0 : 3;
            break;
        case 15:
            if ((cp0 >>> 3) === 30) {
                codePoint = ((cp0 & 0x07) << 18) | ((charCodeAt.call(encoded, 1) & 0x3F) << 12) | ((charCodeAt.call(encoded, 2) & 0x3F) << 6) | charCodeAt.call(encoded, 3);
                i = codePoint < 0x10000 ? 0 : 4;
            }
    }
    if (i) {
        if (stringLen < i) {
            i = 0;
        } else if (codePoint < 0x10000) { // BMP code point
            result = fromCharCode(codePoint);
        } else if (codePoint < 0x110000) {
            codePoint = codePoint - 0x10080 | 0; //- 0x10000|0;
            result = fromCharCode(
                (codePoint >>> 10) + 0xD800 | 0, // highSurrogate
                (codePoint & 0x3ff) + 0xDC00 | 0 // lowSurrogate
            );
        } else i = 0; // to fill it in with INVALIDs
    }

    for (; i < stringLen; i = i + 1 | 0) result += "\ufffd"; // fill rest with replacement character

    return result;
}

class TextDecoder {
    encoding: string = "utf-8";
    fatal: boolean = false;
    ignoreBOM: boolean = false;

    // NOTE: shermes don't support option parameters
    constructor(label: string/*, options?: {fatal: boolean, ignoreBOM: boolean}*/) {
        // polyfill only supports "utf-8" encoding
        this.encoding = label;
        // if (options) {
        //     this.fatal = options.fatal;
        //     this.ignoreBOM = options.ignoreBOM;
        // }
    }

    // NOTE: shermes does not support using typed arrays or
    // ArrayBuffer as a type so I must use any instead
    decode(inputArrayOrBuffer: any /* TypedArray | ArrayBuffer */) {
        let buffer = (inputArrayOrBuffer && inputArrayOrBuffer.buffer) || inputArrayOrBuffer;
        let inputAs8 = new Uint8Array(buffer);
        let resultingString = "";
        for (let index = 0, len = inputAs8.length | 0; index < len; index = index + 32768 | 0)
            resultingString += fromCharCode.apply(0, inputAs8.slice(index, index + 32768 | 0) as any as number[]);
    
        return String.prototype.replace.call(resultingString, /[\xc0-\xff][\x80-\xbf]+|[\x80-\xff]/g, decoderReplacer);
    }
}

function encoderReplacer(nonAsciiChars: string){
    // make the UTF string into a binary UTF-8 encoded string
    var point = charCodeAt.call(nonAsciiChars, 0)|0;
    if (0xD800 <= point) {
        if (point < 0xDC00) {
            var nextcode = charCodeAt.call(nonAsciiChars, 1)|0; // defaults to 0 when NaN, causing null replacement character
            
            if (0xDC00 <= nextcode && nextcode <= 0xDFFF) {
                //point = ((point - 0xD800)<<10) + nextcode - 0xDC00 + 0x10000|0;
                point = (point<<10) + nextcode - 0x35fdc00|0;
                if (point > 0xffff)
                    return fromCharCode(
                        (0x1e/*0b11110*/<<3) | (point>>>18),
                        (0x2/*0b10*/<<6) | ((point>>>12)&0x3f/*0b00111111*/),
                        (0x2/*0b10*/<<6) | ((point>>>6)&0x3f/*0b00111111*/),
                        (0x2/*0b10*/<<6) | (point&0x3f/*0b00111111*/)
                    );
            } else point = 65533/*0b1111111111111101*/;//return '\xEF\xBF\xBD';//fromCharCode(0xef, 0xbf, 0xbd);
        } else if (point <= 0xDFFF) {
            point = 65533/*0b1111111111111101*/;//return '\xEF\xBF\xBD';//fromCharCode(0xef, 0xbf, 0xbd);
        }
    }
    /*if (point <= 0x007f) return nonAsciiChars;
    else */if (point <= 0x07ff) {
        return fromCharCode((0x6<<5)|(point>>>6), (0x2<<6)|(point&0x3f));
    } else return fromCharCode(
        (0xe/*0b1110*/<<4) | (point>>>12),
        (0x2/*0b10*/<<6) | ((point>>>6)&0x3f/*0b00111111*/),
        (0x2/*0b10*/<<6) | (point&0x3f/*0b00111111*/)
    );
}

class TextEncoder {
    constructor() {
        
    }

    // NOTE: shermes does not support using Uint8Array or
    // ArrayBuffer as a type so I must use any instead
    encode(inputString: any) {
        // 0xc0 => 0b11000000; 0xff => 0b11111111; 0xc0-0xff => 0b11xxxxxx
        // 0x80 => 0b10000000; 0xbf => 0b10111111; 0x80-0xbf => 0b10xxxxxx
        var encodedString = inputString === void 0 ?  "" : String.prototype.replace.call(("" + inputString), /[\x80-\uD7ff\uDC00-\uFFFF]|[\uD800-\uDBFF][\uDC00-\uDFFF]?/g, encoderReplacer);
        var len = new String(encodedString).length|0,
            result = new Uint8Array(len);
        var i=0;
        for (; i<len; i=i+1|0)
            result[i] = charCodeAt.call(encodedString, i) |0;
        return result;
    }

    encodeInto(inputString: string, u8Arr: any /* Uint8Array */) {
        var encodedString = inputString === void 0 ?  "" : String.prototype.replace.call(("" + inputString), /[\x80-\uD7ff\uDC00-\uFFFF]|[\uD800-\uDBFF][\uDC00-\uDFFF]?/g, encoderReplacer);
        var len=new String(encodedString).length|0, i=0, char=0, read=0, u8ArrLen = u8Arr.length|0, inputLength=new String(inputString).length|0;
        if (u8ArrLen < len) len=u8ArrLen;
        putChars: {
            for (; i<len; i=i+1|0) {
                char = charCodeAt.call(encodedString, i) |0;
                // @ts-ignore
                switch(char >>> 4) {
                    case 0:
                    case 1:
                    case 2:
                    case 3:
                    case 4:
                    case 5:
                    case 6:
                    case 7:
                        read = read + 1|0;
                        // extension points:
                    case 8:
                    case 9:
                    case 10:
                    case 11:
                        break;
                    case 12:
                    case 13:
                        if ((i+1|0) < u8ArrLen) {
                            read = read + 1|0;
                            break;
                        }
                    case 14:
                        if ((i+2|0) < u8ArrLen) {
                            read = read + 1|0;
                            break;
                        }
                    case 15:
                        if ((i+3|0) < u8ArrLen) {
                            read = read + 1|0;
                            break;
                        }
                    default:
                        break putChars;
                }
                //read = read + ((char >>> 6) !== 2) |0;
                u8Arr[i] = char;
            }
        }
        return {"written": i, "read": inputLength < read ? inputLength : read};
    }
}
// ---------- ----------




// ---------- console.log Polyfill -----------
const console = {
    log: print,
};
// ---------- ----------




// ---------- process Polyfill -----------
const process = {
    argv: ["ab", "cd", "ef"],
    stdout: {
        write: print
    }
};
// ---------- ----------




// ---------- Zig Bindings ----------
const init = $SHBuiltin.extern_c({ include: "fs-polyfill.h" }, function init(): void {
    throw 0;
});

const createBuffer = $SHBuiltin.extern_c({ include: "fs-polyfill.h" }, function createBuffer(a: c_int): c_int {
    throw 0;
});

const getBufferLen = $SHBuiltin.extern_c({ include: "fs-polyfill.h" }, function getBufferLen(a: c_int): c_int {
    throw 0;
});

const setBufferLen = $SHBuiltin.extern_c({ include: "fs-polyfill.h" }, function setBufferLen(a: c_int, b: c_int): void {
    throw 0;
});

const getBufferByte = $SHBuiltin.extern_c({ include: "fs-polyfill.h" }, function getBufferByte(a: c_int, b: c_int): c_int {
    throw 0;
});

const setBufferByte = $SHBuiltin.extern_c({ include: "fs-polyfill.h" }, function setBufferByte(a: c_int, b: c_int, c: c_int): void {
    throw 0;
});

function getZigString(idx: number) {
    const len = getBufferLen(idx);
    let bytes: number[] = [];
    for (let i = 0; i < len; i++) {
        const byte = getBufferByte(idx, i);
        bytes.push(byte);
    }
    const enc = new TextDecoder("utf-8");
    return enc.decode(bytes);
}

function createZigString(value_: string): number {
    const enc = new TextEncoder();
    const buff = enc.encode(value_);
    const idx = createBuffer(buff.length);
    setBufferLen(idx, buff.length);
    const value = new String(value_);
    for (let i = 0; i < buff.length; i++) {
        setBufferByte(idx, i, value.charCodeAt(i));
    }
    return idx;
}
// ---------- ----------




// ---------- node:fs Polyfill -----------
const readDir = $SHBuiltin.extern_c({ include: "fs-polyfill.h" }, function readDir(a: c_int): c_int {
    throw 0;
});

const lStat = $SHBuiltin.extern_c({ include: "fs-polyfill.h" }, function lStat(a: c_int): c_int {
    throw 0;
});

const readFile = $SHBuiltin.extern_c({ include: "fs-polyfill.h" }, function readFile(a: c_int): c_int {
    throw 0;
});

class fs_Stats {
    // NOTE: shermes doesn't support private variables
    _kind: number = 0;

    constructor(kind: number) {
        this._kind = kind;
    }

    isDirectory(): boolean {
        // NOTE: shermes doesn't support enums
        const DIRECTORY = 1,
              FILE = 2,
              UNKNOWN = 0;
        return this._kind === DIRECTORY;
    }
}

type callbackFxn = (chunk: string) => void;

class fs_ReadStream {
    _path: string = "";
    _dataListener: callbackFxn = (chunk: string): void => {};
    _endListener: callbackFxn = (chunk: string): void => {};
    _hasEndListener = false;

    constructor(path: string) {
        this._path = path;
    }

    on(event: string, callback: callbackFxn): fs_ReadStream {
        switch (event) {
            case "data": {
                // NOTE: shermes seg faults when creating an array of functions
                // Thread 1 "lnstat" received signal SIGSEGV, Segmentation fault.
                // 0x00007ffff7e9396c in _sh_fastarray_push () from /home/vexcess/shermes-linux-x86_64/build_release/lib/libhermesvm.so
                this._dataListener = callback;

                // I'm not sure how I would implement this asyncronously
                const strAddr = createZigString(this._path);
                const contentAddr = readFile(strAddr);
                const data = getZigString(contentAddr);
                this._dataListener(data);
                break;
            }
            case "end": {
                this._endListener = callback;
                if (!this._hasEndListener) {
                    this._endListener("");
                    this._hasEndListener = true;
                }
                break;
            }
        }
        return this;
    }
}

class fsClass {
    // NOTE: shermes doesn't support static methods
    readdirSync(path: string): string[] {
        const addr = createZigString(path);
        const range = readDir(addr);
        const rangeStart = range >> 16;
        const rangeEnd = range & (2**16 - 1);
        let out: string[] = [];
        for (let i = rangeStart; i < rangeEnd; i++) {
            out.push(getZigString(i));
        }
        return out;
    }

    lstatSync(path: string): fs_Stats {
        const addr = createZigString(path);
        const kind = lStat(addr);
        return new fs_Stats(kind);
    }

    createReadStream(path: string, options: { encoding: string }): fs_ReadStream {
        // the only supported encoding is "utf8"
        return new fs_ReadStream(path);
    }
}

// NOTE: When I tried creating a singleton using an object literal isntead of a class
// shermes reported `warning: ft: unsupported property for typed object, assuming 'any'`
const fs = new fsClass();
// ---------- ----------




// ---------- More Polyfills ----------
// NOTE: shermes does not support accessing properties of numbers
function Number_toString(num: number): string {
    return Number.prototype.toString.call(num);
}

// NOTE: shermes does not support Array.prototype.includes
function Array_includes(self: string[], item: string): boolean {
    for (let i = 0; i < self.length; i++) {
        if (self[i] === item) {
            return true;
        }
    }
    return false;
}

// NOTE: shermes does not support Array.prototype.slice
function Array_slice(self: string[], start: number, stop: number): string[] {
    let subArr = [];
    for (let i = start; i < stop; i++) {
        subArr.push(self[i]);
    }
    return subArr;
}

// NOTE: shermes does not support Array.prototype.map
function Array_map(self: any, fxn: (item: any) => any): any {
    let newArr = [];
    for (let i = 0; i < self.length; i++) {
        newArr.push(fxn(self[i]));
    }
    return newArr;
}

// NOTE: shermes does not support Array.prototype.find
function Array_find(self: any, fxn: (item: any) => boolean): any {
    for (let i = 0; i < self.length; i++) {
        if (fxn(self[i])) {
            return self[i];
        }
    }
    return undefined;
}

// NOTE: shermes does not support Array.prototype.join
function Array_join(self: any, joiner: string): string {
    let out = "";
    for (let i = 0; i < self.length; i++) {
        out += self[i] + joiner;
    }
    return out;
}
// ---------- ----------




init();

/*

    lnstat

    This is a utility similiar to github.com/AlDanial/cloc, 
    but it also shows individual stats for sub directories
    and also shows info as percentages.

    I only plan on supporting languages that I use.
    If you want support for other languages leave a pull
    request.

*/

function isDir(path: string) {
    return fs.lstatSync(path).isDirectory();
}

function getFileExt(path_: string) {
    let path = new String(path_);
    let i = path.length - 1;
    while (i > 0) {
        if (path.charAt(i) === "/") {
            return "";
        } else if (path.charAt(i) === ".") {
            let ext = path.slice(i + 1);
            if (ext === "cjs" || ext === "mjs") {
                ext = "js";
            }
            return ext;
        }
        i--;
    }
    return "";
}

const extNameMap = {
    "js": "JavaScript",
    "html": "HTML",
    "css": "CSS",
    "json": "JSON",
    "ts": "TypeScript",
    "md": "Markdown",
    "py": "Python",
    "java": "Java",
    "rs": "Rust",
    "zig": "Zig",
    "c": "C",
    "cpp": "C++",
    "cs": "C#",
    "csx": "C# (csx)",
    "txt": "Plain Text",
    "csv": "CSV"
};

type FileStats = {
    lines: number,
    code: number,
    comments: number,
    blanks: number,
    avgLength: number,
    maxLength: number
};

// NOTE: shermes doesn't support IntersectionTypeAnnotation
type ExtStats = /* FileStats & */{
    lines: number,
    code: number,
    comments: number,
    blanks: number,
    avgLength: number,
    maxLength: number,
    files: number,
};

// NOTE: shermes doesn't support Map or Array as type
type DirStats = {
    path: string,
    extsStats: any /* Map<string, ExtStats> */,
    subDirs: any /* Array<DirStats> */
};

async function getFileStats(path: string, ext: string) /* Promise<FileStats> */ {
    return new globalThis.Promise(resolve => {
        const fileStats: FileStats = {
            lines: 0,
            code: 0,
            comments: 0,
            blanks: 0,
            avgLength: 0,
            maxLength: 0
        };

        const readStream = fs.createReadStream(path, { encoding: 'utf8' });

        let isFirstChunk = true;
        let inSinglelineComment = false;
        let inMultilineComment = false;
        let inSinglelineString = false;
        let inMultilineString = false;
        let stringType = "";
        let isStartOfLine = false;
        let overflowedSlc = "";
        readStream.on('data', (chunk_: string): void => {
            let chunk = new String(chunk_);
            let lineCount = 0;
            let commentCount = 0;
            let blankCount = 0;

            if (isFirstChunk) {
                if (chunk.length > 1) {
                    lineCount++;
                }
                isFirstChunk = false;
            }

            const lines = chunk.split("\n");
            for (let i = 0; i < lines.length; i++) {
                if (lines[i].length > fileStats.maxLength) {
                    fileStats.maxLength = lines[i].length;
                }
            }

            if (Array_includes(["zig", "rs"], ext)) {
                lineCount = lines.length;
                for (let i = 0; i < lines.length; i++) {
                    const trimed = lines[i].trimStart();
                    if (trimed.length === 0) {
                        blankCount++;
                    } else if (trimed.startsWith("//")) {
                        commentCount++;
                    }
                }
            } else if (Array_includes(["py"], ext)) {
                lineCount = lines.length;
                for (let i = 0; i < lines.length; i++) {
                    const trimed = lines[i].trimStart();
                    if (trimed.length === 0) {
                        blankCount++;
                    } else if (trimed.startsWith("#")) {
                        commentCount++;
                    }
                }
            } else if (Array_includes(["html", "xml", "md"], ext)) {
                // we need a 2 char lookahead, this allows that even at chunk borders
                chunk = overflowedSlc + chunk;
                let idx = 0;
                while (idx < chunk.length - 3) {
                    const ch = chunk[idx];
                    if (ch === "\n") {
                        if (isStartOfLine) {
                            blankCount++;
                        } else if (inMultilineComment) {
                            commentCount++;
                        }
                        lineCount++;
                        isStartOfLine = true;
                    } else if (!new String(" \t").includes(ch)) {
                        isStartOfLine = false;
                        if (!inMultilineComment && chunk.slice(idx).startsWith("<!--")) {
                            commentCount++;
                            inMultilineComment = true;
                            idx += 3;
                        } else if (inMultilineComment && chunk.slice(idx).startsWith("-->")) {
                            inMultilineComment = false;
                            idx += 2;
                        }
                    }
                    idx++;
                }
                overflowedSlc = chunk.slice(chunk.length - 3);
            } else if (Array_includes(["js", "ts", "java", "c", "cpp", "cs", "csx", "css"], ext)) {
                // we need a 1 char lookahead, this allows that even at chunk borders
                chunk = overflowedSlc + chunk;
                let idx = 0;
                while (idx < chunk.length - 1) {
                    const ch = chunk[idx];
                    if (ch === "\n") {
                        if (isStartOfLine) {
                            blankCount++;
                        } else if (inMultilineComment) {
                            commentCount++;
                        }
                        inSinglelineComment = false;
                        lineCount++;
                        isStartOfLine = true;
                    } else if (!new String(" \t").includes(ch)) {
                        isStartOfLine = false;
                        if (!inMultilineComment && !inSinglelineComment) {
                            if ((inSinglelineString || inMultilineString) && ch === "\\") {
                                idx += 2;
                                continue;
                            }
                            if (!inSinglelineString && !inMultilineString && ch === "/") {
                                if (chunk[idx+1] === "/" && ext !== "css") {
                                    commentCount++;
                                    inSinglelineComment = true;
                                    idx++;
                                } else if (chunk[idx+1] === "*") {
                                    commentCount++;
                                    inMultilineComment = true;
                                    idx++;
                                }
                            } else if (ch === '"') {
                                if (inSinglelineString && stringType === '"') {
                                    inSinglelineString = false;
                                } else if (!inSinglelineString) {
                                    inSinglelineString = true;
                                    stringType = '"';
                                }
                            } else if (ch === "'") {
                                if (inSinglelineString && stringType === "'") {
                                    inSinglelineString = false;
                                } else if (!inSinglelineString) {
                                    inSinglelineString = true;
                                    stringType = "'";
                                }
                            } else if (ch === "`" && Array_includes(["js", "ts"], ext)) {
                                if (inMultilineString && stringType === "`") {
                                    inMultilineString = false;
                                } else if (!inMultilineString) {
                                    inMultilineString = true;
                                    stringType = "`";
                                }
                            }
                        } else if (inMultilineComment && ch === "*" && chunk[idx+1] === "/") {
                            inMultilineComment = false;
                            idx++;
                        }
                    }
                    idx++;
                }
                overflowedSlc = chunk[chunk.length - 1];
            } else {
                lineCount = lines.length;
                for (let i = 0; i < lines.length; i++) {
                    const trimed = lines[i].trimStart();
                    if (trimed.length === 0) {
                        blankCount++;
                    }
                }
            }

            fileStats.lines += lineCount;
            fileStats.comments += commentCount;
            fileStats.blanks += blankCount;
            fileStats.code += lineCount - commentCount - blankCount;
            fileStats.avgLength += chunk.length;
        }).on('end', (chunk: string): void => {
            if (fileStats.lines > 0) {
                fileStats.avgLength = (fileStats.avgLength - fileStats.lines) / fileStats.lines;
            }
            resolve(fileStats);
        });
    });
}

type getDirStatsOptions = {
    includeUnsupported: boolean,
    includeDotfiles: boolean,
    excludeRegexes: any /* Array<RegExp> */,
    filterRegexes: any /* Array<RegExp> */
};

// NOTE: shermes doesn't support computed access to exact object types
function computedAccess(obj: any, item: string) {
    switch (item) {
        case "js": {
            return obj.js;
        }
        case "html": {
            return obj.html;
        }
        case "css": {
            return obj.css;
        }
        case "json": {
            return obj.json;
        }
        case "ts": {
            return obj.ts;
        }
        case "md": {
            return obj.md;
        }
        case "py": {
            return obj.py;
        }
        case "java": {
            return obj.java;
        }
        case "rs": {
            return obj.rs;
        }
        case "zig": {
            return obj.zig;
        }
        case "c": {
            return obj.c;
        }
        case "cpp": {
            return obj.cpp;
        }
        case "cs": {
            return obj.cs;
        }
        case "csx": {
            return obj.csx;
        }
        case "txt": {
            return obj.txt;
        }
        case "csv": {
            return obj.csv;
        }
    }
    return undefined;
}

// NOTE: typing of pattern parameters not implemented in shermes, :any assumed
async function getDirStats(path_: string, options: getDirStatsOptions, depth: number) {
    let path = new String(path_);
    const dirStats: DirStats = {
        path: path_,
        extsStats: new Map(),
        subDirs: []
    };
    const contents = fs.readdirSync(path_);
    for (let i = 0; i < contents.length; i++) {
        // show loading bar
        if (depth === 0) {
            if (i > 0) {
                process.stdout.write("\r\x1b[K");
            }
            const prog = Math.round(i / contents.length * 100);
            process.stdout.write(`[${new String("#").repeat(prog/2)}${new String("-").repeat(50 - prog/2)}] ${prog}% Complete`);
        }

        const subPath = new String(contents[i]);
        // ignore hidden directories
        if (subPath.charAt(0) !== "." || options.includeDotfiles) {
            let myPath: string;
            if (path.endsWith("/")) {
                myPath = path + subPath.replaceAll("\\", "/");
            } else {
                myPath = path +  "/" + subPath.replaceAll("\\", "/");
            }

            if (isDir(myPath)) {
                const subDirStats = await getDirStats(myPath, options, depth+1);
                dirStats.subDirs.push(subDirStats);
                const subDirExtsStats = Array.from(subDirStats.extsStats.entries());
                for (let k = 0; k < subDirExtsStats.length; k++) {
                    const ext = (subDirExtsStats as any)[k][0];
                    const extStats = (subDirExtsStats as any)[k][1];

                    // create extStats if it doesn't exist
                    let dirExtStats = dirStats.extsStats.get(ext);
                    if (!dirExtStats) {
                        dirExtStats = {
                            files: 0,
                            lines: 0,
                            code: 0,
                            comments: 0,
                            blanks: 0,
                            avgLength: 0,
                            maxLength: 0
                        };
                        dirStats.extsStats.set(ext, dirExtStats);
                    }

                    // NOTE: shermes doesn't support type annotation KeyofTypeAnnotation
                    for (const prop in extStats) {
                        dirExtStats[prop/* as keyof ExtStats*/] += extStats[prop/* as keyof FileStats*/];
                    }
                }
            } else {
                let ignorePath = false;
                for (let j = 0; j < options.excludeRegexes.length; j++) {
                    if (options.excludeRegexes[j].test(myPath)) {
                        ignorePath = true;
                        break;
                    }
                }
                
                for (let j = 0; j < options.filterRegexes.length; j++) {
                    if (!options.filterRegexes[j].test(myPath)) {
                        ignorePath = true;
                        break;
                    }
                }

                if (ignorePath) {
                    continue;
                }

                const ext = getFileExt(myPath);
                const mappedName = computedAccess(extNameMap, ext/* as keyof typeof extNameMap*/);
                if (ext.length !== 0 && (mappedName || options.includeUnsupported)) {
                    let extStats = dirStats.extsStats.get(ext);

                    // create extStats if it doesn't exist
                    if (!extStats) {
                        extStats = {
                            files: 0,
                            lines: 0,
                            code: 0,
                            comments: 0,
                            blanks: 0,
                            avgLength: 0,
                            maxLength: 0
                        };
                        dirStats.extsStats.set(ext, extStats);
                    }

                    extStats.files++;

                    if (mappedName) {
                        const fileStats: any = await getFileStats(myPath, ext);
                        for (const prop in fileStats) {
                            extStats[prop/* as keyof ExtStats*/] += fileStats[prop/* as keyof FileStats*/];
                        }
                    }
                }
            }
        }
    }

    if (depth === 0) {
        process.stdout.write("\r\x1b[K");
    }

    return dirStats;
}

type StringTable = any /*Array<Array<string | Array<string>>>*/;

function tablizeDirStats(stats: DirStats, depth: number, maxDepth: number): any /* StringTable | Array<StringTable> */ {
    const entries: any = Array.from(stats.extsStats.entries());

    const totals = [0, 0, 0, 0, 0, 0, 0];
    for (let i = 0; i < entries.length; i++) {
        const item = entries[i][1];
        totals[0] += item.files;
        totals[1] += item.lines;
        totals[2] += item.code;
        totals[3] += item.comments;
        totals[4] += item.blanks;
        totals[5] += item.avgLength;
        if (item.maxLength > totals[6]) {
            totals[6] = item.maxLength;
        }
    }
    totals[5] = Math.round(totals[5] / entries.length);

    function perc(n: number, d: number) {
        return "" + Math.round(n / d * 100) + "%";
    }

    // NOTE: shermes doesn't support binary operation: + cannot be applied to string and number
    const rows: StringTable = [
        [
            stats.path, 
            Number_toString(totals[0]),
            Number_toString(totals[1]),
            [perc(totals[2], totals[1]), Number_toString(totals[2])],
            [perc(totals[3], totals[1]), Number_toString(totals[3])],
            [perc(totals[4], totals[1]), Number_toString(totals[4])],
            [Number_toString(totals[5]), Number_toString(totals[6])],
        ]
    ];

    // file types with most lines at top
    entries.sort((a: any, b: any) => b[1].lines - a[1].lines);

    for (let i = 0; i < entries.length; i++) {
        const key = entries[i][0];
        const item = entries[i][1];

        const castedKey = key/* as keyof typeof extNameMap*/;
        const rowFirstChar = String.fromCharCode(i < entries.length - 1 ? 9500 : 9492);
        const decor = rowFirstChar + String.fromCharCode(9472) + " ";

        const extName = computedAccess(extNameMap, castedKey) ?? key;

        if (item.lines !== 0) {
            rows.push([
                decor + extName, 
                "" + item.files,
                [perc(item.lines, totals[1]), "" + item.lines], 
                [perc(item.code, item.lines), "" + item.code], 
                [perc(item.comments, item.lines), "" + item.comments], 
                [perc(item.blanks, item.lines), "" + item.blanks],
                ["" + Math.round(item.avgLength), "" + item.maxLength]
            ]);
        } else {
            rows.push([
                decor + extName, 
                "" + item.files, 
                ["", ""], 
                ["", ""], 
                ["", ""], 
                ["", ""],
                ["", ""],
            ]);
        }
    }

    if (depth < maxDepth) {
        const sections = [rows];
        stats.subDirs.forEach((subDir: DirStats) => {
            const subSections = tablizeDirStats(subDir, depth + 1, maxDepth) as StringTable;
            let subPath = new String(subSections[0][0] as string);
            subPath = subPath.replace(stats.path, "");
            subPath = (subPath.startsWith("/") ? "..." : ".../") + subPath;
            subSections[0][0] = subPath;
            sections.push(subSections);
        });
        return sections;
    } else {
        return rows;
    }
}

function mkRow(values: any /* Array<string | Array<string>> */, paddings: number[], aligns: boolean[]) {
    let strRow = "";
    for (let k = 0; k < values.length; k++) {
        const val = values[k];
        let strSlc = "";
        if (typeof val === "string") {
            if (aligns[k]) {
                strSlc = val.padStart(paddings[k], " ");
            } else {
                strSlc = val.padEnd(paddings[k], " ");
            }
        } else {
            strSlc = val[0].padEnd(paddings[k] - val[1].length, " ") + val[1];
        }
        strRow += " " + strSlc + " " + String.fromCharCode(9130);
    }
    return strRow;
}

function displayResults(sections: any /* Array<StringTable> */) {
    const labels = ["Language", "Files", "Lines", "Code", "Comments", "Blanks", "Avg/Max Len"];
    const rightAligned = [false, true, true, true, true, true, true];

    let paddings = Array_map(labels, (l: any): any => l.length);
    for (let i = 0; i < sections.length; i++) {
        const tableRows = sections[i];
        for (let j = 0; j < tableRows.length; j++) {
            const row = tableRows[j];
            for (let k = 0; k < row.length; k++) {
                const item = row[k];
                if (typeof item === "string") {
                    if (item.length > paddings[k]) {
                        paddings[k] = item.length;
                    }
                } else {
                    if (item[0].length + item[1].length + 2 > paddings[k]) {
                        paddings[k] = item[0].length + item[1].length + 2;
                    }
                }
            }
        }
    }
    
    const headRow = mkRow(labels, paddings, Array(labels.length).fill(false));

    const dividerBold = String.fromCharCode(9473).repeat(headRow.length);
    const divider = Array_map(paddings, (n: any): any => String.fromCharCode(9472).repeat(n + 2)).join(String.fromCharCode(9524)) + String.fromCharCode(9496);

    console.log(dividerBold);
    console.log(headRow);
    console.log(dividerBold);
    
    for (let i = 0; i < sections.length; i++) {
        const tableRows = sections[i];
        for (let j = 0; j < tableRows.length; j++) {
            console.log(mkRow(tableRows[j], paddings, rightAligned));
        }
        console.log(divider);
    }
}

function showHelp() {
    const options = Array_map([
        ["-iu, --include-unsupported", "Include file count for unsupported file types"],
        ["-id, --include-dotfiles", "Include hidden directories"],
        ["-e,  --exclude=<regex>", "Skip paths matching given regex"],
        ["-f,  --filter=<regex>", "Skip paths not matching given regex"],
        ["-h,  --help", "Show this dialog"],
    ], (arr: any): any => "  " + arr[0].padEnd(28, " ") + arr[1]).join("\n");
    console.log(Array_join([
        "usage: lnstat <path> [options]\n       lnstat [options] <path>",
        "\noptions:\n" + options,
        '\nexamples:\n    lnstat ./node_modules -f=".*\\.ts"\n    lnstat --exclude=.*\\.css -ia ./\n    lnstat index.js'
    ], "\n"));
}

async function main() {
    const args = Array_slice(process.argv, 2, process.argv.length);
    let includeUnsupported = false;
    let includeDotfiles = false;
    let excludeRegexes = [];
    let filterRegexes = [];
    for (let i = 0; i < args.length; i++) {
        const arg = new String(args[i]);
        if (arg === "--include-unsupported" || arg === "-iu") {
            includeUnsupported = true;
        } else if (arg === "--include-dotfiles" || arg === "-id") {
            includeDotfiles = true;
        } else if (arg.startsWith("--exclude=") || arg.startsWith("-e=")) {
            excludeRegexes.push(new RegExp(arg.slice(arg.indexOf("=") + 1)));
        } else if (arg.startsWith("--filter=") || arg.startsWith("-f=")) {
            filterRegexes.push(new RegExp(arg.slice(arg.indexOf("=") + 1)));
        } else if (arg === "--help" || arg === "-h" || arg === "-help") {
            showHelp();
            return;
        }
    }

    let searchDir = Array_find(args, (arg: any): boolean => arg[0] !== "-");
    if (!searchDir) {
        showHelp();
        return;
    } else {
        searchDir = searchDir.replaceAll("\\", "/");
    }

    let tabledStats: any /*Array<StringTable>*/;
    if (isDir(searchDir)) {
        const stats = await getDirStats(searchDir, {
            includeUnsupported,
            includeDotfiles,
            excludeRegexes,
            filterRegexes
        }, 0);
        tabledStats = tablizeDirStats(stats, 0, 1)/* as Array<StringTable> */;
    } else {
        const ext = getFileExt(searchDir);
        const fileStats: any = await getFileStats(searchDir, ext);
        const dirStats: DirStats  = {
            path: searchDir as string,
            extsStats: new Map(),
            subDirs: []
        };
        dirStats.extsStats.set(ext, {
            files: 1,
            lines: fileStats.lines,
            code: fileStats.code,
            comments: fileStats.comments,
            blanks: fileStats.blanks,
            avgLength: fileStats.avgLength,
            maxLength: fileStats.maxLength
        });
        tabledStats = tablizeDirStats(dirStats, 0, 1)/* as Array<StringTable> */;
    }

    displayResults(tabledStats);
}
main();