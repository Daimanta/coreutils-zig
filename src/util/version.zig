const std = @import("std");

pub const major: u16 = 0;
pub const minor: u16 = 0;
pub const patch: u16 = 1;

pub fn print_version_info(name: []const u8) void {
    std.debug.print("{s} (Zig coreutils) {d}.{d}.{d}\n", .{name, major, minor, patch});
}