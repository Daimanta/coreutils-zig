const std = @import("std");
const fs = std.fs;
const os = std.os;
const io = std.io;

const clap = @import("clap.zig");
const version = @import("util/version.zig");
const strings = @import("util/strings.zig");
const time_info = @import("util/time.zig");
const utmp = @import("util/utmp.zig");

const Allocator = std.mem.Allocator;
const time_t = time_info.time_t;

const allocator = std.heap.page_allocator;

const application_name = "realpath";

const help_message =
\\Usage: realpath [OPTION]... FILE...
\\Print the resolved absolute file name;
\\all but the last component must exist
\\
\\  -e, --canonicalize-existing  all components of the path must exist
\\  -m, --canonicalize-missing   no path components need exist or be a directory
\\  -L, --logical                resolve '..' components before symlinks
\\  -P, --physical               resolve symlinks as encountered (default)
\\  -q, --quiet                  suppress most error messages
\\      --relative-to=DIR        print the resolved path relative to DIR
\\      --relative-base=DIR      print absolute paths unless paths below DIR
\\  -s, --strip, --no-symlinks   don't expand symlinks
\\  -z, --zero                   end each output line with NUL, not newline
\\
\\      --help     display this help and exit
\\      --version  output version information and exit
\\
;


pub fn main() !void {
    const params = comptime [_]clap.Param(clap.Help){
        clap.parseParam("-e, --canonicalize-existing") catch unreachable,
        clap.parseParam("-m, --canonicalize-missing") catch unreachable,
        clap.parseParam("-L, --logical") catch unreachable,
        clap.parseParam("-P, --physical") catch unreachable,
        clap.parseParam("-q, --quiet") catch unreachable,
        clap.parseParam("--relative-to <STR>") catch unreachable,
        clap.parseParam("--relative-base <STR>") catch unreachable,
        clap.parseParam("-s, --strip") catch unreachable,
        clap.parseParam("--no-symlinks") catch unreachable,
        clap.parseParam("-z") catch unreachable,
        clap.parseParam("--help") catch unreachable,
        clap.parseParam("--version") catch unreachable,
        clap.parseParam("<STRING>") catch unreachable,
    };

    var diag = clap.Diagnostic{};
    var args = clap.parseAndHandleErrors(clap.Help, &params, .{ .diagnostic = &diag }, application_name, 1);
    defer args.deinit();
    
    const must_exist = args.flag("-e");
    const may_exist = args.flag("-m");
    const logical = args.flag("-L");
    const physical = args.flag("-P");
    const quiet = args.flag("-q");
    const relative_to = args.option("--relative-to");
    const relative_base = args.option("--relative-base");
    const strip = args.flag("-s") or args.flag("--no-symlinks");
    const zero = args.flag("-z");
    

    if (args.flag("--help")) {
        std.debug.print(help_message, .{});
        std.os.exit(0);
    } else if (args.flag("--version")) {
        version.printVersionInfo(application_name);
        std.os.exit(0);
    }
    
    checkInconsistencies(must_exist, may_exist, logical, physical, strip);
    
}

fn checkInconsistencies(must_exist: bool, may_exist: bool, logical: bool, physical: bool, strip: bool) void {
    
}


