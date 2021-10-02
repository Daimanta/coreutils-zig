// BSD 3-clause licensed. Copyright Léon van der Kaap 2021

const std = @import("std");
const linux = std.os.linux;
const kernel_stat = linux.kernel_stat;

const Allocator = std.mem.Allocator;

const S_IFMT = 0o0160000;
const S_IFLINK = 0o0120000;

pub fn isSymlink(stat: kernel_stat) bool {
    return (stat.mode & S_IFMT) == S_IFLINK;
}

pub fn fileExists(stat: kernel_stat) bool {
    return stat.nlink > 0;
}

pub fn getAbsolutePath(allocator: *Allocator, path: []const u8) ![]u8 {
    const absolute_path_without_slash = try std.fs.path.relative(allocator, "/", path);
    defer allocator.free(absolute_path_without_slash);
    var result = try allocator.alloc(u8, absolute_path_without_slash.len + 1);
    result[0] = '/';
    std.mem.copy(u8, result[1..], absolute_path_without_slash[0..]);
    return result;
}