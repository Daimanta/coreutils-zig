const std = @import("std");
const fs = std.fs;
const mem = std.mem;
const os = std.os;
const io = std.io;
const testing = std.testing;

const clap = @import("clap.zig");
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
    const params = comptime [_]clap.Param(clap.Help){
        clap.parseParam("--help") catch unreachable,
        clap.parseParam("--version") catch unreachable,
        clap.parseParam("--backup <STR>") catch unreachable,
        clap.parseParam("-b") catch unreachable,
        clap.parseParam("-d, --directory") catch unreachable,
        clap.parseParam("-F") catch unreachable,
        clap.parseParam("-f, --force") catch unreachable,
        clap.parseParam("-i, --interactive") catch unreachable,
        clap.parseParam("-L, --logical") catch unreachable,
        clap.parseParam("-n, --no-dereference") catch unreachable,
        clap.parseParam("-P, --physical") catch unreachable,
        clap.parseParam("-r, --relative") catch unreachable,
        clap.parseParam("-s, --symbolic") catch unreachable,
        clap.parseParam("-S, --suffix <STR>") catch unreachable,
        clap.parseParam("-t, --target-directory <STR>") catch unreachable,
        clap.parseParam("-T, --no-target-directory") catch unreachable,
        clap.parseParam("-v, --verbose") catch unreachable,
        clap.parseParam("<STRING>") catch unreachable,
    };

    var diag = clap.Diagnostic{};
    var args = clap.parseAndHandleErrors(clap.Help, &params, .{ .diagnostic = &diag }, application_name, 1);
    defer args.deinit();

    if (args.flag("--help")) {
       print(help_message, .{});
        std.os.exit(0);
    } else if (args.flag("--version")) {
        version.printVersionInfo(application_name);
        std.os.exit(0);
    }

    const backup = args.option("--backup");
    const directory = args.flag("-d") or args.flag("-F");
    const force = args.flag("-f");
    const interactive = args.flag("-i");
    const logical = args.flag("-L");
    const no_dereference = args.flag("-n");
    const physical = args.flag("-P");
    const relative = args.flag("-r");
    const symbolic = args.flag("-s");
    const suffix = args.option("-S");
    const target_directory = args.option("-t");
    const no_target_directory = args.flag("-T");
    const verbose = args.flag("-v");
    _ = backup; _ = suffix; _ = verbose;
    checkInconsistencies(directory, symbolic, physical, relative, force, interactive, target_directory != null, no_target_directory, logical, no_dereference);
    
    const positionals = args.positionals();
    
    if (positionals.len == 0) {
        print("{s}: No targets specified. Exiting.\n", .{application_name});
        std.os.exit(1);
    } else if (positionals.len == 1) {
    
    } else {
    
    }
    
}

fn checkInconsistencies(directory: bool, symbolic: bool, physical: bool, relative: bool, force: bool, interactive: bool, target_directory: bool, no_target_directory: bool, logical: bool, no_dereference: bool) void {
    if (target_directory and no_target_directory) {
        print("{s}: -t and -T cannot be active at the same time. Exiting.\n", .{application_name});
        std.os.exit(1);
    }
    
    if (force and interactive) {
        print("{s}: -f and -i cannot be active at the same time. Exiting.\n", .{application_name});
        std.os.exit(1);
    }
    
    if ((directory or physical) and (symbolic or relative)) {
        print("{s}: -f or -P cannot be combined with -s or -r. Exiting.\n", .{application_name});
        std.os.exit(1);
    }
    
    if (logical and no_dereference) {
        print("{s}: -L and -n cannot be active at the same time. Exiting.\n", .{application_name});
        std.os.exit(1);
    }

}

