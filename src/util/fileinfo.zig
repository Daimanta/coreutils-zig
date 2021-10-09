// BSD 3-clause licensed. Copyright Léon van der Kaap 2021

const std = @import("std");
const linux = std.os.linux;

const strings = @import("strings.zig");

const kernel_stat = linux.kernel_stat;

const Allocator = std.mem.Allocator;
pub const mode_t = linux.mode_t;

const allocator = std.heap.page_allocator;

pub const MakeFifoError = error {
    WritePermissionDenied,
    FileAlreadyExists,
    NameTooLong,
    IncorrectPath,
    ReadOnlyFileSystem,
    NotSupported,
    QuotaReached,
    NoSpaceLeft,
    Unknown
};

const S_IFMT = 0o0160000;
const S_IFLINK = 0o0120000;

extern fn mkfifo(path: [*:0]u8, mode: mode_t) c_int;

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

pub fn makeFifo(path: []const u8, mode: mode_t) MakeFifoError!void{
    const null_string = strings.toNullTerminatedPointer(path, allocator) catch return MakeFifoError.Unknown;
    const result = mkfifo(null_string, mode);
    allocator.free(null_string);
    if (result != 0) {
        const errno = std.c.getErrno(result);
        return switch (errno) {
            linux.EACCES => MakeFifoError.WritePermissionDenied,
            linux.EDQUOT => MakeFifoError.QuotaReached,
            linux.EEXIST => MakeFifoError.FileAlreadyExists,
            linux.ENAMETOOLONG => MakeFifoError.NameTooLong,
            linux.ENOENT,linux.ENOTDIR  => MakeFifoError.IncorrectPath,
            linux.ENOSPC => MakeFifoError.NoSpaceLeft,
            linux.EROFS => MakeFifoError.ReadOnlyFileSystem,
            linux.EOPNOTSUPP => MakeFifoError.NotSupported,
            else => MakeFifoError.Unknown
        };
    }
    std.debug.print("{d}\n", .{result});
}