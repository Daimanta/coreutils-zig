const std = @import("std");
const linux = std.os.linux;

const mem = std.mem;
const uid = linux.uid_t;
const gid = linux.gid_t;

const version = @import("util/version.zig");
const users = @import("util/users.zig");
const strings = @import("util/strings.zig");

const Allocator = std.mem.Allocator;

const allocator = std.heap.page_allocator;
const print = @import("util/print_tools.zig").print;

const application_name = "groups";

const help_message =
\\Usage: groups [OPTION]... [USERNAME]...
\\Print group memberships for each USERNAME or, if no USERNAME is specified, for
\\the current process (which may differ if the groups database has changed).
\\      --help     display this help and exit
\\      --version  output version information and exit
\\
;

extern fn getgrouplist(user: [*:0]const u8, group: gid, groups: [*]gid, ngroups: *c_int) callconv(.C) c_int;

pub fn main() !void {

    const arguments = try std.process.argsAlloc(allocator);

    const Mode = enum {
        help,
        version,
        main
    };

    var current_mode: ?Mode = null;
    if (arguments.len > 2) {
        current_mode = Mode.main;
    } else if (arguments.len == 2) {
        if (mem.eql(u8, "--help", arguments[1])) {
            current_mode = Mode.help;
        } else if (mem.eql(u8, "--version", arguments[1])) {
            current_mode = Mode.version;
        } else {
            if (arguments[1].len > 0 and arguments[1][0] == '-') {
                print("{s}: Unknown argument \"{s}\"\n", .{application_name, arguments[1]});
                std.posix.exit(1);
            } else {
                current_mode = Mode.main;
            }
        }
    } else {
        current_mode = Mode.main;
    }

    if (current_mode == Mode.help) {
        print("{s}", .{help_message});
        std.posix.exit(0);
    } else if (current_mode == Mode.version) {
        version.printVersionInfo(application_name);
        std.posix.exit(0);
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
            try displayGroup(pw, false);
        } else {
            for(arguments[1..]) |argument| {
                if (argument.len > 0 and argument[0] != '-') {
                    const user_null_pointer = try strings.toNullTerminatedPointer(argument, allocator);
                    defer allocator.free(user_null_pointer);
                    const user: ?*users.Passwd = users.getUserByName(user_null_pointer) catch blk: {
                        print("{s}: '{s}': no such user\n", .{application_name, argument});
                        break :blk null;
                    };
                    if (user != null) {
                        try displayGroup(user.?, true);
                    }
                }
            }
        }

        std.posix.exit(0);
    } else {
        print("{s}: inconsistent state\n", .{application_name});
        std.posix.exit(1);
    }

}

fn displayGroup (user: *users.Passwd, print_name: bool) !void {
    const user_gid: gid = user.pw_gid;
    var groups: [*]gid = undefined;
    var group_count: c_int = 0;

    // Size iteration
    _ = getgrouplist(user.pw_name, user_gid, groups, &group_count);
    const group_count_usize: usize = @intCast(group_count);
    const group_alloc = try allocator.alloc(gid, group_count_usize);
    groups = group_alloc.ptr;
    defer allocator.free(group_alloc);
    // Actually allocate the groups
    _ = getgrouplist(user.pw_name, user_gid, groups, &group_count);

    if (print_name) {
        print("{s} : ", .{user.pw_name});
    }
    for (groups[0..@intCast(group_count)]) |group| {
        const grp = users.getgrgid(group);
        print("{s} ", .{grp.gr_name});
    }
    print("\n", .{});
}
