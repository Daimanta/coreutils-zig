// BSD 3-clause licensed. Copyright Léon van der Kaap 2021

const std = @import("std");
const linux = std.os.linux;
const mem = std.mem;

const strings = @import("strings.zig");

const uid = linux.uid_t;
const gid = linux.gid_t;

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