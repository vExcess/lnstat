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
    lnstat index.js
```

## Sample Output
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 Language         ⎪ Files ⎪ Lines       ⎪ Code         ⎪ Comments   ⎪ Blanks   ⎪ Avg/Max Len ⎪
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 ./               ⎪   244 ⎪      480298 ⎪ 85%   409087 ⎪ 14%  64961 ⎪ 1%  6250 ⎪ 1906  30906 ⎪
 ├─ JavaScript    ⎪     9 ⎪ 68%  328196 ⎪ 100%  327632 ⎪ 0%     167 ⎪ 0%   397 ⎪ 382   22365 ⎪
 ├─ TypeScript    ⎪   196 ⎪ 26%  125475 ⎪ 44%    54961 ⎪ 52%  64787 ⎪ 5%  5727 ⎪ 7884  30906 ⎪
 ├─ JSON          ⎪    25 ⎪ 5%    26057 ⎪ 100%   26045 ⎪ 0%       0 ⎪ 0%    12 ⎪ 2099   5530 ⎪
 ├─ Markdown      ⎪    11 ⎪ 0%      281 ⎪ 83%      232 ⎪ 1%       2 ⎪ 17%   47 ⎪ 678    4488 ⎪
 ├─ Plain Text    ⎪     2 ⎪ 0%      250 ⎪ 76%      189 ⎪ 0%       0 ⎪ 24%   61 ⎪ 357   15193 ⎪
 └─ Zig           ⎪     1 ⎪ 0%       39 ⎪ 72%       28 ⎪ 13%      5 ⎪ 15%    6 ⎪ 35       82 ⎪
──────────────────┴───────┴─────────────┴──────────────┴────────────┴──────────┴─────────────┘
 .../node_modules ⎪   238 ⎪      479097 ⎪ 85%   407978 ⎪ 14%  64945 ⎪ 1%  6174 ⎪ 2250  30767 ⎪
 ├─ JavaScript    ⎪     9 ⎪ 69%  328196 ⎪ 100%  327632 ⎪ 0%     167 ⎪ 0%   397 ⎪ 382   22365 ⎪
 ├─ TypeScript    ⎪   195 ⎪ 26%  124880 ⎪ 44%    54431 ⎪ 52%  64776 ⎪ 5%  5673 ⎪ 7849  30767 ⎪
 ├─ JSON          ⎪    22 ⎪ 5%    25562 ⎪ 100%   25556 ⎪ 0%       0 ⎪ 0%     6 ⎪ 2035   5339 ⎪
 ├─ Plain Text    ⎪     2 ⎪ 0%      250 ⎪ 76%      189 ⎪ 0%       0 ⎪ 24%   61 ⎪ 357   15193 ⎪
 └─ Markdown      ⎪    10 ⎪ 0%      209 ⎪ 81%      170 ⎪ 1%       2 ⎪ 18%   37 ⎪ 626    4373 ⎪
──────────────────┴───────┴─────────────┴──────────────┴────────────┴──────────┴─────────────┘
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