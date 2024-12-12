module Bootstrap

import "std/datatypes/list.rl";
import "std/colors.rl";
import "std/utils.rl";
import "clap/clap.rl"; as clap

enum Flag {
    Verbose = 1 << Utils::iota(),
}

fn check_all_file_extensions_match(@const @ref files) {
    let ext = none;
    foreach f in files.split(" ") {
        with parts = f.split(".") in
        if len(parts) > 1 {
            if ext == none {
                ext = some(parts.back());
            }
            else if ext.unwrap() != parts.back() {
                none;
            }
        }
    }
    ext;
}

fn sep_list_to_space_str(@const @ref lst, delim) {
    lst
        .split(delim)
        .fold(|f, acc| {
            case acc of {
                "" = f;
                _ = acc+' '+f;
            };
        }, "");
}

fn determine_compiler(ext) {
    with compiler = {
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
        "f90": "gfortran"
    }[ext] in

    case compiler of {
        none = panic(f"no known compiler for extension: {ext}");
        _ = compiler.unwrap();
    };
}

fn get_run(@const @ref options, state) {
    options["run"].unwrap();
}

fn get_files(@const @ref options) {
    with _Files = options["files"].unwrap() in
    case _Files of {
        none = [];
        _ = sep_list_to_space_str(_Files.unwrap(), ",");
    };
}

fn get_flags(@const @ref options) {
    with _Flags = options["flags"].unwrap() in
    case _Flags of {
        none = "";
        _ = sep_list_to_space_str(_Flags.unwrap(), " ");
    };
}

fn get_compiler(@const @ref options, @const @ref files) {
    let compiler, guessed = ("", false);
    with _Compiler = options["compiler"].unwrap() in
    if _Compiler == none {
        with ext = check_all_file_extensions_match(files) in
        compiler = case ext of {
            none = panic("cannot determine compiler from file extensions (mixed extensions or no extensions found)");
            _ = determine_compiler(ext.unwrap());
        };
        guessed = true;
    }
    else {
        compiler = _Compiler.unwrap();
    }
    (compiler, guessed);
}

@pub fn run(@const @ref args) {
    let options, runtime_flags, state = (
        {
            "run": none,
            "compiler": none,
            "files": none,
            "flags": none
        },
        {
            "v": Flag.Verbose,
            "verbose": Flag.Verbose
        },
        0,
    );

    foreach arg in clap::parse(args) {
        if arg.is_assignment() {
            with parts = arg.get_assignment() in
            if options[arg.lx] {
                options[arg.lx].unwrap() = some(parts[1]);
            }
            else {
                panic(f"unknown option: {parts}");
            }
        }
        else if arg.is_one_hyph() && runtime_flags[arg.lx] {
            state `|= int(runtime_flags[arg.lx].unwrap());
        }
        else if arg.is_two_hyph() && runtime_flags[arg.lx] {
            state `|= int(runtime_flags[arg.lx].unwrap());
        }
        else {
            panic(f"unknown option: ", arg.get_actual());
        }
    }

    @const let run = get_run(options, state);
    @const let files = get_files(options);
    @const let flags = get_flags(options);
    @const let compiler, guessed = get_compiler(options, files);

    if (state `& Flag.Verbose) != 0 {
        println(Colors::Tfc.Green, f"run={run}", Colors::Te.Reset);
        println(Colors::Tfc.Green, f"files={files}", Colors::Te.Reset);
        println(Colors::Tfc.Green, f"flags={flags}", Colors::Te.Reset);
        print(Colors::Tfc.Green, f"compiler={compiler}", Colors::Te.Reset);
        println(
            case guessed of {
                true = Colors::Tfc.Yellow + f" (guessed)" + Colors::Te.Reset;
                _ = "";
            }
        );
    }

    $f"{compiler} {flags} {files}";

    if run {
        $run.unwrap();
    }
}
