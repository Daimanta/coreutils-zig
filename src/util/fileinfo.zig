const std = @import("std");
const linux = std.os.linux;
const kernel_stat = linux.kernel_stat;

const S_IFMT = 0o0160000;
const S_IFLINK = 0o0120000;

pub fn isSymlink(stat: kernel_stat) bool {
    return (stat.mode & S_IFMT) == S_IFLINK;
}