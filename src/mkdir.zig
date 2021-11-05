const std = @import("std");
const fs = std.fs;
const os = std.os;

const clap = @import("clap.zig");
const mode = @import("util/mode.zig");
const version = @import("util/version.zig");
const strings = @import("util/strings.zig");

const Allocator = std.mem.Allocator;
const mode_t = mode.mode_t;
const MakeDirError = os.MakeDirError;
const OpenError = fs.Dir.OpenError;

const allocator = std.heap.page_allocator;

const application_name = "mkdir";

const help_message =
\\Usage: mkdir [OPTION]... DIRECTORY...
\\Create the DIRECTORY(ies), if they do not already exist.
\\
\\Mandatory arguments to long options are mandatory for short options too.
\\  -m, --mode=MODE   set file mode (as in chmod), not a=rwx - umask
\\  -p, --parents     no error if existing, make parent directories as needed
\\  -v, --verbose     print a message for each created directory
\\  -Z                   set SELinux security context of each created directory
\\                         to the default type
\\      --context[=CTX]  like -Z, or if CTX is specified then set the SELinux
\\                         or SMACK security context to CTX
\\      --help     display this help and exit
\\      --version  output version information and exit
\\
\\
;


pub fn main() !void {
    const params = comptime [_]clap.Param(clap.Help){
        clap.parseParam("--help") catch unreachable,
        clap.parseParam("--version") catch unreachable,
        clap.parseParam("-m, --mode <STR>") catch unreachable,
        clap.parseParam("-Z") catch unreachable,
        clap.parseParam("--context <STR>") catch unreachable,
        clap.parseParam("-p, --parents") catch unreachable,
        clap.parseParam("-v, --verbose") catch unreachable,
        clap.parseParam("<STRING>") catch unreachable,
    };

    var diag = clap.Diagnostic{};
    var args = clap.parseAndHandleErrors(clap.Help, &params, .{ .diagnostic = &diag }, application_name, 1);
    defer args.deinit();

    if (args.flag("--help")) {
        std.debug.print(help_message, .{});
        std.os.exit(0);
    } else if (args.flag("--version")) {
        version.printVersionInfo(application_name);
        std.os.exit(0);
    }

    const arguments = args.positionals();
    
    var used_mode: mode_t = mode.getModeFromString("a=rw") catch unreachable;
    
    const mode_string = args.option("-m");
    const create_parents = args.flag("-p");
    const verbose = args.flag("-v");
    const default_selinux_context = args.flag("-Z");
    const special_selinux_context = args.option("--context");
    
    if (default_selinux_context and special_selinux_context != null) {
        std.debug.print("SELinux context cannot be both default and specific. Exiting.\n", .{});
        std.os.exit(1);
    }   
    
    if (mode_string != null) {
        used_mode = mode.getModeFromString(mode_string.?) catch |err| {
            switch (err) {
                mode.ModeError.InvalidModeString => std.debug.print("Invalid mode. Exiting.\n", .{}),
                mode.ModeError.UnknownError => std.debug.print("Unknown mode error. Exiting.\n", .{}),
            }
            std.os.exit(1);
        };
    }
    
    var success = true;
    
    for (arguments) |arg| {
        success = create_dir(arg, create_parents, verbose, used_mode) and success;
    }
    
    if (!success) {
        std.os.exit(1);
    }
}

fn create_dir(path: []const u8, create_parents: bool, verbose: bool, used_mode: mode_t) bool {
    const absolute = (path[0] == '/');
    if (absolute and path.len == 1) {
        std.debug.print("'/' cannot be created.\n", .{});
        return false;
    }
    var used_dir: []const u8 = undefined;
    if (path[path.len - 1] == '/') {
        const last_non_index = strings.lastNonIndexOf(path, '/');
        if (last_non_index == null) {
            std.debug.print("'/' cannot be created.\n", .{});
            return false;
        }
        used_dir = path[0..last_non_index.?+1];
    } else {
        used_dir = path;
    }
    
    if (create_parents) {
        var slash_position = strings.indexOf(used_dir, '/');
        if (slash_position == null) {
            std.os.mkdir(used_dir, @intCast(u32, used_mode)) catch |err| {
                handleMkdirErrors(err);
                return false;
            };
        } else {
            var existing_base_path = used_dir;
            var slash_index = strings.indexOfStartOnPos(existing_base_path, 1, '/');
            while (slash_index != null) {
                const open_dir = std.fs.cwd().openDir(existing_base_path[0..slash_index.?+1], .{});
                _ = open_dir catch |err| {
                    if (err == error.FileNotFound) {
                        break;
                    }
                };
                slash_index = strings.indexOfStartOnPos(existing_base_path, slash_index.?+1, '/');
            }
            if (slash_index != null) {
                while (slash_index != null) {
                    std.debug.print("{s}", .{existing_base_path[0..slash_index.?]});
                    std.os.mkdir(existing_base_path[0..slash_index.?], @intCast(u32, used_mode)) catch |err| {
                        handleMkdirErrors(err);
                        return false;
                    };
                    slash_index = strings.indexOfStartOnPos(existing_base_path, slash_index.?+1, '/');
                }
            } else {
                std.os.mkdir(used_dir, @intCast(u32, used_mode)) catch |err| {
                    handleMkdirErrors(err);
                    return false;
                };
            }
        }
    } else {
        const last_slash = strings.lastIndexOf(used_dir, '/');
        if (last_slash != null) {
            const check_path = used_dir[0..last_slash.?+1];
            const open_dir_test = std.fs.cwd().openDir(check_path, .{}) catch |err| {
                handleOpenDirErrors(err, check_path);
                return false;
            };
            std.os.mkdir(used_dir, @intCast(u32, used_mode)) catch |err| {
                handleMkdirErrors(err);
                return false;
            };
        } else {
            std.os.mkdir(used_dir, @intCast(u32, used_mode)) catch |err| {
                handleMkdirErrors(err);
                return false;
            };
        }
    }
    return true;
}

fn handleMkdirErrors(err: MakeDirError) void {
    switch (err) {
        MakeDirError.AccessDenied => std.debug.print("{s}: Access Denied\n", .{application_name}),
        MakeDirError.DiskQuota => std.debug.print("{s}: Disk Quota Reached\n", .{application_name}),
        MakeDirError.PathAlreadyExists => std.debug.print("{s}: Directory Already Exists\n", .{application_name}),
        MakeDirError.SymLinkLoop => std.debug.print("{s}: Symlink loop detected\n", .{application_name}),
        MakeDirError.LinkQuotaExceeded => std.debug.print("{s}: Link Quota Exceeded\n", .{application_name}),
        MakeDirError.NameTooLong => std.debug.print("{s}: Name Too Long\n", .{application_name}),
        MakeDirError.FileNotFound => std.debug.print("{s}: File Not Found\n", .{application_name}),
        MakeDirError.SystemResources => std.debug.print("{s}: System Resources Error\n", .{application_name}),
        MakeDirError.NoSpaceLeft => std.debug.print("{s}: No Space Left On Device\n", .{application_name}),
        MakeDirError.NotDir => std.debug.print("{s}: Base Path Is Not A Directory \n", .{application_name}),
        MakeDirError.ReadOnlyFileSystem => std.debug.print("{s}: Read Only File System\n", .{application_name}),
        MakeDirError.InvalidUtf8 => std.debug.print("{s}: Invalid UTF-8 Detected\n", .{application_name}),
        MakeDirError.BadPathName => std.debug.print("{s}: Bad Path Name\n", .{application_name}),
        MakeDirError.NoDevice => std.debug.print("{s}: No Device\n", .{application_name}),
        else => std.debug.print("{s}: Unknown error\n", .{application_name})
    }
}

fn handleOpenDirErrors(err: OpenError, check_path: []const u8) void {
    switch (err) {
        error.NotDir => std.debug.print("{s}: Basepath '{s}' is not a dir\n", .{application_name, check_path}),
        error.AccessDenied => std.debug.print("{s}: Access to '{s}' denied\n", .{application_name, check_path}),
        error.FileNotFound => std.debug.print("{s}: Basepath '{s}' does not exist\n", .{application_name, check_path}),
        else => std.debug.print("{s}: Unknown error '{s}' encountered when trying to create directory\n", .{application_name, err}),
    }
}




