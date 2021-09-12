const std = @import("std");
const process = std.process;
const clap = @import("clap.zig");
const version = @import("util/version.zig");
const mem = std.mem;

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

    if (arguments.len == 2) {
        var arg: []const u8 = arguments[1];
        const help_arg: []const u8 = "--help";
        const version_arg: []const u8 = "--version";
        if (mem.eql(u8, arg, help_arg)) {
            current_mode = Mode.help;
        } else if (mem.eql(u8, arg, version_arg)) {
            current_mode = Mode.version;
        } else if (arguments.len == 1) {
            std.debug.print("dirname: missing operand\nTry 'dirname --help' for more information.\n", .{});
            std.os.exit(1);
        } else {
            current_mode = Mode.main;
        }
    }

    if (current_mode == Mode.help) {
        std.debug.print("{s}", .{help_message});
    } else if (current_mode == Mode.version) {
        version.print_version_info(application_name);
    } else if (current_mode == Mode.main) {
        std.debug.print("{s}", .{"~"});
    } else {
        std.debug.print("Inconsistent state detected! Exiting.", .{});
        std.os.exit(1);
    }

}