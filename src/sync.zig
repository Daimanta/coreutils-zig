const std = @import("std");
const fs = std.fs;
const os = std.os;

const mem = std.mem;

const clap2 = @import("clap2/clap2.zig");
const strings = @import("util/strings.zig");
const version = @import("util/version.zig");

const Allocator = std.mem.Allocator;
const OpenError = std.posix.OpenError;

const fsync = std.os.linux.fsync;
const fdatasync = std.os.linux.fdatasync;
const print = @import("util/print_tools.zig").print;
const sync = std.os.linux.sync;
const syncfs = std.os.linux.syncfs;
const exit = std.process.exit;

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

pub fn main(init: std.process.Init) !void {
    const args: []const clap2.Argument = &[_]clap2.Argument{
        clap2.Argument.FlagArgument(null, &[_][]const u8{"help"}),
        clap2.Argument.FlagArgument(null, &[_][]const u8{"version"}),
        clap2.Argument.FlagArgument("d", &[_][]const u8{"date"}),
        clap2.Argument.FlagArgument("f", &[_][]const u8{"file-system"}),
    };

    var parser = clap2.Parser.init(args, init.minimal, .{});
    defer parser.deinit();

    if (parser.flag("help")) {
        print(help_message, .{});
        exit(0);
    } else if (parser.flag("version")) {
        version.printVersionInfo(application_name);
        exit(0);
    }

    const arguments = parser.positionals();

    const only_filedata = parser.flag("d");
    const sync_filesystem = parser.flag("f");
    
    var sync_type = SyncType.FILE;
    if (only_filedata) sync_type = SyncType.DATA;
    if (sync_filesystem) sync_type = SyncType.FILE_SYSTEM;
    
    if (only_filedata and sync_filesystem) {
        print("Filesystem and data-only sync cannot be done at the same time. Exiting.\n", .{});
        exit(1);
    }
    
    if (sync_type != SyncType.FILE and arguments.len == 0) {
        print("The mode was set for syncing specific files but no files were provided. Exiting.\n", .{});
        exit(1);
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
    const handle = std.posix.openat(std.Io.Dir.cwd().handle, target, .{}, 0) catch {
        print("An error occured\n", .{});
        return false;
    };
    _ = switch(sync_type) {
        SyncType.DATA => fdatasync(handle),
        SyncType.FILE => fsync(handle),
        SyncType.FILE_SYSTEM => syncfs(handle)
    };
    return true;
}
