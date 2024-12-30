const std = @import("std");
const fs = std.fs;
const os = std.os;

const mem = std.mem;

const clap = @import("clap.zig");
const clap2 = @import("clap2/clap2.zig");
const strings = @import("util/strings.zig");
const version = @import("util/version.zig");

const Allocator = std.mem.Allocator;
const OpenError = std.posix.OpenError;

const fsync = std.posix.fsync;
const fdatasync = std.posix.fdatasync;
const print = @import("util/print_tools.zig").print;
const sync = std.posix.sync;
const syncfs = std.posix.syncfs;

const default_allocator = std.heap.page_allocator;

const application_name = "sync";

const help_message =
\\Usage: sync [OPTION] [FILE]...
\\Synchronize cached writes to persistent storage
\\
\\If one or more files are specified, sync only them,
\\or their containing file systems.
\\
\\  -d, --data             sync only file data, no unneeded metadata
\\  -f, --file-system      sync the file systems that contain the files
\\      --help     display this help and exit
\\      --version  output version information and exit
\\
;

const SyncType = enum {
    DATA,
    FILE,
    FILE_SYSTEM
};

pub fn main() !void {

    const params = comptime [_]clap.Param(clap.Help){
        clap.parseParam("--help") catch unreachable,
        clap.parseParam("--version") catch unreachable,
        clap.parseParam("-d, --data") catch unreachable,
        clap.parseParam("-f, --file-system") catch unreachable,
        clap.parseParam("<STRING>") catch unreachable,
    };

    var diag = clap.Diagnostic{};
    var args = clap.parseAndHandleErrors(clap.Help, &params, .{ .diagnostic = &diag }, application_name, 1);
    defer args.deinit();

    if (args.flag("--help")) {
        print(help_message, .{});
        std.posix.exit(0);
    } else if (args.flag("--version")) {
        version.printVersionInfo(application_name);
        std.posix.exit(0);
    }
    
    const only_filedata = args.flag("-d");
    const sync_filesystem = args.flag("-f");
    
    var sync_type = SyncType.FILE;
    if (only_filedata) sync_type = SyncType.DATA;
    if (sync_filesystem) sync_type = SyncType.FILE_SYSTEM;
    
    if (only_filedata and sync_filesystem) {
        print("Filesystem and data-only sync cannot be done at the same time. Exiting.\n", .{});
        std.posix.exit(1);
    }
    
    const arguments = args.positionals();
    if (sync_type != SyncType.FILE and arguments.len == 0) {
        print("The mode was set for syncing specific files but no files were provided. Exiting.\n", .{});
        std.posix.exit(1);
    }
    
    synchronize(sync_type, arguments);
}

fn synchronize(sync_type: SyncType, targets: [] const []const u8) void{
    if (targets.len == 0) {
        sync();
        return;
    }
    
    for (targets) |target| {
        _ = synchronize_target(sync_type, target);
    }
    
}

fn synchronize_target(sync_type: SyncType, target: []const u8) bool {
    const handle = std.posix.open(target, .{}, 0) catch |err| {
        switch (err) {
            OpenError.FileNotFound => print("{s}: File '{s}' not found.\n", .{application_name, target}),
            OpenError.IsDir => print("{s}: Target '{s}' is a directory.\n", .{application_name, target}),
            OpenError.AccessDenied => print("{s}: Access to file '{s}' denied.\n", .{application_name, target}),
            else => print("Unknown error.\n", .{}),
        }
        return false;
    };
    switch(sync_type) {
        SyncType.DATA => fdatasync(handle) catch return false,
        SyncType.FILE => fsync(handle) catch return false,
        SyncType.FILE_SYSTEM => syncfs(handle) catch return false   
    }
    return true;
}
