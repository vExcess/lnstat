import 'dart:io';
import 'dart:convert';

Object? find(List<Object> arr, bool Function(dynamic) fn) {
    for (var i = 0; i < arr.length; i++) {
        if (fn(arr[i])) {
            return arr[i];
        }
    }
    return null;
}

List<dynamic> map(List<Object> arr, dynamic Function(dynamic) fn) {
    var newArr = [];
    for (var i = 0; i < arr.length; i++) {
        newArr.add(fn(arr[i]));
    }
    return newArr;
}

String repeat(String str, num times) {
    var out = "";
    for (var i = 0; i < times; i++) {
        out += str;
    }
    return out;
}

Stream createReadStream(String path) {
    final file = File(path);
    // Stream<List<int>> stream = ;
    return file.openRead().transform(utf8.decoder);
}

int round(num n) {
    return n.round();
}
int floor(num n) {
    return n.floor();
}
int ceil(num n) {
    return n.ceil();
}

class Slice {
    String str = "";
    int start = 0;
    int end = 0;

    Slice(String str, int start, [int end=-1]) {
        this.str = str;
        this.start = start;
        if (end == -1) {
            this.end = str.length;
        } else {
            this.end = end;
        }
    }

    Slice substring(int start, [int end=-1]) {
        if (end == -1) {
            end = this.str.length;
        }
        return Slice(this.str, start, end);
    }

    bool startsWith(String str) {
        if (str.length > this.str.length) {
            return false;
        } else {
            for (int i = 0; i < str.length; i++) {
                if (this.str[i] != str[i]) {
                    return false;
                }
            }
        }

        return true;
    }
}

// --- --- --- --- --- --- --- --- --- ---

bool isDir(String path) {
    return FileStat.statSync(path).type == FileSystemEntityType.directory;
}

String getFileExt(String path) {
    var i = path.length - 1;
    while (i > 0) {
        if (path[i] == "/") {
            return "";
        } else if (path[i] == ".") {
            var ext = path.substring(i + 1);
            if (ext == "cjs" || ext == "mjs") {
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
    "cc": "C++",
    "dart": "Dart",
    "cs": "C#",
    "csx": "C# (csx)",
    "txt": "Plain Text",
    "csv": "CSV"
};

typedef FileStats = Map<String, int>;
typedef ExtStats = Map<String, int>;

class DirStats {
    String path = "";
    Map<String, ExtStats> extsStats = Map();
    List<DirStats> subDirs = [];
    DirStats({String? path, Map<String, ExtStats>? extsStats, List<DirStats>? subDirs}) {
        this.path = path as String;
        this.extsStats = extsStats as Map<String, ExtStats>;
        this.subDirs = subDirs as List<DirStats>;
    }
    String toString() {
        return "path: ${this.path}\nextsStats: ${this.extsStats}\nsubDirs: ${this.subDirs}";
    }
}

Future<FileStats> getFileStats(String path, String ext) async {
    final FileStats fileStats = {
        'lines': 0,
        'code': 0,
        'comments': 0,
        'blanks': 0,
        'avgLength': 0,
        'maxLength': 0
    };

    final readStream = createReadStream(path);

    var isFirstChunk = true;
    var inSinglelineComment = false;
    var inMultilineComment = false;
    var inSinglelineString = false;
    var inMultilineString = false;
    var stringType = "";
    var isStartOfLine = false;
    var overflowedSlc = Slice("", 0);

    await for (var chunk in readStream) {
        var lineCount = 0;
        var commentCount = 0;
        var blankCount = 0;

        if (isFirstChunk) {
            if (chunk.length > 1) {
                lineCount++;
            }
            isFirstChunk = false;
        }

        final lines = chunk.split("\n");
        for (var i = 0; i < lines.length; i++) {
            if (lines[i].length > fileStats['maxLength']) {
                fileStats['maxLength'] = lines[i].length;
            }
        }

        if (["zig", "rs"].contains(ext)) {
            lineCount = lines.length;
            for (var i = 0; i < lines.length; i++) {
                final trimed = lines[i].trimLeft();
                if (trimed.length == 0) {
                    blankCount++;
                } else if (trimed.startsWith("//")) {
                    commentCount++;
                }
            }
        } else if (["py"].contains(ext)) {
            lineCount = lines.length;
            for (var i = 0; i < lines.length; i++) {
                final trimed = lines[i].trimLeft();
                if (trimed.length == 0) {
                    blankCount++;
                } else if (trimed.startsWith("#")) {
                    commentCount++;
                }
            }
        } else if (["html", "xml", "md"].contains(ext)) {
            // we need a 2 char lookahead, this allows that even at chunk borders
            chunk = overflowedSlc.str + chunk;
            var chunkSlice = Slice(chunk, 0);
            var idx = 0;
            while (idx < chunk.length - 3) {
                final ch = chunk[idx];
                if (ch == "\n") {
                    if (isStartOfLine) {
                        blankCount++;
                    } else if (inMultilineComment) {
                        commentCount++;
                    }
                    lineCount++;
                    isStartOfLine = true;
                } else if (!" \t".contains(ch)) {
                    isStartOfLine = false;
                    if (!inMultilineComment && chunkSlice.substring(idx).startsWith("<!--")) {
                        commentCount++;
                        inMultilineComment = true;
                        idx += 3;
                    } else if (inMultilineComment && chunkSlice.substring(idx).startsWith("-->")) {
                        inMultilineComment = false;
                        idx += 2;
                    }
                }
                idx++;
            }
            overflowedSlc = Slice(chunk, chunk.length - 3);
        } 
        else if (["js", "ts", "java", "c", "cpp", "cs", "csx", "css", "dart"].contains(ext)) {
            // we need a 1 char lookahead, this allows that even at chunk borders
            chunk = overflowedSlc.str + chunk;
            var idx = 0;
            while (idx < chunk.length - 1) {
                final ch = chunk[idx];
                if (ch == "\n") {
                    if (isStartOfLine) {
                        blankCount++;
                    } else if (inMultilineComment) {
                        commentCount++;
                    }
                    inSinglelineComment = false;
                    lineCount++;
                    isStartOfLine = true;
                } else if (!" \t".contains(ch)) {
                    isStartOfLine = false;
                    if (!inMultilineComment && !inSinglelineComment) {
                        if ((inSinglelineString || inMultilineString) && ch == "\\") {
                            idx += 2;
                            continue;
                        }
                        if (!inSinglelineString && !inMultilineString && ch == "/") {
                            if (chunk[idx+1] == "/" && ext != "css") {
                                commentCount++;
                                inSinglelineComment = true;
                                idx++;
                            } else if (chunk[idx+1] == "*") {
                                commentCount++;
                                inMultilineComment = true;
                                idx++;
                            }
                        } else if (ch == '"') {
                            if (inSinglelineString && stringType == '"') {
                                inSinglelineString = false;
                            } else if (!inSinglelineString) {
                                inSinglelineString = true;
                                stringType = '"';
                            }
                        } else if (ch == "'") {
                            if (inSinglelineString && stringType == "'") {
                                inSinglelineString = false;
                            } else if (!inSinglelineString) {
                                inSinglelineString = true;
                                stringType = "'";
                            }
                        } else if (ch == "`" && ["js", "ts"].contains(ext)) {
                            if (inMultilineString && stringType == "`") {
                                inMultilineString = false;
                            } else if (!inMultilineString) {
                                inMultilineString = true;
                                stringType = "`";
                            }
                        }
                    } else if (inMultilineComment && ch == "*" && chunk[idx+1] == "/") {
                        inMultilineComment = false;
                        idx++;
                    }
                }
                idx++;
            }
            overflowedSlc = Slice(chunk[chunk.length - 1], 0);
        } else {
            lineCount = lines.length;
            for (var i = 0; i < lines.length; i++) {
                final trimed = lines[i].trimLeft();
                if (trimed.length == 0) {
                    blankCount++;
                }
            }
        }

        fileStats['lines'] = (fileStats['lines'] as int) + lineCount;
        fileStats['comments'] = (fileStats['comments'] as int) + commentCount;
        fileStats['blanks'] = (fileStats['blanks'] as int) + blankCount;
        fileStats['code'] = (fileStats['code'] as int) + lineCount - commentCount - blankCount;
        fileStats['avgLength'] = (fileStats['avgLength'] as int) + chunk.length as int;
    }

    if (fileStats['lines'] as int > 0) {
        fileStats['avgLength'] = round(((fileStats['avgLength'] as int) - (fileStats['lines'] as int)) / (fileStats['lines'] as int));
    }

    return fileStats;
}

class GetDirStatsOptions {
    bool includeUnsupported = false;
    bool includeDotfiles = false;
    List<RegExp> excludeRegexes = [];
    List<RegExp> filterRegexes = [];
    GetDirStatsOptions({bool? includeUnsupported, bool? includeDotfiles, List<RegExp>? excludeRegexes, List<RegExp>? filterRegexes}) {
        this.includeUnsupported = includeUnsupported as bool;
        this.includeDotfiles = includeDotfiles as bool;
        this.excludeRegexes = excludeRegexes as List<RegExp>;
        this.filterRegexes = filterRegexes as List<RegExp>;
    }
}

Future<DirStats> getDirStats(String path, GetDirStatsOptions options, [int depth=0]) async {
    final dirStats = DirStats(
        path: path,
        extsStats: new Map(),
        subDirs: []
    );

    final contents = Directory(path).listSync();
    for (var i = 0; i < contents.length; i++) {
        // show loading bar
        if (depth == 0) {
            if (i > 0) {
                stdout.write("\r\x1b[K");
            }
            final prog = round(i / contents.length * 100);
            final hashes = repeat("#", floor(prog/2));
            final dashes = repeat("-", ceil(50 - prog/2));
            stdout.write("[${hashes}${dashes}] ${prog}% Complete");
        }

        // ignore hidden directories
        String myPath = contents[i].path;
        var startIdx = myPath.lastIndexOf("/");
        if (startIdx == -1) {
            startIdx = myPath.lastIndexOf("\\");
        }
        var subPath = myPath.substring(startIdx + 1);
        if ((subPath[0] != "." || (subPath[1] == "/" || subPath[1] == "\\")) || options.includeDotfiles) {
            if (isDir(myPath)) {
                final subDirStats = await getDirStats(myPath, options, depth+1);
                dirStats.subDirs.add(subDirStats);
                final subDirExtsStats = List.from(subDirStats.extsStats.entries);
                for (var k = 0; k < subDirExtsStats.length; k++) {
                    final ext = subDirExtsStats[k].key;
                    final extStats = subDirExtsStats[k].value;

                    // create extStats if it doesn't exist
                    late ExtStats dirExtStats;
                    if (dirStats.extsStats.containsKey(ext)) {
                        dirExtStats = dirStats.extsStats[ext] as ExtStats;
                    } else {
                        dirExtStats = {
                            'files': 0,
                            'lines': 0,
                            'code': 0,
                            'comments': 0,
                            'blanks': 0,
                            'avgLength': 0,
                            'maxLength': 0
                        };
                        dirStats.extsStats[ext] = dirExtStats;
                    }

                    for (final prop in extStats.keys) {
                        dirExtStats[prop] = ((dirExtStats[prop] as int) + extStats[prop]) as int;
                    }
                }
            } else {
                var ignorePath = false;
                for (var j = 0; j < options.excludeRegexes.length; j++) {
                    if (options.excludeRegexes[j].hasMatch(myPath)) {
                        ignorePath = true;
                        break;
                    }
                }
                
                for (var j = 0; j < options.filterRegexes.length; j++) {
                    if (!options.filterRegexes[j].hasMatch(myPath)) {
                        ignorePath = true;
                        break;
                    }
                }

                if (ignorePath) {
                    continue;
                }

                final ext = getFileExt(myPath);
                String? mappedName;
                if (extNameMap.containsKey(ext)) {
                    mappedName = extNameMap[ext];
                } else {
                    mappedName = null;
                }
                if (ext.length != 0 && (mappedName != null || options.includeUnsupported)) {
                    ExtStats extStats;

                    // create extStats if it doesn't exist
                    if (dirStats.extsStats.containsKey(ext)) {
                        extStats = dirStats.extsStats[ext] as ExtStats;
                    } else {
                        extStats = {
                            'files': 0,
                            'lines': 0,
                            'code': 0,
                            'comments': 0,
                            'blanks': 0,
                            'avgLength': 0,
                            'maxLength': 0
                        };
                        dirStats.extsStats[ext] = extStats;
                    }

                    extStats['files'] = (extStats['files'] as int) + 1;

                    if (mappedName != null) {
                        final fileStats = await getFileStats(myPath, ext);
                        for (final prop in fileStats.keys) {
                            extStats[prop] = (extStats[prop] as int) + (fileStats[prop] as int);
                        }
                    }
                }
            }
        }
    }

    if (depth == 0) {
        stdout.write("\r\x1b[K");
    }

    return dirStats;
}

// ideally not dynamic, but was converted from TS and I don't want to rewrite
typedef StringTable = List<dynamic>; // Array<Array<string | Array<string>>>;
/*StringTable | Array<StringTable>*/ dynamic tablizeDirStats(DirStats stats, int depth, int maxDepth) {
    final entries = List.from(stats.extsStats.entries);

    final totals = [0, 0, 0, 0, 0, 0, 0];
    for (var i = 0; i < entries.length; i++) {
        final item = entries[i].value;
        totals[0] += item['files'] as int;
        totals[1] += item['lines'] as int;
        totals[2] += item['code'] as int;
        totals[3] += item['comments'] as int;
        totals[4] += item['blanks'] as int;
        totals[5] += item['avgLength'] as int;
        if (item['maxLength'] > totals[6]) {
            totals[6] = item['maxLength'];
        }
    }
    if (entries.length != 0) {
        totals[5] = round(totals[5] / entries.length);
    }

    String perc(num n, num d) {
        if (d == 0) {
            return "";
        }
        return "${round(n / d * 100)}%";
    }

    final StringTable rows = [
        [
            stats.path, 
            "${totals[0]}",
            "${totals[1]}",
            [perc(totals[2], totals[1]), "${totals[2]}"],
            [perc(totals[3], totals[1]), "${totals[3]}"],
            [perc(totals[4], totals[1]), "${totals[4]}"],
            ["${totals[5]}", "${totals[6]}"],
        ]
    ];

    // file types with most lines at top
    entries.sort((a, b) => b.value['lines'] - a.value['lines']);

    for (var i = 0; i < entries.length; i++) {
        final key = entries[i].key;
        final item = entries[i].value;

        final rowFirstChar = String.fromCharCode(i < entries.length - 1 ? 9500 : 9492);
        final decor = rowFirstChar + String.fromCharCode(9472) + " ";
        final extName = extNameMap.containsKey(key) ? extNameMap[key] : key;

        if (item['lines'] != 0) {
            rows.add([
                decor + extName, 
                "${item['files']}",
                [perc(item['lines'], totals[1]), "${item['lines']}"], 
                [perc(item['code'], item['lines']), "${item['code']}"], 
                [perc(item['comments'], item['lines']), "${item['comments']}"], 
                [perc(item['blanks'], item['lines']), "${item['blanks']}"],
                ["${round(item['avgLength'])}", "${item['maxLength']}"]
            ]);
        } else {
            rows.add([
                decor + extName, 
                "${item['files']}", 
                ["", ""], 
                ["", ""], 
                ["", ""], 
                ["", ""],
                ["", ""],
            ]);
        }
    }

    if (depth < maxDepth) {
        final sections = [rows];
        for (var i = 0; i < stats.subDirs.length; i++) {
            final subDir = stats.subDirs[i];
            final subSections = tablizeDirStats(subDir, depth + 1, maxDepth) as StringTable;
            var subPath = subSections[0][0] as String;
            subPath = subPath.replaceFirst(stats.path, "");
            subPath = (subPath.startsWith("/") ? "..." : ".../") + subPath;
            subSections[0][0] = subPath;
            sections.add(subSections);
        }
        return sections;
    } else {
        return rows;
    }
}

String mkRow(List<Object> values, List<int> paddings, List<bool> aligns) {
    var strRow = "";
    for (var k = 0; k < values.length; k++) {
        var val = values[k];
        var strSlc = "";
        if (val is String) {
            if (aligns[k]) {
                strSlc = val.padLeft(paddings[k], " ");
            } else {
                strSlc = val.padRight(paddings[k], " ");
            }
        } else {
            val = val as List;
            strSlc = val[0].padRight(paddings[k] - val[1].length, " ") + val[1];
        }
        strRow += " " + strSlc + " " + String.fromCharCode(9130);
    }
    return strRow;
}

void displayResults(List<StringTable> sections) {
    const labels = ["Language", "Files", "Lines", "Code", "Comments", "Blanks", "Avg/Max Len"];
    const rightAligned = [false, true, true, true, true, true, true];

    List<int> paddings = List.from(labels.map((l) => l.length));
    for (var i = 0; i < sections.length; i++) {
        final tableRows = sections[i];
        for (var j = 0; j < tableRows.length; j++) {
            final row = tableRows[j];
            for (var k = 0; k < row.length; k++) {
                final item = row[k];
                if (item is String) {
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
    
    final headRow = mkRow(labels, paddings, List<bool>.filled(labels.length, false));

    final dividerBold = repeat(String.fromCharCode(9473), headRow.length);
    final divider = paddings.map((n) => repeat(String.fromCharCode(9472), n + 2)).join(String.fromCharCode(9524)) + String.fromCharCode(9496);

    print(dividerBold);
    print(headRow);
    print(dividerBold);
    
    for (var i = 0; i < sections.length; i++) {
        final tableRows = sections[i];
        for (var j = 0; j < tableRows.length; j++) {
            print(mkRow(tableRows[j], paddings, rightAligned));
        }
        print(divider);
    }
}

void showHelp() {
    final options = [
        ["-iu, --include-unsupported", "Include file count for unsupported file types"],
        ["-id, --include-dotfiles", "Include hidden directories"],
        ["-e,  --exclude=<regex>", "Skip paths matching given regex"],
        ["-f,  --filter=<regex>", "Skip paths not matching given regex"],
        ["-h,  --help", "Show this dialog"],
    ].map((arr) => "  " + arr[0].padRight(28, " ") + arr[1]).join("\n");
    print([
        "usage: lnstat <path> [options]\n       lnstat [options] <path>",
        "\noptions:\n" + options,
        '\nexamples:\n    lnstat ./node_modules -f=".*\\.ts"\n    lnstat --exclude=.*\\.css -ia ./\n    lnstat index.js'
    ].join("\n"));
}

void main(List<String> args) async {
    var includeUnsupported = false;
    var includeDotfiles = false;
    List<RegExp> excludeRegexes = [];
    List<RegExp> filterRegexes = [];
    for (var i = 0; i < args.length; i++) {
        final arg = args[i];
        if (arg == "--include-unsupported" || arg == "-iu") {
            includeUnsupported = true;
        } else if (arg == "--include-dotfiles" || arg == "-id") {
            includeDotfiles = true;
        } else if (arg.startsWith("--exclude=") || arg.startsWith("-e=")) {
            excludeRegexes.add(RegExp(arg.substring(arg.indexOf("=") + 1)));
        } else if (arg.startsWith("--filter=") || arg.startsWith("-f=")) {
            filterRegexes.add(RegExp(arg.substring(arg.indexOf("=") + 1)));
        } else if (arg == "--help" || arg == "-h" || arg == "-help") {
            showHelp();
            return;
        }
    }

    var searchDir = find(args, (arg) => arg[0] != "-") as String?;
    if (searchDir == null) {
        showHelp();
        return;
    } else {
        searchDir = (searchDir ).replaceAll("\\", "/");
    }

    List<StringTable> tabledStats;
    if (isDir(searchDir)) {
        final stats = await getDirStats(searchDir, GetDirStatsOptions(
            includeUnsupported: includeUnsupported,
            includeDotfiles: includeDotfiles,
            excludeRegexes: excludeRegexes,
            filterRegexes: filterRegexes
        ));
        tabledStats = tablizeDirStats(stats, 0, 1) as List<StringTable>;
    } else {
        final ext = getFileExt(searchDir);
        final fileStats = await getFileStats(searchDir, ext);
        var dirStats = DirStats(
            path: searchDir,
            extsStats: new Map(),
            subDirs: []
        );
        dirStats.extsStats[ext] = {
            'files': 1,
            'lines': fileStats['lines'] as int,
            'code': fileStats['code'] as int,
            'comments': fileStats['comments'] as int,
            'blanks': fileStats['blanks'] as int,
            'avgLength': fileStats['avgLength'] as int,
            'maxLength': fileStats['maxLength'] as int
        };
        tabledStats = tablizeDirStats(dirStats, 0, 1) as List<StringTable>;
    }

    displayResults(tabledStats);
}