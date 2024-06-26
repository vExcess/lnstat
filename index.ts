/*

    lnstat

    This is a utility similiar to github.com/AlDanial/cloc, 
    but it also shows individual stats for sub directories
    and also shows info as percentages.

    I only plan on supporting languages that I use.
    If you want support for other languages leave a pull
    request.

*/

import { file } from "bun";

const fs = require("fs");

function isDir(path: string) {
    return fs.lstatSync(path).isDirectory();
}

function getFileExt(path: string) {
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

type ExtStats = FileStats & {
    files: number,
};

type DirStats = {
    path: string,
    extsStats: Map<string, ExtStats>,
    subDirs: Array<DirStats>
};

async function getFileStats(path: string, ext: string): Promise<FileStats> {
    return new Promise(resolve => {
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
        readStream.on('data', (chunk: string) => {
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

            if (["zig", "rs"].includes(ext)) {
                lineCount = lines.length;
                for (let i = 0; i < lines.length; i++) {
                    const trimed = lines[i].trimStart();
                    if (trimed.length === 0) {
                        blankCount++;
                    } else if (trimed.startsWith("//")) {
                        commentCount++;
                    }
                }
            } else if (["py"].includes(ext)) {
                lineCount = lines.length;
                for (let i = 0; i < lines.length; i++) {
                    const trimed = lines[i].trimStart();
                    if (trimed.length === 0) {
                        blankCount++;
                    } else if (trimed.startsWith("#")) {
                        commentCount++;
                    }
                }
            } else if (["html", "xml", "md"].includes(ext)) {
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
                    } else if (!" \t".includes(ch)) {
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
            } else if (["js", "ts", "java", "c", "cpp", "cs", "csx", "css"].includes(ext)) {
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
                    } else if (!" \t".includes(ch)) {
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
                            } else if (ch === "`" && ["js", "ts"].includes(ext)) {
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
        }).on('end', () => {
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
    excludeRegexes: Array<RegExp>,
    filterRegexes: Array<RegExp>
};
async function getDirStats(path: string, options: getDirStatsOptions, depth=0) {
    const dirStats: DirStats = {
        path,
        extsStats: new Map(),
        subDirs: []
    };
    const contents = fs.readdirSync(path);
    for (let i = 0; i < contents.length; i++) {
        // show loading bar
        if (depth === 0) {
            if (i > 0) {
                process.stdout.write("\r\x1b[K");
            }
            const prog = Math.round(i / contents.length * 100);
            process.stdout.write(`[${"#".repeat(prog/2)}${"-".repeat(50 - prog/2)}] ${prog}% Complete`);
        }

        const subPath = contents[i];
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
                    const ext = subDirExtsStats[k][0];
                    const extStats = subDirExtsStats[k][1];

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

                    for (const prop in extStats) {
                        dirExtStats[prop as keyof ExtStats] += extStats[prop as keyof FileStats];
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
                const mappedName = extNameMap[ext as keyof typeof extNameMap];
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
                        const fileStats = await getFileStats(myPath, ext);
                        for (const prop in fileStats) {
                            extStats[prop as keyof ExtStats] += fileStats[prop as keyof FileStats];
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

type StringTable = Array<Array<string | Array<string>>>;

function tablizeDirStats(stats: DirStats, depth: number, maxDepth: number): StringTable | Array<StringTable> {
    const entries = Array.from(stats.extsStats.entries());

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

    const rows: StringTable = [
        [
            stats.path, 
            "" + totals[0],
            "" + totals[1],
            [perc(totals[2], totals[1]), "" + totals[2]],
            [perc(totals[3], totals[1]), "" + totals[3]],
            [perc(totals[4], totals[1]), "" + totals[4]],
            ["" + totals[5], "" + totals[6]],
        ]
    ];

    // file types with most lines at top
    entries.sort((a, b) => b[1].lines - a[1].lines);

    for (let i = 0; i < entries.length; i++) {
        const key = entries[i][0];
        const item = entries[i][1];

        const castedKey = key as keyof typeof extNameMap;
        const rowFirstChar = String.fromCharCode(i < entries.length - 1 ? 9500 : 9492);
        const decor = rowFirstChar + String.fromCharCode(9472) + " ";
        const extName = extNameMap[castedKey] ?? key;

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
            let subPath = subSections[0][0] as string;
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

function mkRow(values: Array<string | Array<string>>, paddings: Array<number>, aligns: Array<boolean>) {
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

function displayResults(sections: Array<StringTable>) {
    const labels = ["Language", "Files", "Lines", "Code", "Comments", "Blanks", "Avg/Max Len"];
    const rightAligned = [false, true, true, true, true, true, true];

    let paddings = labels.map(l => l.length);
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
    const divider = paddings.map(n => String.fromCharCode(9472).repeat(n + 2)).join(String.fromCharCode(9524)) + String.fromCharCode(9496);

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
    const options = [
        ["-iu, --include-unsupported", "Include file count for unsupported file types"],
        ["-id, --include-dotfiles", "Include hidden directories"],
        ["-e,  --exclude=<regex>", "Skip paths matching given regex"],
        ["-f,  --filter=<regex>", "Skip paths not matching given regex"],
        ["-h,  --help", "Show this dialog"],
    ].map(arr => "  " + arr[0].padEnd(28, " ") + arr[1]).join("\n");
    console.log([
        "usage: lnstat <path> [options]\n       lnstat [options] <path>",
        "\noptions:\n" + options,
        '\nexamples:\n    lnstat ./node_modules -f=".*\\.ts"\n    lnstat --exclude=.*\\.css -ia ./\n    lnstat index.js'
    ].join("\n"));
}

async function main() {
    const args = process.argv.slice(2);
    let includeUnsupported = false;
    let includeDotfiles = false;
    let excludeRegexes = [];
    let filterRegexes = [];
    for (let i = 0; i < args.length; i++) {
        const arg = args[i];
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

    let searchDir = args.find(arg => arg[0] !== "-");
    if (!searchDir) {
        showHelp();
        return;
    } else {
        searchDir = searchDir.replaceAll("\\", "/");
    }

    let tabledStats: Array<StringTable>;
    if (isDir(searchDir)) {
        const stats = await getDirStats(searchDir, {
            includeUnsupported,
            includeDotfiles,
            excludeRegexes,
            filterRegexes
        });
        tabledStats = tablizeDirStats(stats, 0, 1) as Array<StringTable>;
    } else {
        const ext = getFileExt(searchDir);
        const fileStats = await getFileStats(searchDir, ext);
        const dirStats: DirStats = {
            path: searchDir,
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
        tabledStats = tablizeDirStats(dirStats, 0, 1) as Array<StringTable>;
    }

    displayResults(tabledStats);
}
main();