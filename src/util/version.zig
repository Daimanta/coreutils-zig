const std = @import("std");

pub const major: u16 = 0;
pub const minor: u16 = 0;
pub const patch: u16 = 1;

const print = @import("print_tools.zig").print;

pub fn printVersionInfo(name: []const u8) void {
    print("{s} (Zig coreutils) {d}.{d}.{d}\n{s}", .{name, major, minor, patch, license_info});
}

pub const license_info =
\\Copyright (C) 2021 Léon van der Kaap
\\License GPLv3: GNU GPL version 3 <https://gnu.org/licenses/gpl.html>.
\\This is free software: you are free to change and redistribute it.
\\There is NO WARRANTY, to the extent permitted by law.
;
