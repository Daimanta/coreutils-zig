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
const print = @import("util/print_tools.zig").print;

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
        print(help_message, .{});
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
    
    const errors = checkInconsistencies(must_exist, may_exist, physical, strip, relative_to, relative_base);
    if (errors) os.exit(1);
    
    const positionals = args.positionals();
    
    if (positionals.len == 0) {
        print("{s}: No arguments supplied. Exiting.\n", .{application_name});
        return;
    }
    
    for (positionals, 0..) |arg, i| {
        printRealpath(arg, must_exist, logical, !strip, quiet, relative_to, relative_base, i != positionals.len - 1, separator);
    }
    print("\n", .{});
}

fn checkInconsistencies(must_exist: bool, may_exist: bool, physical: bool, strip: bool, relative_to: ?[]const u8, relative_base: ?[]const u8) bool {
    if (must_exist and may_exist) {
        print("-e and -m cannot be active at the same time. Exiting.\n", .{});
        return true;
    }
    
    if (physical and strip) {
        print("-P and -ms cannot be active at the same time. Exiting.\n", .{});
        return true;
    }
    
    if (relative_to != null and relative_base != null) {
        print("relative_to and relative_base cannot be active at the same time. Exiting.\n", .{});
        return true;
    }
    return false;
}

fn printRealpath(path: []const u8, must_exist: bool, logical: bool, physical: bool, quiet: bool, relative_to: ?[]const u8, relative_base: ?[]const u8, add_separator: bool, separator: []const u8) void {
    _ = logical; // What does this do?
    var exists = true;
    std.fs.cwd().access(path, .{.mode = .read_only}) catch {
        exists = false;
    };
    if (!exists and must_exist) {
        if (!quiet) {
           print("{s}: '{s}' does not exist.", .{application_name, path});
           if (add_separator) print("\n", .{});
        }
        return;
    }
    
    var print_absolute_path = !physical;
    var absolute_path: ?[]const u8 = null;
    
    if (exists and physical) {
        const lstat = fileinfo.getLstat(path) catch return;
        if (fileinfo.isSymlink(lstat)) {
            const symlink_result: fileinfo.FollowSymlinkResult = fileinfo.followSymlink(default_allocator, path, false);
            if (symlink_result.error_result != null) return;
            absolute_path = symlink_result.path;
        } else {
            print_absolute_path = true;
        }
    } else {
        print_absolute_path = true;
    }
    
    if (print_absolute_path) {
        absolute_path = fileinfo.getAbsolutePath(default_allocator, path, relative_to) catch return;
    }
    
    if (absolute_path != null) {
        var start_index: usize = 0;
        if (relative_base != null) {
            if (std.mem.startsWith(u8, absolute_path.?, relative_base.?)) {
                start_index = relative_base.?.len;
                if (absolute_path.?.len > start_index and absolute_path.?[start_index] == '/') {
                    start_index += 1;
                }
            }
        }
        if (start_index >= absolute_path.?.len) {
            print("", .{});
        } else {
            print("{s}", .{absolute_path.?[start_index..]});
        }
        default_allocator.free(absolute_path.?);
    }
    
    if (add_separator) {
        print("{s}", .{separator});
    }
}
