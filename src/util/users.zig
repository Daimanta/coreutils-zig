// BSD 3-clause licensed. Copyright Léon van der Kaap 2021

const std = @import("std");
const linux = std.os.linux;
const mem = std.mem;

const strings = @import("strings.zig");

const uid = linux.uid_t;
const gid = linux.gid_t;

const Allocator = std.mem.Allocator;

const default_allocator = std.heap.page_allocator;

pub const Passwd = extern struct {
    pw_name: [*:0]u8,
    pw_passwd: [*:0]u8,
    pw_uid: uid,
    pw_gid: gid,
    pw_gecos: [*:0]u8,
    pw_dir: [*:0]u8,
    pw_shell: [*:0]u8
};

pub const Group = extern struct {
    gr_name: [*:0]u8,
    gr_passwd: [*:0]u8,
    gr_gid: gid,
    gr_mem: [*][*:0]u8
};

pub extern fn getpwuid (uid: uid) callconv(.C) *Passwd;
pub extern fn getpwnam (name: [*:0]u8) callconv(.C) *Passwd;

pub fn getUserByNameA(name: []const u8) !*Passwd {
    const nameZ = try strings.toNullTerminatedPointer(name, default_allocator);
    defer default_allocator.free(nameZ);
    const result = getpwnam(nameZ);
    if (@ptrToInt(result) == 0) {
        return error.UserNotFound;
    } else {
        return result;
    }
}

pub fn getUserByName(name: [*:0]u8) !*Passwd {
    const result = getpwnam(name);
    if (@ptrToInt(result) == 0) {
        return error.UserNotFound;
    } else {
        return result;
    }
}

pub extern fn getgrgid (gid: gid) callconv(.C) *Group;
extern fn getgrouplist(user: [*:0]const u8, group: gid, groups: [*]gid, ngroups: *c_int) callconv(.C) c_int;

pub fn getGroupsFromPasswd(user: *Passwd, allocator: *Allocator) ![]gid {
    var user_gid: gid = user.pw_gid;
    var groups: [*]gid = undefined;
    var group_count: c_int = 0;

    // Size iteration
    _ = getgrouplist(user.pw_name, user_gid, groups, &group_count);
    var group_count_usize = @intCast(usize, group_count);
    var group_alloc = try allocator.alloc(gid, group_count_usize);
    groups = group_alloc.ptr;
    // Actually allocate the groups
    _ = getgrouplist(user.pw_name, user_gid, groups, &group_count);
    return group_alloc[0..];
}