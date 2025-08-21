const std = @import("std");
const fs = std.fs;
const os = std.os;

const clap2 = @import("clap2/clap2.zig");
const mode = @import("util/mode.zig");
const version = @import("util/version.zig");
const strings = @import("util/strings.zig");

const Allocator = std.mem.Allocator;
const mode_t = mode.mode_t;
const MakeDirError = std.posix.MakeDirError;
const OpenError = fs.Dir.OpenError;

const allocator = std.heap.page_allocator;
const mkdir = std.posix.mkdir;
const print = @import("util/print_tools.zig").print;

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
    const args: []const clap2.Argument = &[_]clap2.Argument{
        clap2.Argument.FlagArgument(null, &[_][]const u8{"help"}),
        clap2.Argument.FlagArgument(null, &[_][]const u8{"version"}),
        clap2.Argument.OptionArgument("m", &[_][]const u8{"mode"}, false),
        clap2.Argument.FlagArgument("Z", null),
        clap2.Argument.OptionArgument(null, &[_][]const u8{"context"}, false),
        clap2.Argument.FlagArgument("p", &[_][]const u8{"parents"}),
        clap2.Argument.FlagArgument("z", &[_][]const u8{"zero"}),
        clap2.Argument.FlagArgument("v", &[_][]const u8{"verbose"}),
    };

    var parser = clap2.Parser.init(args, .{});
    defer parser.deinit();

    if (parser.flag("help")) {
        print(help_message, .{});
        std.posix.exit(0);
    } else if (parser.flag("version")) {
        version.printVersionInfo(application_name);
        std.posix.exit(0);
    }

    const arguments = parser.positionals();
    
    var used_mode: mode_t = mode.getModeFromStringAndZeroMode("a=rw") catch unreachable;
    
    const mode_string = parser.option("m");
    const create_parents = parser.flag("p");
    const verbose = parser.flag("v");
    const default_selinux_context = parser.flag("Z");
    const special_selinux_context = parser.option("context");
    
    if (default_selinux_context and special_selinux_context.found) {
        print("SELinux context cannot be both default and specific. Exiting.\n", .{});
        std.posix.exit(1);
    }   
    
    if (mode_string.found) {
        used_mode = mode.getModeFromStringAndZeroMode(mode_string.value.?) catch |err| {
            switch (err) {
                mode.ModeError.InvalidModeString => print("Invalid mode. Exiting.\n", .{}),
                mode.ModeError.UnknownError => print("Unknown mode error. Exiting.\n", .{}),
            }
            std.posix.exit(1);
        };
    }
    
    var success = true;
    
    for (arguments) |arg| {
        success = create_dir(arg, create_parents, verbose, used_mode) and success;
    }
    
    if (!success) {
        std.posix.exit(1);
    }
}

fn create_dir(path: []const u8, create_parents: bool, verbose: bool, used_mode: mode_t) bool {
    const absolute = (path[0] == '/');
    if (absolute and path.len == 1) {
        print("'/' cannot be created.\n", .{});
        return false;
    }
    var used_dir: []const u8 = undefined;
    if (path[path.len - 1] == '/') {
        const last_non_index = strings.lastNonIndexOf(path, '/');
        if (last_non_index == null) {
            print("'/' cannot be created.\n", .{});
            return false;
        }
        used_dir = path[0..last_non_index.?+1];
    } else {
        used_dir = path;
    }
    
    const cast_mode: u32 = @intCast(used_mode);
    
    if (create_parents) {
        const slash_position = strings.indexOf(used_dir, '/');
        if (slash_position == null) {
            mkdir(used_dir, cast_mode) catch |err| {
                handleMkdirErrors(err);
                return false;
            };
            if (verbose) print("{s}: created directory '{s}'\n", .{application_name, used_dir});
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
                    mkdir(existing_base_path[0..slash_index.?], cast_mode) catch |err| {
                        handleMkdirErrors(err);
                        return false;
                    };
                    if (verbose) print("{s}: created directory '{s}'\n", .{application_name, existing_base_path[0..slash_index.?]});
                    slash_index = strings.indexOfStartOnPos(existing_base_path, slash_index.?+1, '/');
                }
                
                mkdir(used_dir, cast_mode) catch |err| {
                    handleMkdirErrors(err);
                    return false;
                };
                if (verbose) print("{s}: created directory '{s}'\n", .{application_name, used_dir});
            } else {
                mkdir(used_dir, cast_mode) catch |err| {
                    handleMkdirErrors(err);
                    return false;
                };
                if (verbose) print("{s}: created directory '{s}'\n", .{application_name, used_dir});
            }
        }
    } else {
        const last_slash = strings.lastIndexOf(used_dir, '/');
        if (last_slash != null) {
            const check_path = used_dir[0..last_slash.?+1];
            _ = std.fs.cwd().openDir(check_path, .{}) catch |err| {
                handleOpenDirErrors(err, check_path);
                return false;
            };
            mkdir(used_dir, cast_mode) catch |err| {
                handleMkdirErrors(err);
                return false;
            };
            if (verbose) print("{s}: created directory '{s}'\n", .{application_name, used_dir});
        } else {
            mkdir(used_dir, cast_mode) catch |err| {
                handleMkdirErrors(err);
                return false;
            };
            if (verbose) print("{s}: created directory '{s}'\n", .{application_name, used_dir});
        }
    }
    return true;
}

fn handleMkdirErrors(err: MakeDirError) void {
    switch (err) {
        MakeDirError.AccessDenied => print("{s}: Access Denied\n", .{application_name}),
        MakeDirError.DiskQuota => print("{s}: Disk Quota Reached\n", .{application_name}),
        MakeDirError.PathAlreadyExists => print("{s}: Directory Already Exists\n", .{application_name}),
        MakeDirError.SymLinkLoop => print("{s}: Symlink loop detected\n", .{application_name}),
        MakeDirError.LinkQuotaExceeded => print("{s}: Link Quota Exceeded\n", .{application_name}),
        MakeDirError.NameTooLong => print("{s}: Name Too Long\n", .{application_name}),
        MakeDirError.FileNotFound => print("{s}: File Not Found\n", .{application_name}),
        MakeDirError.SystemResources => print("{s}: System Resources Error\n", .{application_name}),
        MakeDirError.NoSpaceLeft => print("{s}: No Space Left On Device\n", .{application_name}),
        MakeDirError.NotDir => print("{s}: Base Path Is Not A Directory \n", .{application_name}),
        MakeDirError.ReadOnlyFileSystem => print("{s}: Read Only File System\n", .{application_name}),
        MakeDirError.InvalidUtf8 => print("{s}: Invalid UTF-8 Detected\n", .{application_name}),
        MakeDirError.BadPathName => print("{s}: Bad Path Name\n", .{application_name}),
        MakeDirError.NoDevice => print("{s}: No Device\n", .{application_name}),
        else => print("{s}: Unknown error\n", .{application_name})
    }
}

fn handleOpenDirErrors(err: OpenError, check_path: []const u8) void {
    switch (err) {
        error.NotDir => print("{s}: Basepath '{s}' is not a dir\n", .{application_name, check_path}),
        error.AccessDenied => print("{s}: Access to '{s}' denied\n", .{application_name, check_path}),
        error.FileNotFound => print("{s}: Basepath '{s}' does not exist\n", .{application_name, check_path}),
        else => print("{s}: Unknown error '{any}' encountered when trying to create directory\n", .{application_name, err}),
    }
}




