# lnstat
Utility for counting lines of source code,
number of comment lines, and blank lines.

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

## Running as Dev
To run the project without compiling it use `bun run src/lnstat.ts`. This requires that `bun` is installed.

## Compile
Firstly, `node` (v16 or greater) and `zig` (v0.13.0 or greater) must be installed.  
Next, install all required Node modules:
```
npm install -g pkg
npm install -g npx
npm install -g esbuild
```

To compile the shermes version of lnstat you will additionally need to build Static Hermes from source ([How to try Static Hermes](https://github.com/facebook/hermes/discussions/1137))

Then run `make` to build the Node reliant and standalone versions of lnstat. The outputs will be in `dist/node` and `dist/standalone` respectively. You can also run `make shermes` to build the static hermes version of the project. The output will be in `dist/shermes` however the shermes version of the project currently does not work and seg faults when run.

## Build Deb Package
First compile the project following the instructions above. Next run `make deb-node` or `make deb-standalone` to build the deb package for the Node dependent or standalone version of lnstat. The deb package will be output to the `dist` directory. The Node dependent version is a mere 35.5kB however it requires that the user have Node installed on their system. The standalone version is 42.7 MB but can run on systems that do not have Node installed. Ideally I would like to get the shermes version working so that it can be standalone yet lightweight, however shermes is not mature enough of a software to do so just yet.

## Install
For the convenience of Linux users who have Node installed I have provided the `dist/node/lnstat`, `dist/node/lnstat.js` and `/dist/lnstat_x.x-x.deb` files in the repo's dist folder. Therefore you can just download the compiled program and do not need to build it from source.
**Debian based Linux distros**: Download and double click the deb package in `dist` and press the "Install Package" button.  
**Other Linux distros**: Download the files from `dist/node` and add the executable to your PATH.  
**Windows**: Download the repo and required softwares, compile the project, and add the executable to your PATH.  
**Mac**: I have never and will never own a Mac so I don't officially support it, but since Mac OS is Unix based I'd imagine it's not that much harder to compile it from source than it is on Linux.

## Uninstall
**Debian based Linux distros**: Run `sudo apt remove lnstat`.  
**Other**: Remove the executable from your path and delete the compiled program.