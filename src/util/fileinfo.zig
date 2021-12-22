// BSD 3-clause licensed. Copyright Léon van der Kaap 2021

const std = @import("std");
const linux = std.os.linux;

const strings = @import("strings.zig");

const KernelStat = linux.Stat;

const Allocator = std.mem.Allocator;
pub const mode_t = linux.mode_t;

const default_allocator = std.heap.page_allocator;

pub const MakeFifoError = error {
    WritePermissionDenied,
    FileAlreadyExists,
    NameTooLong,
    IncorrectPath,
    ReadOnlyFileSystem,
    NotSupported,
    QuotaReached,
    NoSpaceLeft,
    NotImplemented,
    Unknown
};

const S_IFMT = 0o0160000;
const S_IFLINK = 0o0120000;

extern fn mkfifo(path: [*:0]const u8, mode: mode_t) c_int;

pub fn isSymlink(stat: KernelStat) bool {
    return (stat.mode & S_IFMT) == S_IFLINK;
}

pub fn fileExists(stat: KernelStat) bool {
    return stat.nlink > 0;
}

pub fn getAbsolutePath(allocator: Allocator, path: []const u8) ![]u8 {
    const absolute_path_without_slash = try std.fs.path.relative(allocator, "/", path);
    defer allocator.free(absolute_path_without_slash);
    var result = try allocator.alloc(u8, absolute_path_without_slash.len + 1);
    result[0] = '/';
    std.mem.copy(u8, result[1..], absolute_path_without_slash[0..]);
    return result;
}

pub fn getLstat(path: []const u8) !KernelStat {
    var my_kernel_stat: KernelStat = std.mem.zeroes(KernelStat);
    const np_link = try strings.toNullTerminatedPointer(path, default_allocator);
    defer default_allocator.free(np_link);
    _ = linux.lstat(np_link, &my_kernel_stat);
    return my_kernel_stat;
}

pub fn makeFifo(path: []const u8, mode: mode_t) MakeFifoError!void{
    const null_string = strings.toNullTerminatedPointer(path, default_allocator) catch return MakeFifoError.Unknown;
    const result = mkfifo(null_string, mode);
    default_allocator.free(null_string);
    if (result != 0) {
        const errno = std.c.getErrno(result);
        return switch (errno) {
            .ACCES => MakeFifoError.WritePermissionDenied,
            .DQUOT => MakeFifoError.QuotaReached,
            .EXIST => MakeFifoError.FileAlreadyExists,
            .NAMETOOLONG => MakeFifoError.NameTooLong,
            .NOENT,.NOTDIR  => MakeFifoError.IncorrectPath,
            .NOSPC => MakeFifoError.NoSpaceLeft,
            .ROFS => MakeFifoError.ReadOnlyFileSystem,
            .OPNOTSUPP => MakeFifoError.NotSupported,
            .NOSYS => MakeFifoError.NotImplemented,
            else => blk: {
                std.debug.print("Unknown error encountered: {d}\n", .{errno});
                break :blk MakeFifoError.Unknown;
            }
        };
    }
}
