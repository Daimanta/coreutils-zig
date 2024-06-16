const std = @import("std");

const version_number = @import("version_number.zig");
const print = @import("print_tools.zig").print;

pub fn printVersionInfo(name: []const u8) void {
    print("{s} (Zig coreutils) {d}.{d}.{d}\n{s}\n", .{name, version_number.major, version_number.minor, version_number.patch, license_info});
}

pub const license_info =
\\Copyright (C) 2024 Léon van der Kaap
\\License GPLv3: GNU GPL version 3 <https://gnu.org/licenses/gpl.html>.
\\This is free software: you are free to change and redistribute it.
\\There is NO WARRANTY, to the extent permitted by law.

;
