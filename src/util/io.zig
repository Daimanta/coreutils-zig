const std = @import("std");

pub fn readStdin(io: std.Io, allocator: std.mem.Allocator) ![]u8{
    var buffer: [4096]u8 = undefined;
    var reader = std.Io.File.stdin().reader(io, &buffer);
    return try reader.interface.allocRemaining(allocator, .unlimited);
}

pub fn mkdir(path: []const u8, mode: std.os.linux.mode_t) !void{
    const path_null = std.posix.toPosixPath(path) catch {
        return error.PathTooLong;
    };

    const returncode: isize = @bitCast(std.os.linux.mkdir(&path_null, mode));
    if (returncode != 0) {
        return error.MakeDirError;
    }
}

pub fn rmdir(path: []const u8) !void {
    const path_null = std.posix.toPosixPath(path) catch {
        return error.PathTooLong;
    };
    const returncode: isize = @bitCast(std.os.linux.rmdir(&path_null));
    if (returncode < 0) {
        return error.RemovalError;
    }
}

pub fn mkdirat(dir: std.Io.Dir, path: []const u8, mode: std.os.linux.mode_t) !void{
    const path_null = std.posix.toPosixPath(path) catch {
        return error.PathTooLong;
    };
    const returncode: isize = @bitCast(std.os.linux.mkdirat(dir.handle, &path_null, mode));
    if (returncode < 0) {
        return error.CreateDirError;
    }
}

pub fn readlink(dir: std.Io.Dir, io: std.Io, allocator: std.mem.Allocator, path: []const u8) ![]u8{
    _ = io;
    var buffer: [4096]u8 = undefined;
    const path_null = std.posix.toPosixPath(path) catch {
        return error.PathTooLong;
    };
    const returnsize: isize = @bitCast(std.os.linux.readlinkat(dir.handle, &path_null, &buffer, 4096));
    if (returnsize < 0) {
        return error.ReadLinkError;
    }
    return allocator.dupe(u8, buffer[0..@intCast(returnsize)]);
}

pub fn readFileAlloc(file: std.Io.File, io: std.Io, allocator: std.mem.Allocator) ![]u8{
    var buffer: [4096]u8 = undefined;
    var reader = file.reader(io, &buffer);
    return try reader.interface.allocRemaining(allocator, .unlimited);
}

pub fn link(oldpath: []const u8, newpath: []const u8) !void {
    const oldpath_null = std.posix.toPosixPath(oldpath) catch {
        return error.PathTooLong;
    };

    const newpath_null = std.posix.toPosixPath(newpath) catch {
        return error.PathTooLong;
    };

    const returncode: isize = @bitCast(std.os.linux.link(&oldpath_null, &newpath_null));
    if (returncode != 0) {
        return error.LinkError;
    }
}

pub fn symlink(oldpath: []const u8, newpath: []const u8) !void {
    const oldpath_null = std.posix.toPosixPath(oldpath) catch {
        return error.PathTooLong;
    };

    const newpath_null = std.posix.toPosixPath(newpath) catch {
        return error.PathTooLong;
    };

    const returncode: isize = @bitCast(std.os.linux.symlink(&oldpath_null, &newpath_null));
    if (returncode != 0) {
        return error.LinkError;
    }
}