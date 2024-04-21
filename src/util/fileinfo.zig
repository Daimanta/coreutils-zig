// BSD 3-clause licensed. Copyright Léon van der Kaap 2021

const std = @import("std");
const linux = std.os.linux;

const strings = @import("strings.zig");

const KernelStat = linux.Stat;

const Allocator = std.mem.Allocator;
pub const mode_t = linux.mode_t;

const default_allocator = std.heap.page_allocator;
const print = @import("print_tools.zig").print;

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

pub const FollowSymlinkError = error {
    TooManyLinks,
    TargetDoesNotExist,
    NotLink,
    UnknownError
};

pub const ChmodError = error {
    AccessDenied,
    InvalidPath,
    OtherError,
    LoopEncountered,
    NameTooLong,
    FileDoesNotExist,
};

pub const FollowSymlinkResult = struct {
    error_result: ?FollowSymlinkError = null,
    path: ?[]u8 = null
};

const S_IFMT = 0o160000;
const S_IFLINK = 0o120000;
const S_IFDIR = 0o40000;

extern fn mkfifo(path: [*:0]const u8, mode: mode_t) c_int;
extern fn chmod(pathname: [*:0]const u8, mode: mode_t) c_int;

pub fn isSymlink(stat: KernelStat) bool {
    return (stat.mode & S_IFMT) == S_IFLINK;
}

pub fn fileExists(stat: KernelStat) bool {
    return stat.nlink > 0;
}

pub fn isDir(stat: KernelStat) bool {
    return (stat.mode & S_IFMT) == S_IFDIR;
}

pub fn getAbsolutePath(allocator: Allocator, path: []const u8, relative_to: ?[]const u8) ![]u8 {
    if (relative_to == null) {
        const absolute_path_without_slash = try std.fs.path.relative(allocator, "/", path);
        defer allocator.free(absolute_path_without_slash);
        var result = try allocator.alloc(u8, absolute_path_without_slash.len + 1);
        result[0] = '/';
        std.mem.copyForwards(u8, result[1..], absolute_path_without_slash[0..]);
        return result;
    } else {
        return try std.fs.path.relative(allocator, relative_to.?, path);
    }
    
}

// Follows a symlink recursively to the last path provided
pub fn followSymlink(allocator: Allocator, link: []const u8, target_must_exist: bool) FollowSymlinkResult {
    const max_path_length = 1 << 12;
    var link_iterator = link;
    var count: u8 = 0;
    var my_kernel_stat: KernelStat = undefined;
    var next: []u8 = undefined;
    var link_buffer: [max_path_length]u8 = undefined;
    var next_buffer: [max_path_length]u8 = undefined;
    while (true) {
        next = std.fs.cwd().readLink(link_iterator, link_buffer[0..]) catch return .{.error_result = FollowSymlinkError.NotLink};
        if (next.len > 0 and next[0] != '/') {
            const lastSlash = strings.lastIndexOf(link_iterator, '/');
            if (lastSlash != null) {
                std.mem.copyForwards(u8, next_buffer[0..], link_iterator[0..lastSlash.?+1]);
                std.mem.copyForwards(u8, next_buffer[lastSlash.?+1..], next);
                next = next_buffer[0..lastSlash.?+next.len+1];
            }
        }
        my_kernel_stat = getLstat(next) catch return .{.error_result = FollowSymlinkError.UnknownError};
        const it_exists = fileExists(my_kernel_stat);
        if (!it_exists and target_must_exist) {
            if (target_must_exist) {
                return .{.error_result = FollowSymlinkError.TargetDoesNotExist, .path = getAbsolutePath(allocator, next, null) catch return .{.error_result = FollowSymlinkError.UnknownError}};
            } else {
                return .{.path = getAbsolutePath(allocator, next, null) catch return .{.error_result = FollowSymlinkError.UnknownError}};
            }
        }
        if (!isSymlink(my_kernel_stat)) {
            return .{.path = getAbsolutePath(allocator, next, null) catch return .{.error_result = FollowSymlinkError.UnknownError}};
        }
        count += 1;
        if (count > 64) {
            return .{.error_result = FollowSymlinkError.TooManyLinks};
        }
        link_iterator = next;
    }
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
        const errno = std.posix.errno(result);
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
                print("Unknown error encountered: {d}\n", .{errno});
                break :blk MakeFifoError.Unknown;
            }
        };
    }
}

pub fn fsRoot(path: []const u8) bool {
    const targets: [3][]const u8 = .{"/"[0..], "/."[0..], "/.."[0..]};
    for (targets) |target| {
        if (std.mem.eql(u8, target, path)) {
            return true;
        }
    }
    return false;
}

pub fn chmodA(path: []const u8, mode: mode_t) ChmodError!void {
    const np_path = strings.toNullTerminatedPointer(path, default_allocator) catch return ChmodError.OtherError;
    const chmod_result = chmod(np_path, mode);
    default_allocator.free(np_path);
    if (chmod_result != 0) {
        const errno = std.posix.errno(chmod_result);
        return switch (errno) {
            .ACCES, .PERM => ChmodError.AccessDenied,
            .FAULT => ChmodError.InvalidPath,
            .IO, .ROFS, .NOMEM => ChmodError.OtherError,
            .LOOP => ChmodError.LoopEncountered,
            .NAMETOOLONG => ChmodError.NameTooLong,
            .NOENT => ChmodError.FileDoesNotExist,
            else => blk: {
                print("Unknown error encountered: {d}\n", .{errno});
                break :blk ChmodError.OtherError;
            }
        };
    }
}
