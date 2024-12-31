const std = @import("std");
const fs = std.fs;
const mem = std.mem;
const os = std.os;
const io = std.io;
const testing = std.testing;

const clap2 = @import("clap2/clap2.zig");
const fileinfo = @import("util/fileinfo.zig");
const version = @import("util/version.zig");

const Allocator = std.mem.Allocator;
const LinkError = os.LinkError;

const default_allocator = std.heap.page_allocator;
const print = @import("util/print_tools.zig").print;

const application_name = "ln";

const help_message =
\\Usage: ln [OPTION]... [-T] TARGET LINK_NAME
\\  or:  ln [OPTION]... TARGET
\\  or:  ln [OPTION]... TARGET... DIRECTORY
\\  or:  ln [OPTION]... -t DIRECTORY TARGET...
\\In the 1st form, create a link to TARGET with the name LINK_NAME.
\\In the 2nd form, create a link to TARGET in the current directory.
\\In the 3rd and 4th forms, create links to each TARGET in DIRECTORY.
\\Create hard links by default, symbolic links with --symbolic.
\\By default, each destination (name of new link) should not already exist.
\\When creating hard links, each TARGET must exist.  Symbolic links
\\can hold arbitrary text; if later resolved, a relative link is
\\interpreted in relation to its parent directory.
\\
\\Mandatory arguments to long options are mandatory for short options too.
\\      --backup[=CONTROL]      make a backup of each existing destination file
\\  -b                          like --backup but does not accept an argument
\\  -d, -F, --directory         allow the superuser to attempt to hard link
\\                                directories (note: will probably fail due to
\\                                system restrictions, even for the superuser)
\\  -f, --force                 remove existing destination files
\\  -i, --interactive           prompt whether to remove destinations
\\  -L, --logical               dereference TARGETs that are symbolic links
\\  -n, --no-dereference        treat LINK_NAME as a normal file if
\\                                it is a symbolic link to a directory
\\  -P, --physical              make hard links directly to symbolic links
\\  -r, --relative              create symbolic links relative to link location
\\  -s, --symbolic              make symbolic links instead of hard links
\\  -S, --suffix=SUFFIX         override the usual backup suffix
\\  -t, --target-directory=DIRECTORY  specify the DIRECTORY in which to create
\\                                the links
\\  -T, --no-target-directory   treat LINK_NAME as a normal file always
\\  -v, --verbose               print name of each linked file
\\      --help     display this help and exit
\\      --version  output version information and exit
\\
\\The backup suffix is '~', unless set with --suffix or SIMPLE_BACKUP_SUFFIX.
\\The version control method may be selected via the --backup option or through
\\the VERSION_CONTROL environment variable.  Here are the values:
\\
\\  none, off       never make backups (even if --backup is given)
\\  numbered, t     make numbered backups
\\  existing, nil   numbered if numbered backups exist, simple otherwise
\\  simple, never   always make simple backups
\\
\\
;

var handled_stdin = false;

const HashError = error{ FileDoesNotExist, IsDir, FileAccessFailed, OtherError };

pub fn main() !void {
    const args: []const clap2.Argument = &[_]clap2.Argument{
        clap2.Argument.FlagArgument(null, &[_][]const u8{"help"}),
        clap2.Argument.FlagArgument(null, &[_][]const u8{"version"}),
        clap2.Argument.FlagArgument("b", null),
        clap2.Argument.FlagArgument("d", &[_][]const u8{"directory"}),
        clap2.Argument.FlagArgument("F", null),
        clap2.Argument.FlagArgument("f", &[_][]const u8{"force"}),
        clap2.Argument.FlagArgument("i", &[_][]const u8{"interactive"}),
        clap2.Argument.FlagArgument("L", &[_][]const u8{"logical"}),
        clap2.Argument.FlagArgument("n", &[_][]const u8{"no-dereference"}),
        clap2.Argument.FlagArgument("P", &[_][]const u8{"physical"}),
        clap2.Argument.FlagArgument("r", &[_][]const u8{"relative"}),
        clap2.Argument.FlagArgument("s", &[_][]const u8{"symbol"}),
        clap2.Argument.FlagArgument("T", &[_][]const u8{"no-target-directory"}),
        clap2.Argument.FlagArgument("v", &[_][]const u8{"verbose"}),
        clap2.Argument.OptionArgument(null, &[_][]const u8{"backup"}, false),
        clap2.Argument.OptionArgument("S", &[_][]const u8{"suffix"}, false),
        clap2.Argument.OptionArgument("t", &[_][]const u8{"target-directory"}, false),
    };

    var parser = clap2.Parser.init(args);
    defer parser.deinit();

    if (parser.flag("help")) {
        print(help_message, .{});
        std.posix.exit(0);
    } else if (parser.flag("version")) {
        version.printVersionInfo(application_name);
        std.posix.exit(0);
    }

    const backup = parser.option("backup");
    const directory = parser.flag("d") or parser.flag("F");
    const force = parser.flag("f");
    const interactive = parser.flag("i");
    const logical = parser.flag("L");
    const no_dereference = parser.flag("n");
    const physical = parser.flag("P");
    const relative = parser.flag("r");
    const symbolic = parser.flag("s");
    const suffix = parser.option("S");
    const target_directory = parser.option("t");
    const no_target_directory = parser.flag("T");
    const verbose = parser.flag("v");
    _ = backup; _ = suffix; _ = verbose;
    checkInconsistencies(directory, symbolic, physical, relative, force, interactive, target_directory.found, no_target_directory, logical, no_dereference);
    
    const positionals = parser.positionals();
    
    if (positionals.len == 0) {
        print("{s}: No targets specified. Exiting.\n", .{application_name});
        std.posix.exit(1);
    } else if (positionals.len == 1) {
    
    } else {
    
    }
    
}

fn checkInconsistencies(directory: bool, symbolic: bool, physical: bool, relative: bool, force: bool, interactive: bool, target_directory: bool, no_target_directory: bool, logical: bool, no_dereference: bool) void {
    if (target_directory and no_target_directory) {
        print("{s}: -t and -T cannot be active at the same time. Exiting.\n", .{application_name});
        std.posix.exit(1);
    }
    
    if (force and interactive) {
        print("{s}: -f and -i cannot be active at the same time. Exiting.\n", .{application_name});
        std.posix.exit(1);
    }
    
    if ((directory or physical) and (symbolic or relative)) {
        print("{s}: -f or -P cannot be combined with -s or -r. Exiting.\n", .{application_name});
        std.posix.exit(1);
    }
    
    if (logical and no_dereference) {
        print("{s}: -L and -n cannot be active at the same time. Exiting.\n", .{application_name});
        std.posix.exit(1);
    }

}

