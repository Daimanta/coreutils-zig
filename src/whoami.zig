const std = @import("std");
const linux = std.os.linux;

const Passwd = extern struct {
    pw_name: [*:0]u8,
    pw_uid: linux.uid_t,
    pw_gid: linux.gid_t,
    pw_dir: [*:0]u8,
    pw_shell: [*:0]u8
};


pub extern fn getpwuid (uid: linux.uid_t) callconv(.C) *Passwd;

pub fn main() !void {
    const uid = linux.geteuid();
    const pw: *Passwd = getpwuid(uid);
    std.debug.print("{s}\n", .{pw.pw_name});
}