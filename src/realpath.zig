const std = @import("std");
const fs = std.fs;
const os = std.os;
const io = std.io;

const clap2 = @import("clap2/clap2.zig");
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
    const args: []const clap2.Argument = &[_]clap2.Argument{
        clap2.Argument.FlagArgument(null, &[_][]const u8{"help"}),
        clap2.Argument.FlagArgument(null, &[_][]const u8{"version"}),
        clap2.Argument.FlagArgument("e", &[_][]const u8{"canonicalize-existing"}),
        clap2.Argument.FlagArgument("m", &[_][]const u8{"canonicalize-missing"}),
        clap2.Argument.FlagArgument("L", &[_][]const u8{"logical"}),
        clap2.Argument.FlagArgument("P", &[_][]const u8{"physical"}),
        clap2.Argument.FlagArgument("q", &[_][]const u8{"quiet"}),
        clap2.Argument.FlagArgument("s", &[_][]const u8{"strip", "no-symlinks"}),
        clap2.Argument.FlagArgument("z", null),
        clap2.Argument.OptionArgument(null, &[_][]const u8{"relative-to"}, false),
        clap2.Argument.OptionArgument(null, &[_][]const u8{"relative-base"}, false),
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

    const must_exist = parser.flag("e");
    const may_exist = parser.flag("m");
    const logical = parser.flag("L");
    const physical = parser.flag("P");
    const quiet = parser.flag("q");
    const relative_to = parser.option("relative-to");
    const relative_base = parser.option("relative-base");
    const strip = parser.flag("s");
    const zero = parser.flag("z");
    
    const separator = if (zero) "\x00" else "\n";
    
    const errors = checkInconsistencies(must_exist, may_exist, physical, strip, relative_to.value, relative_base.value);
    if (errors) std.posix.exit(1);
    
    const positionals = parser.positionals();
    
    if (positionals.len == 0) {
        print("{s}: No arguments supplied. Exiting.\n", .{application_name});
        return;
    }
    
    for (positionals, 0..) |arg, i| {
        printRealpath(arg, must_exist, logical, !strip, quiet, relative_to.value, relative_base.value, i != positionals.len - 1, separator);
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
