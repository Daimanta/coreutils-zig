const std = @import("std");
const fs = std.fs;
const os = std.os;

const clap2 = @import("clap2/clap2.zig");
const mode = @import("util/mode.zig");
const version = @import("util/version.zig");
const strings = @import("util/strings.zig");

const Allocator = std.mem.Allocator;
const mode_t = mode.mode_t;
const DeleteDirError = std.posix.DeleteDirError;

const allocator = std.heap.page_allocator;
const print = @import("util/print_tools.zig").print;
const rmdir = std.posix.rmdir;

const application_name = "rmdir";

const help_message =
\\Usage: rmdir [OPTION]... DIRECTORY...
\\Remove the DIRECTORY(ies), if they are empty.
\\
\\      --ignore-fail-on-non-empty
\\                  ignore each failure that is solely because a directory
\\                    is non-empty
\\  -p, --parents   remove DIRECTORY and its ancestors; e.g., 'rmdir -p a/b/c' is
\\                    similar to 'rmdir a/b/c a/b a'
\\  -v, --verbose   output a diagnostic for every directory processed
\\      --help     display this help and exit
\\      --version  output version information and exit
\\
;


pub fn main() !void {
    const args: []const clap2.Argument = &[_]clap2.Argument{
        clap2.Argument.FlagArgument(null, &[_][]const u8{"help"}),
        clap2.Argument.FlagArgument(null, &[_][]const u8{"version"}),
        clap2.Argument.FlagArgument("v", &[_][]const u8{"verbose"}),
        clap2.Argument.FlagArgument("P", &[_][]const u8{"physical"}),
        clap2.Argument.FlagArgument("z", null),
        clap2.Argument.FlagArgument(null, &[_][]const u8{"ignore-fail-on-non-empty"}),
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
    
    const remove_parents = parser.flag("p");
    const verbose = parser.flag("v");
    const ignore_non_empty_fail = parser.flag("ignore-fail-on-non-empty");
        
    var success = true;
    
    for (arguments) |arg| {
        success = remove_dir(arg, remove_parents, verbose, ignore_non_empty_fail) and success;
    }
    
    if (!success) {
        std.posix.exit(1);
    }
}

fn remove_dir(path: []const u8, remove_parents: bool, verbose: bool, ignore_non_empty_fail: bool) bool {
    if (path[0] == '/' and path.len == 1) {
        print("{s}: '/' cannot be deleted\n" ,.{application_name});
        return false;
    }
    if (std.mem.eql(u8, path, "./") or std.mem.eql(u8, path, ".") or std.mem.eql(u8, path, "..")) {
        print("{s}: '{s}' cannot be deleted\n" ,.{application_name, path});
        return false;
    }
    
    if (remove_parents) {
        const slash_position = strings.indexOf(path, '/');
        if (slash_position == null) {
            rmdir(path) catch |err| {
                handleRmDirErrors(err, path);
                return errorReturnStatus(err, ignore_non_empty_fail);
            };
        } else {
            // Strip all last slashes, path is guaranteed to not be '/' so this does not fail
            var used_path = path[0..strings.lastNonIndexOf(path, '/').? + 1];
            rmdir(path) catch |err| {
                    handleRmDirErrors(err, used_path);
                    return errorReturnStatus(err, ignore_non_empty_fail);
            };
            if (verbose) print("{s}: removing directory '{s}'\n", .{application_name, used_path});
            var current_slash: ?usize = strings.lastIndexOf(used_path, '/');
            while (current_slash != null and current_slash.? > 0) {
                const remove_path = used_path[0..current_slash.?];
                if (std.mem.eql(u8, remove_path, ".") or std.mem.eql(u8, remove_path, "..")) {
                    return true;
                }
                rmdir(remove_path) catch |err| {
                    handleRmDirErrors(err, remove_path);
                    return errorReturnStatus(err, ignore_non_empty_fail);
                };
                if (verbose) print("{s}: removing directory '{s}'\n", .{application_name, remove_path});
                current_slash = strings.lastIndexOf(used_path[0..current_slash.?], '/');
            }
        }
    } else {
        rmdir(path) catch |err| {
            handleRmDirErrors(err, path);
            return errorReturnStatus(err, ignore_non_empty_fail);
        };
        if (verbose) print("{s}: removing directory '{s}'\n", .{application_name, path});
    }
    return true;
}

fn handleRmDirErrors(err: DeleteDirError, path: []const u8) void {
    switch (err) {
        error.AccessDenied => print("{s}: Access denied to '{s}'\n", .{application_name, path}),
        error.BadPathName => print("{s}: Bad path name '{s}'\n", .{application_name, path}),
        error.DirNotEmpty => print("{s}: Directory '{s}' not empty\n", .{application_name, path}),
        error.FileBusy => print("{s}: Directory '{s}' still busy\n", .{application_name, path}),
        error.FileNotFound => print("{s}: Directory '{s}' not found\n", .{application_name, path}),
        error.InvalidUtf8 => print("{s}: Invalid UTF-8 detected\n", .{application_name}),
        error.NameTooLong => print("{s}: Name too long\n", .{application_name}),
        error.NotDir => print("{s}: '{s}' is not a directory\n", .{application_name, path}),
        error.ReadOnlyFileSystem => print("{s}: Read only filesystem\n", .{application_name}),
        error.SymLinkLoop => print("{s}: Symlink loop detected\n", .{application_name}),
        error.SystemResources => print("{s}: System resources error\n", .{application_name}),
        error.Unexpected => print("{s}: Unexpected error\n", .{application_name}),
        else => unreachable
    }
}

fn errorReturnStatus(err: DeleteDirError, ignore_non_empty_fail: bool) bool {
      if (err == DeleteDirError.DirNotEmpty) return ignore_non_empty_fail;
      return false;
}
