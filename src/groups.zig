const std = @import("std");
const linux = std.os.linux;
const version = @import("util/version.zig");
const mem = std.mem;
const uid = linux.uid_t;
const gid = linux.gid_t;
const users = @import("util/users.zig");

const allocator = std.heap.page_allocator;

const application_name = "groups";

const help_message =
\\Usage: groups [OPTION]... [USERNAME]...
\\Print group memberships for each USERNAME or, if no USERNAME is specified, for
\\the current process (which may differ if the groups database has changed).
\\      --help     display this help and exit
\\      --version  output version information and exit
\\
;

pub extern fn getgrouplist(user: [*:0]const u8, group: gid, groups: [*]gid, ngroups: *c_int) callconv(.C) c_int;

pub fn main() !void {

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
        var count: u32 = 0;
        for (arguments[1..]) |argument| {
            if (argument.len > 0 and argument[0] != '-') {
                count +=1;
            }
        }
        if (count == 0) {
            const my_uid = linux.geteuid();
            const pw: *users.Passwd = users.getpwuid(my_uid);
            try display_group(pw.pw_name, pw.pw_gid);
        } else {

        }

        std.os.exit(0);
    } else {
        std.debug.print("{s}: inconsistent state\n", .{application_name});
        std.os.exit(1);
    }

}

pub fn display_group (user: [*:0]const u8, my_gid: gid) !void {
    var user_gid: gid = my_gid;
    var groups: [*]gid = undefined;
    var group_count: c_int = 0;
    var size_iteration = getgrouplist(user, my_gid, groups, &group_count);
    var group_count_usize = @intCast(usize, group_count);
    std.debug.print("{d}\n", .{group_count_usize});
    var group_alloc = try allocator.alloc(gid, group_count_usize);
    groups = group_alloc.ptr;
    var data_iteration = getgrouplist(user, my_gid, groups, &group_count);
    std.debug.print("{d}\n", .{group_count});
    for (groups[0..@intCast(usize, group_count)]) |group| {
        std.debug.print("{d}\n", .{group});
    }
}

pub fn null_pointer_length(ptr: [*:0]u8) usize {
    var result: usize = 0;
    while (ptr[result] != 0) {
        result += 1;
    }
    return result;
}