const std = @import("std");
const linux = std.os.linux;
const version = @import("util/version.zig");
const mem = std.mem;

const Passwd = extern struct {
    pw_name: [*:0]u8,
    pw_uid: linux.uid_t,
    pw_gid: linux.gid_t,
    pw_dir: [*:0]u8,
    pw_shell: [*:0]u8
};

const application_name = "groups";

const help_message =
\\Usage: groups [OPTION]... [USERNAME]...
\\Print group memberships for each USERNAME or, if no USERNAME is specified, for
\\the current process (which may differ if the groups database has changed).
\\      --help     display this help and exit
\\      --version  output version information and exit
\\
;

pub extern fn getpwuid (uid: linux.uid_t) callconv(.C) *Passwd;

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
        version.print_version_info(application_name);
        std.os.exit(0);
    } else if (current_mode == Mode.main) {

        std.os.exit(0);
    } else {
        std.debug.print("{s}: inconsistent state\n", .{application_name});
        std.os.exit(1);
    }

}