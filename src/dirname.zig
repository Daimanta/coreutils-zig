const std = @import("std");
const process = std.process;
const clap = @import("clap.zig");
const version = @import("util/version.zig");
const mem = std.mem;

const print = @import("util/print_tools.zig").print;

const help_message =
\\Usage: dirname [OPTION] NAME...
\\Output each NAME with its last non-slash component and trailing slashes
\\removed; if NAME contains no /'s, output '.' (meaning the current directory).
\\
\\  -z, --zero     end each output line with NUL, not newline
\\      --help     display this help and exit
\\      --version  output version information and exit
\\
\\Examples:
\\  dirname /usr/bin/          -> "/usr"
\\  dirname dir1/str dir2/str  -> "dir1" followed by "dir2"
\\  dirname stdio.h            -> "."
\\
;

const application_name = "dirname";

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const arguments = try std.process.argsAlloc(allocator);

    const Mode = enum {
        help,
        version,
        main
    };

    var current_mode: ?Mode = null;
    var use_null = false;

    if (arguments.len == 2) {
        const arg: []const u8 = arguments[1];
        const help_arg: []const u8 = "--help";
        const version_arg: []const u8 = "--version";
        if (mem.eql(u8, arg, help_arg)) {
            current_mode = Mode.help;
        } else if (mem.eql(u8, arg, version_arg)) {
            current_mode = Mode.version;
        } else if (arguments.len == 1) {
            print("dirname: missing operand\nTry 'dirname --help' for more information.\n", .{});
            std.posix.exit(1);
        } else {
            current_mode = Mode.main;
        }
    } else if (arguments.len == 1) {
        current_mode = Mode.main;
    } else {
        for (arguments[1..]) |arg| {
            if (arg[0] == '-') {
                if (mem.eql(u8, arg, "-z") or mem.eql(u8, arg, "--zero")) {
                    use_null = true;
                } else {
                    print("Unrecognized option '{s}'", .{arg});
                    std.posix.exit(1);
                }
            }
        }
        current_mode = Mode.main;
    }

    if (current_mode == Mode.help) {
        print("{s}", .{help_message});
    } else if (current_mode == Mode.version) {
        version.printVersionInfo(application_name);
    } else if (current_mode == Mode.main) {
        for (arguments[1..]) |elem| {
            if (elem.len == 0 or elem[0] != '-') {
                processPath(elem, use_null);
            }
        }
    } else {
        print("Inconsistent state detected! Exiting.", .{});
        std.posix.exit(1);
    }

}

fn processPath(path: []const u8, use_null: bool) void {
    if (path.len == 0) {
        print(".", .{});
    } else {
        var i: usize = path.len - 1;
        if (path[i] == '/' and i > 0) {
            i -= 1;
        }
        while (i > 0) {
            if (path[i] == '/') break;
            i -= 1;
        }

        if (i == 0) {
            if (path[0] == '/') {
                print("/", .{});
            } else {
                print(".", .{});
            }
        } else {
            var j = i;
            while (j >= 0) {
                j -= 1;
                if (j != '/') break;
            }
            print("{s}", .{path[0..j+1]});
        }
    }

    if (use_null) {
        print("\x00", .{});
    } else {
        print("\n", .{});
    }

}
