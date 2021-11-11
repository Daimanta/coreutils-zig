const std = @import("std");
const fs = std.fs;
const os = std.os;

const clap = @import("clap.zig");
const mode = @import("util/mode.zig");
const version = @import("util/version.zig");
const strings = @import("util/strings.zig");

const Allocator = std.mem.Allocator;
const mode_t = mode.mode_t;
const DeleteDirError = os.DeleteDirError;

const allocator = std.heap.page_allocator;
const print = std.debug.print;
const rmdir = os.rmdir;

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
    const params = comptime [_]clap.Param(clap.Help){
        clap.parseParam("--help") catch unreachable,
        clap.parseParam("--version") catch unreachable,
        clap.parseParam("--ignore-fail-on-non-empty") catch unreachable,
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
    
    const remove_parents = args.flag("-p");
    const verbose = args.flag("-v");
    const ignore_non_empty_fail = args.flag("--ignore-fail-on-non-empty");
        
    var success = true;
    
    for (arguments) |arg| {
        success = remove_dir(arg, remove_parents, verbose, ignore_non_empty_fail) and success;
    }
    
    if (!success) {
        std.os.exit(1);
    }
}

fn remove_dir(path: []const u8, remove_parents: bool, verbose: bool, ignore_non_empty_fail: bool) bool {
    if (path[0] == '/' and path.len == 1) {
        print("{s}: '/' cannot be deleted\n" ,.{application_name});
        return false;
    }
    if (remove_parents) {
        const slash_position = strings.indexOf(path, '/');
        if (slash_position == null) {
            rmdir(path) catch |err| {
            handleRmDirErrors(err);
            return false;
            };
        
        } else {
        
        }
    } else {
        rmdir(path) catch |err| {
            handleRmDirErrors(err);
            return false;
        };
    }
    return true;
}

fn handleRmDirErrors(err: DeleteDirError) void {
    switch (err) {
        error.AccessDenied => print("{s}: Access denied\n", .{application_name}),
        error.BadPathName => print("{s}: Bad path name\n", .{application_name}),
        error.DirNotEmpty => print("{s}: Directory not empty\n", .{application_name}),
        error.FileBusy => print("{s}: Directory still busy\n", .{application_name}),
        error.FileNotFound => print("{s}: Directory not found\n", .{application_name}),
        error.InvalidUtf8 => print("{s}: Invalid UTF-8 detected\n", .{application_name}),
        error.NameTooLong => print("{s}: Name too long\n", .{application_name}),
        error.NotDir => print("{s}: File is not a directory\n", .{application_name}),
        error.ReadOnlyFileSystem => print("{s}: Read only filesystem\n", .{application_name}),
        error.SymLinkLoop => print("{s}: Symlink loop detected\n", .{application_name}),
        error.SystemResources => print("{s}: System resources error\n", .{application_name}),
        error.Unexpected => print("{s}: Unexpected error\n", .{application_name}),
        else => print("{s}: Unknown error\n", .{application_name})
    }
}
