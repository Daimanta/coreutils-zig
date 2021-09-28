const std = @import("std");
const linux = std.os.linux;
const version = @import("util/version.zig");
const mem = std.mem;
const users = @import("util/users.zig");

const application_name = "whoami";

const help_message =
\\Usage: whoami [OPTION]...
\\Print the user name associated with the current effective user ID.
\\Same as id -un.
\\
\\      --help     display this help and exit
\\      --version  output version information and exit
\\
;

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const arguments = try std.process.argsAlloc(allocator);

    const Mode = enum {
        help,
        version,
        main
    };

    var current_mode: ?Mode = null;

    if (arguments.len > 2) {
        std.debug.print("{s}: too many arguments", .{application_name});
        std.os.exit(1);
    } else if (arguments.len == 2) {
        if (mem.eql(u8, "--help", arguments[1])) {
            current_mode = Mode.help;
        } else if (mem.eql(u8, "--version", arguments[1])) {
            current_mode = Mode.version;
        } else {
            std.debug.print("{s}: Unknown argument \"{s}\"\n", .{application_name, arguments[1]});
            std.os.exit(1);
        }
    } else {
        current_mode = Mode.main;
    }

    if (current_mode == Mode.help) {
        std.debug.print("{s}", .{help_message});
        std.os.exit(0);
    } else if (current_mode == Mode.version) {
        version.printVersionInfo(application_name);
        std.os.exit(0);
    } else if (current_mode == Mode.main) {
        const uid = linux.geteuid();
        const pw: *users.Passwd = users.getpwuid(uid);
        std.debug.print("{s}\n", .{pw.pw_name});
        std.os.exit(0);
    } else {
        std.debug.print("{s}: inconsistent state\n", .{application_name});
        std.os.exit(1);
    }

}