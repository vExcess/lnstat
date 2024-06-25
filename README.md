# lnstat
Utility for counting lines of source code,
number of comment lines, and blank lines.
Important! Node JS must be installed
on your system to run lnstat.

## Usage
```
usage: lnstat <path> [options]
       lnstat [options] <path>

options:
  -iu, --include-unsupported  Include file count for unsupported file types
  -id, --include-dotfiles     Include hidden directories
  -e,  --exclude=<regex>      Skip paths matching given regex
  -f,  --filter=<regex>       Skip paths not matching given regex
  -h,  --help                 Show this dialog

examples:
    lnstat ./node_modules -f=".*\.ts"
    lnstat --exclude=.*\.css -ia ./
    lnstat ../
```

## Sample Output
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 Language         ⎪ Files ⎪ Lines        ⎪ Code           ⎪ Comments      ⎪ Blanks       ⎪
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 ./               ⎪   235 ⎪       476426 ⎪ 85%     405587 ⎪ 14%     64703 ⎪ 1%      6136 ⎪
 ├─ JavaScript    ⎪     7 ⎪ 68%   325672 ⎪ 100%    325136 ⎪ 0%        156 ⎪ 0%       380 ⎪
 ├─ TypeScript    ⎪   195 ⎪ 26%   124736 ⎪ 44%      54551 ⎪ 52%     64540 ⎪ 5%      5645 ⎪
 ├─ JSON          ⎪    22 ⎪ 5%     25532 ⎪ 100%     25524 ⎪ 0%          0 ⎪ 0%         8 ⎪
 ├─ Plain Text    ⎪     2 ⎪ 0%       250 ⎪ 76%        189 ⎪ 0%          0 ⎪ 24%       61 ⎪
 ├─ Markdown      ⎪     8 ⎪ 0%       197 ⎪ 81%        159 ⎪ 1%          2 ⎪ 18%       36 ⎪
 └─ Zig           ⎪     1 ⎪ 0%        39 ⎪ 72%         28 ⎪ 13%         5 ⎪ 15%        6 ⎪
──────────────────┴───────┴──────────────┴────────────────┴───────────────┴──────────────┘
 .../node_modules ⎪   230 ⎪       475773 ⎪ 85%     405016 ⎪ 14%     64687 ⎪ 1%      6070 ⎪
 ├─ JavaScript    ⎪     7 ⎪ 68%   325672 ⎪ 100%    325136 ⎪ 0%        156 ⎪ 0%       380 ⎪
 ├─ TypeScript    ⎪   194 ⎪ 26%   124175 ⎪ 44%      54052 ⎪ 52%     64529 ⎪ 5%      5594 ⎪
 ├─ JSON          ⎪    20 ⎪ 5%     25494 ⎪ 100%     25490 ⎪ 0%          0 ⎪ 0%         4 ⎪
 ├─ Plain Text    ⎪     2 ⎪ 0%       250 ⎪ 76%        189 ⎪ 0%          0 ⎪ 24%       61 ⎪
 └─ Markdown      ⎪     7 ⎪ 0%       182 ⎪ 82%        149 ⎪ 1%          2 ⎪ 17%       31 ⎪
──────────────────┴───────┴──────────────┴────────────────┴───────────────┴──────────────┘
```

## Understanding the Percents
The percentages in the Code, Comments, and Blanks columns are the percents out of the total lines per type of file.
The percentages in the Lines column are the percents out of the total lines per directory.

## Compile Project
Run `make` to compile the project. `node` and `zig` must be installed. Also `npx` and 
`esbuild` must be installed globally. The output will be in the `dist` directory.

## Build Deb Package
First compile the project. Next run `make deb` to build the deb package. 
The deb package outputted in the `dist` directory.

## Installation
**Debian based Linux distros**: Double click the deb package and press the "Install Package" button.  
**Other Linux distros**: Download the compiled programs from `dist` and add the executable to your PATH.  
**Windows**: Download the repo and required softwares, compile the project, and add the executable to your PATH.  
**Mac**: Last I'm aware, Mac refuses to compile Zig code, so take the common Mac L. I refuse to waste money 
on an overpriced chromebook just to see if it works.

## Uninstallation
**Debian based Linux distros**: Run `sudo apt remove lnstat`.  
**Other Linux distros & Windows**: Remove the executable from your path and delete the compiled program.

## Running as Dev
This project was written using Bun `bun run index.ts` since Bun supports TypeScript natively. 
You can also run the project using Node but you will need to transpile it first.