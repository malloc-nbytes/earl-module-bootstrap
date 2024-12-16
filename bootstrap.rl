# MIT License

# Copyright (c) 2024 malloc-nbytes

# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

module Bootstrap

import "std/colors.rl";
import "std/utils.rl";
import "std/system.rl";

enum Flag {
    Verbose = 1 << Utils::iota(),
}

let FLAGS = 0;

@const let VALID_2HYPH_FLAGS, VALID_1HYPH_FLAGS, VALID_CONFIG_OPTIONS, VALID_COMPILERS = (
    {"verbose": Flag.Verbose},
    {"v": Flag.Verbose},
    {
        # left: option, right: types it can be
        "compiler": [str],
        "files": [str, list, tuple],
        "flags": [str, list, tuple],
        "run": [str]
    },
    {
        # left: file ext., right: compiler/interpreter
        "c": "gcc",
        "cpp": "g++",
        "cxx": "g++",
        "hpp": "g++",
        "hxx": "g++",
        "py": "python3",
        "rs": "rustc",
        "java": "javac",
        "go": "go",
        "swift": "swift",
        "kt": "kotlinc",
        "ts": "tsc",
        "pl": "perl",
        "rb": "ruby",
        "php": "php",
        "sh": "bash",
        "lua": "lua",
        "hs": "ghc",
        "m": "clang",
        "fs": "fsharpc",
        "d": "dmd",
        "r": "Rscript",
        "ex": "elixir",
        "scala": "scalac",
        "adb": "gnat",
        "f90": "gfortran",
        "ml": "ocamlc"
    },
);

fn check_all_file_extensions_match(@const @ref files) {
    let ext, buf = (none, []);
    foreach f in files.split(" ") {
        with parts = f.split(".") in
        if len(parts) > 1 {
            buf.append(f);
            if ext == none {
                ext = some(parts.back());
            }
            else if ext.unwrap() != parts.back() {
                panic(
                    "Cannot guess compiler from mixed file extensions. "
                    + "Got `." + ext.unwrap()
                    + "` but also got `." + parts.back() + "`."
                    + "\n  Examined files: " + str(buf)
                );
            }
        }
    }

    if ext == none {
        panic("cannot guess compiler from no file extensions");
    }

    ext.unwrap();
}

@world fn determine_compiler(ext) {
    with compiler = VALID_COMPILERS[ext] in

    case compiler of {
        none = panic(f"no known compiler for extension `.{ext}`");
        _ = compiler.unwrap();
    };
}

fn get_all_files() {
    let files = [];
    with progname = argv()[0] in
    System::ls(".").foreach(|f| {
        with parts = f.split("."),
             not_bin = parts.back() != "out" && parts.back() != "bin" in
        if f != progname && "./" + f != progname && not_bin && len(parts) > 1 {
            files.append(f);
        }
    });
    files;
}

@world fn __build(config) {
    foreach key, value in config {
        if !VALID_CONFIG_OPTIONS[key] {
            panic(f"invalid option: {key}");
        }
        if !VALID_CONFIG_OPTIONS[key].unwrap().contains(typeof(value)) {
            panic(f"invalid datatype for value: {value}. Expected: ", VALID_CONFIG_OPTIONS[key].unwrap());
        }
    }

    let flags = case config["flags"] of {
        none = "";
        _ = case typeof(config["flags"].unwrap()) of {
                list = config["flags"].unwrap().fold(|f, acc| { acc + ' ' + f; }, "");
                tuple = config["flags"].unwrap().fold(|f, acc| { acc + ' ' + f; }, "");
                _ = config["flags"].unwrap();
        };
    };

    let files = case config["files"] of {
        none = get_all_files().fold(|f, acc| { acc + ' ' + f; }, "");
        _ = case typeof(config["files"].unwrap()) of {
                list = config["files"].unwrap().fold(|f, acc| { acc + ' ' + f; }, "");
                tuple = config["files"].unwrap().fold(|f, acc| { acc + ' ' + f; }, "");
                _ = config["files"].unwrap();
        };
    };

    let compiler, guessed = ("", false);
    if config["compiler"] {
        compiler = config["compiler"].unwrap();
    }
    else {
        compiler = determine_compiler(check_all_file_extensions_match(files));
        guessed = true;
    }

    if (FLAGS `& Flag.Verbose) != 0 {
        println(Colors::Tfc.Green, "***Bootstrap**************");
        println(Colors::Tfc.Green, f"Platform: ", __OS__);
        println(Colors::Tfc.Green, f"Compiler: {compiler}", case guessed of {
            true = Colors::Tfc.Yellow + " (guessed)";
            _ = "";
        });
        if files != "" {
            println(Colors::Tfc.Green, f"Files: {files}");
        }
        if flags != "" {
            println(Colors::Tfc.Green, f"Flags: {flags}", Colors::Te.Reset);
        }
        if !config["run"] {
            println(Colors::Tfc.Green, "**************************", Colors::Te.Reset);
        }
    }

    $compiler + ' ' + flags + ' ' + files;

    if config["run"] {
        if (FLAGS `& Flag.Verbose) != 0 {
            println(Colors::Tfc.Green, f"Run: ", config["run"].unwrap(), Colors::Te.Reset);
            println(Colors::Tfc.Green, "**************************", Colors::Te.Reset);
        }
        $config["run"].unwrap();
    }
}

@world fn handle_cli_flag(arg) {
    if arg.substr(0, 2) == "--" {
        let actual = arg.substr(2, len(arg));
        if !VALID_2HYPH_FLAGS[actual] {
            panic(f"invalid option: {actual}");
        }
        FLAGS `|= VALID_2HYPH_FLAGS[actual].unwrap();
    }
    else if arg[0] == '-' {
        let actual = arg.substr(1, len(arg));
        if !VALID_1HYPH_FLAGS[actual] {
            panic(f"invalid option: {actual}");
        }
        FLAGS `|= VALID_1HYPH_FLAGS[actual].unwrap();
    }
    else {
        panic(__FILE__, ':', __FUNC__, ": invalid cli flag passed");
    }
}

#-- Name: build
#-- Returns: unit
#-- Description:
#--   Run bootstrap with the options
#--   supplied through the CLI.
#--
#--   Valid options are:
#--     - compiler
#--     - run
#--     - files (comma sep list or space sep string)
#--     - flags (comma sep list or space sep string)
#--   The options and values are separated by `=`.
#--
#--   Examples:
#--     earl my-script.rl -- files=main.c,test.c,*.hpp flags="-o main" compiler=gcc run=./main
#--
#--   Note: None of what you supply is directly required, as it will
#--         try to guess how to build based off of the files in the
#--         given directory.
@pub fn build(): unit {
    let config = Dict(str);

    foreach arg in argv()[1:] {
        with parts = arg.split("=").filter(|k| { k != ""; }) in
        if len(parts) > 1 {
            with left = parts[0], right = parts[1] in
            if left == "files" || left == "flags" {
                with commas = right
                                  .split(",")
                                  .filter(|k| { k != ""; }) in
                config
                    .insert(left, right.split(
                        case len(commas) == 1 of {
                            true = " ";
                            _ = ",";
                        })
                       .filter(|k| { k != ""; })
                    );
            }
            else {
                config.insert(left, right);
            }
        }
        else if arg[0] == '-' {
            handle_cli_flag(arg);
        }
        else {
            panic(f"invalid argument: {arg}");
        }
    }

    __build(config);
}

#-- Name: buildconf
#-- Parameter: config: dictionary
#-- Returns: unit
#-- Description:
#--   Launch bootstrap with the options supplied
#--   through a `dictionary` instead of CLI args.
#--
#--   Examples:
#--     Bootstrap::buildconf({
#--         "compiler": "gcc",
#--         "files": ["main.c", "test.c", "*.hpp"],
#--         "flags": "-o main",
#--         "run": "./main"
#--     });
#--
#--   Note: See `help(Bootstrap::build)` to see
#--         all options
@pub fn buildconf(config: dictionary): unit {
    foreach arg in argv()[1:] {
        if arg[0] == '-' {
            handle_cli_flag(arg);
        }
    }
    __build(config);
}
