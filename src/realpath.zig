const std = @import("std");
const fs = std.fs;
const os = std.os;
const io = std.io;

const clap = @import("clap.zig");
const fileinfo = @import("util/fileinfo.zig");
const version = @import("util/version.zig");
const strings = @import("util/strings.zig");
const time_info = @import("util/time.zig");
const utmp = @import("util/utmp.zig");

const Allocator = std.mem.Allocator;
const time_t = time_info.time_t;

const default_allocator = std.heap.page_allocator;
const print = std.debug.print;

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
    
    if (args.flag("--help")) {
        std.debug.print(help_message, .{});
        std.os.exit(0);
    } else if (args.flag("--version")) {
        version.printVersionInfo(application_name);
        std.os.exit(0);
    }
    
    const must_exist = args.flag("-e");
    const may_exist = args.flag("-m");
    const logical = args.flag("-L");
    const physical = args.flag("-P");
    const quiet = args.flag("-q");
    const relative_to = args.option("--relative-to");
    const relative_base = args.option("--relative-base");
    const strip = args.flag("-s") or args.flag("--no-symlinks");
    const zero = args.flag("-z");
    
    const separator = if (zero) "\x00" else "\n";
    _ = relative_to;
    _ = relative_base;
    
    checkInconsistencies(must_exist, may_exist, physical, strip);
    
    const positionals = args.positionals();
    
    if (positionals.len == 0) {
        print("{s}: No arguments supplied. Exiting.\n", .{application_name});
        return;
    }
    
    for (positionals) |arg, i| {
        printRealpath(arg, must_exist, logical, !strip, quiet, i != positionals.len - 1, separator);
    }
    print("\n", .{});
}

fn checkInconsistencies(must_exist: bool, may_exist: bool, physical: bool, strip: bool) void {
    if (must_exist and may_exist) {
        print("-e and -m cannot be active at the same time. Exiting.\n", .{});
    }
    
    if (physical and strip) {
        print("-P and -ms cannot be active at the same time. Exiting.\n", .{});
    }
}

fn printRealpath(path: []const u8, must_exist: bool, logical: bool, physical: bool, quiet: bool, add_separator: bool, separator: []const u8) void {
    _ = logical;
    var exists = true;
    std.fs.cwd().access(path, .{.write = false}) catch {
        exists = false;
    };
    if (!exists and must_exist) {
        if (!quiet) {
           print("{s}: '{s}' does not exist.\n", .{application_name, path});
        }
        return;
    }
    
    var print_absolute_path = !physical;
    
    if (exists and physical) {
        const lstat = fileinfo.getLstat(path) catch return;
        if (fileinfo.isSymlink(lstat)) {
            // Follow symlink recursively and determine real path
        } else {
            print_absolute_path = true;
        }
    } else {
        print_absolute_path = true;
    }
    
    if (print_absolute_path) {
        const absolute_path = fileinfo.getAbsolutePath(default_allocator, path) catch return;
        defer default_allocator.free(absolute_path);
        print("{s}", .{absolute_path});
    }
    
    if (add_separator) {
        print("{s}", .{separator});
    }
}


