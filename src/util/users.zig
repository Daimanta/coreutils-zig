const std = @import("std");
const linux = std.os.linux;
const version = @import("util/version.zig");
const mem = std.mem;
const uid = linux.uid_t;
const gid = linux.gid_t;

pub const Passwd = extern struct {
    pw_name: [*:0]u8,
    pw_uid: uid,
    pw_gid: gid,
    pw_dir: [*:0]u8,
    pw_shell: [*:0]u8
};

pub extern fn getpwuid (uid: uid) callconv(.C) *Passwd;