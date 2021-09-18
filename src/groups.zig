const std = @import("std");
const linux = std.os.linux;
const version = @import("util/version.zig");
const mem = std.mem;
const uid = linux.uid_t;
const gid = linux.gid_t;
const users = @import("util/users.zig");
const Allocator = std.mem.Allocator;

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
        current_mode = Mode.main;
    } else if (arguments.len == 2) {
        if (mem.eql(u8, "--help", arguments[1])) {
            current_mode = Mode.help;
        } else if (mem.eql(u8, "--version", arguments[1])) {
            current_mode = Mode.version;
        } else {
            if (arguments[1].len > 0 and arguments[1][0] == '-') {
                std.debug.print("{s}: Unknown argument \"{s}\"\n", .{application_name, arguments[1]});
                std.os.exit(1);
            } else {
                current_mode = Mode.main;
            }
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
            try display_group(pw, false);
        } else {
            for(arguments[1..]) |argument| {
                if (argument.len > 0 and argument[0] != '-') {
                    var user_null_pointer = try to_null_terminated_pointer(argument, allocator);
                    defer allocator.free(user_null_pointer);
                    if (users.get_user_by_name(user_null_pointer)) |pw| {
                        try display_group(pw, true);
                    } else |err| {
                        std.debug.print("{s}: '{s}': no such user\n", .{application_name, argument});
                    }
                }
            }
        }

        std.os.exit(0);
    } else {
        std.debug.print("{s}: inconsistent state\n", .{application_name});
        std.os.exit(1);
    }

}

fn display_group (user: *users.Passwd, print_name: bool) !void {
    var user_gid: gid = user.pw_gid;
    var groups: [*]gid = undefined;
    var group_count: c_int = 0;

    // Size iteration
    _ = getgrouplist(user.pw_name, user_gid, groups, &group_count);
    var group_count_usize = @intCast(usize, group_count);
    var group_alloc = try allocator.alloc(gid, group_count_usize);
    groups = group_alloc.ptr;
    defer allocator.free(group_alloc);
    // Actually allocate the groups
    _ = getgrouplist(user.pw_name, user_gid, groups, &group_count);

    if (print_name) {
        std.debug.print("{s} : ", .{user.pw_name});
    }
    for (groups[0..@intCast(usize, group_count)]) |group| {
        const grp = users.getgrgid(group);
        std.debug.print("{s} ", .{grp.gr_name});
    }
    std.debug.print("\n", .{});
}

fn null_pointer_length(ptr: [*:0]const u8) usize {
    var result: usize = 0;
    while (ptr[result] != 0) {
        result += 1;
    }
    return result;
}

fn to_null_terminated_pointer(slice: []const u8, allocator_impl: *Allocator) ![:0]u8 {
    var result = try allocator_impl.alloc(u8, slice.len + 1);
    for (slice) |byte, i| {
        result[i] = slice[i];
    }
    result[result.len - 1] = 0;
    return result[0..result.len - 1:0];
}