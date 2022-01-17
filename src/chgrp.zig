const std = @import("std");
const fs = std.fs;
const os = std.os;
const linux = os.linux;

const clap = @import("clap.zig");
const fileinfo = @import("util/fileinfo.zig");
const strings = @import("util/strings.zig");
const users = @import("util/users.zig");
const version = @import("util/version.zig");

const Allocator = std.mem.Allocator;
const ChownError = os.FChownError;
const OpenError = fs.Dir.OpenError;
const OpenFileError = fs.File.OpenError;

const default_allocator = std.heap.page_allocator;
const exit = std.os.exit;
const FollowSymlinkError = fileinfo.FollowSymlinkError;
const KernelStat = linux.Stat;
const print = std.debug.print;

const application_name = "chgrp";
const help_message =
    \\Usage: chgrp [OPTION]... GROUP FILE...
    \\  or:  chgrp [OPTION]... --reference=RFILE FILE...
    \\Change the group of each FILE to GROUP.
    \\With --reference, change the group of each FILE to that of RFILE.
    \\
    \\  -c, --changes          like verbose but report only when a change is made
    \\  -f, --silent, --quiet  suppress most error messages
    \\  -v, --verbose          output a diagnostic for every file processed
    \\      --dereference      affect the referent of each symbolic link (this is
    \\                         the default), rather than the symbolic link itself
    \\  -h, --no-dereference   affect symbolic links instead of any referenced file
    \\                         (useful only on systems that can change the
    \\                         ownership of a symlink)
    \\      --no-preserve-root  do not treat '/' specially (the default)
    \\      --preserve-root    fail to operate recursively on '/'
    \\      --reference=RFILE  use RFILE's group rather than specifying a
    \\                         GROUP value
    \\  -R, --recursive        operate on files and directories recursively
    \\
    \\The following options modify how a hierarchy is traversed when the -R
    \\option is also specified.  If more than one is specified, only the final
    \\one takes effect.
    \\
    \\  -H                     if a command line argument is a symbolic link
    \\                         to a directory, traverse it
    \\  -L                     traverse every symbolic link to a directory
    \\                         encountered
    \\  -P                     do not traverse any symbolic links (default)
    \\
    \\      --help     display this help and exit
    \\      --version  output version information and exit
    \\
    \\Examples:
    \\  chgrp staff /u      Change the group of /u to "staff".
    \\  chgrp -hR staff /u  Change the group of /u and subfiles to "staff".
    \\
;

const max_path_length = 1 << 12;
const consider_user = false;
const consider_group = true;

const Verbosity = enum { QUIET, STANDARD, CHANGED, VERBOSE };

const SymlinkTraversal = enum { NO, MAIN, ALL };

pub fn main() !void {
    const params = comptime [_]clap.Param(clap.Help){
        clap.parseParam("--help") catch unreachable,
        clap.parseParam("--version") catch unreachable,
        clap.parseParam("-c, --changes") catch unreachable,
        clap.parseParam("-f, --silent") catch unreachable,
        clap.parseParam("--quiet") catch unreachable,
        clap.parseParam("-v, --verbose") catch unreachable,
        clap.parseParam("--dereference") catch unreachable,
        clap.parseParam("-h, --no-redereference") catch unreachable,
        clap.parseParam("--no-preserve-root") catch unreachable,
        clap.parseParam("--preserve-root") catch unreachable,
        clap.parseParam("--reference <STR>") catch unreachable,
        clap.parseParam("-R, --recursive") catch unreachable,
        clap.parseParam("-H") catch unreachable,
        clap.parseParam("-L") catch unreachable,
        clap.parseParam("-P") catch unreachable,
        clap.parseParam("<STRING>") catch unreachable,
    };

    var diag = clap.Diagnostic{};
    var args = clap.parseAndHandleErrors(clap.Help, &params, .{ .diagnostic = &diag }, application_name, 1);

    if (args.flag("--help")) {
        std.debug.print(help_message, .{});
        exit(0);
    } else if (args.flag("--version")) {
        version.printVersionInfo(application_name);
        exit(0);
    }

    const changed = args.flag("-c");
    const quiet = args.flag("--quiet") or args.flag("-f");
    const verbose = args.flag("-v");
    const dereference = args.flag("--dereference");
    const no_dereference = args.flag("-h");
    const no_preserve_root = args.flag("--no-preserve-root");
    const preserve_root = args.flag("--preserve-root");
    const rfile_group = args.option("--reference");
    const recursive = args.flag("-R");
    const traverse_main_symlink = args.flag("-H");
    const traverse_all_symlinks = args.flag("-L");
    const no_traverse = args.flag("-P");

    checkInconsistencies(changed, quiet, verbose, dereference, no_dereference, no_preserve_root, preserve_root, traverse_main_symlink, traverse_all_symlinks, no_traverse);

    var verbosity = Verbosity.STANDARD;
    if (quiet) verbosity = Verbosity.QUIET;
    if (changed) verbosity = Verbosity.CHANGED;
    if (verbose) verbosity = Verbosity.VERBOSE;

    var dereference_main = true;
    if (no_dereference) dereference_main = false;

    var symlink_traversal = SymlinkTraversal.NO;
    if (traverse_main_symlink) symlink_traversal = SymlinkTraversal.MAIN;
    // Explict override possibility as both can be specified
    if (traverse_all_symlinks) symlink_traversal = SymlinkTraversal.ALL;

    var group_id_opt: ?linux.gid_t = null;
    var user_id_opt: ?linux.uid_t = null;
    if (rfile_group != null) {
        const lstat = try fileinfo.getLstat(rfile_group.?);
        if (!fileinfo.fileExists(lstat)) {
            print("{s}: RFILE does not exist. Exiting.\n", .{application_name});
            exit(1);
        }
        group_id_opt = lstat.gid;
        user_id_opt = lstat.uid;
    }

    const positionals = args.positionals();
    if (positionals.len == 0) {
        if (rfile_group == null) {
            print("{s}: Group and file(s) missing. Exiting.\n", .{application_name});
        } else {
            print("{s}: Group specified but file(s) missing. Exiting.\n", .{application_name});
        }
        exit(1);
    } else if (positionals.len == 1 and rfile_group == null) {
        print("{s}: Group specified but file(s) missing. Exiting.\n", .{application_name});
        exit(1);
    }

    const group = positionals[0];

    var start_index: usize = 0;
    var group_id: linux.gid_t = undefined;
    if (group_id_opt != null) {
        group_id = group_id_opt.?;
    } else {
        const group_details = users.getGroupByName(group) catch {
            print("{s}: Group not found. Exiting.\n", .{application_name});
            exit(1);
        };
        group_id = group_details.gr_gid;
        start_index = 1;
    }

    for (positionals[start_index..]) |arg| {
        changeGroup(arg, group_id, null, consider_group, consider_user, recursive, verbosity, dereference_main, preserve_root, symlink_traversal);
    }
}

fn changeGroup(path: []const u8, group: ?linux.gid_t, user: ?linux.uid_t, do_consider_group: bool, do_consider_user: bool, recursive: bool, verbosity: Verbosity, dereference_main: bool, preserve_root: bool, symlink_traversal: SymlinkTraversal) void {
    if (fileinfo.fsRoot(path) and preserve_root) {
        if (verbosity != Verbosity.QUIET) {
            print("{s}: Root of fs encountered. Preserving root and exiting.\n", .{application_name});
        }
        return;
    }

    const stat = fileinfo.getLstat(path) catch return;
    if (!fileinfo.fileExists(stat)) {
        if (verbosity != Verbosity.QUIET) {
            print("{s}: File '{s}' does not exist.\n", .{ application_name, path });
        }
        return;
    }

    const target_user = if (do_consider_user) user else null;
    const target_group = if (do_consider_group) group else null;

    const is_dir = fileinfo.isDir(stat);
    const is_symlink = fileinfo.isSymlink(stat);

    if (is_dir) {
        var dir = fs.cwd().openDir(path, .{ .iterate = true }) catch |err| {
            if (verbosity != Verbosity.QUIET) {
                switch (err) {
                    OpenError.AccessDenied => print("{s}: Access Denied to '{s}'\n", .{ application_name, path }),
                    else => print("{s}\n", .{err}),
                }
            }
            return;
        };
        if (dir.chown(target_user, target_group)) {
            if (verbosity == Verbosity.VERBOSE or (verbosity == Verbosity.CHANGED and ((target_group != null and (target_group.? != stat.gid)) or (target_user != null and (target_user.? != stat.uid))))) {
                print("Changed owner/group on '{s}'\n", .{path});
            }
        } else |err| {
            switch (err) {
                ChownError.AccessDenied => print("{s}: Access Denied to '{s}'\n", .{ application_name, path }),
                else => print("{s}\n", .{err}),
            }
        }
        defer dir.close();
    } else if (!is_symlink or dereference_main) {
        changePlainFile(path, stat, group, user, verbosity);
    }

    if (recursive and is_dir) {
        traverseDir(path, target_group, target_user, verbosity, symlink_traversal);
    }
}

fn changeItem(path: []const u8, group: ?linux.gid_t, user: ?linux.uid_t, verbosity: Verbosity, symlink_traversal: SymlinkTraversal) void {
    const stat = fileinfo.getLstat(path) catch return;

    if (!fileinfo.fileExists(stat)) {
        if (verbosity != Verbosity.QUIET) {
            print("{s}: File '{s}' does not exist.\n", .{ application_name, path });
        }
        return;
    }

    if (fileinfo.isDir(stat)) {
        traverseDir(path, group, user, verbosity, symlink_traversal);
    } else {
        if (symlink_traversal == SymlinkTraversal.ALL or fileinfo.isSymlink(stat)) {
            changePlainFile(path, stat, group, user, verbosity);
        }
    }
}

fn changePlainFile(path: []const u8, kernel_stat: ?KernelStat, group: ?linux.gid_t, user: ?linux.uid_t, verbosity: Verbosity) void {
    var stat: KernelStat = if (kernel_stat != null) kernel_stat.? else fileinfo.getLstat(path) catch return;

    const current_user = stat.uid;
    const current_group = stat.gid;

    const file = fs.cwd().openFile(path, .{ .write = true }) catch |err| {
        if (verbosity != Verbosity.QUIET) {
            switch (err) {
                OpenFileError.AccessDenied => print("{s}: Access Denied to '{s}'\n", .{ application_name, path }),
                else => print("{s}\n", .{err}),
            }
        }

        return;
    };

    defer file.close();

    if (file.chown(user, group)) {
        if (verbosity == Verbosity.VERBOSE or (verbosity == Verbosity.CHANGED and ((user != null and current_user != user.?) or (group != null and current_group != group.?)))) {
            print("Changed owner/group on '{s}'\n", .{path});
        }
    } else |err| {
        if (verbosity != Verbosity.QUIET) {
            switch (err) {
                ChownError.AccessDenied => print("{s}: Access Denied to '{s}'\n", .{ application_name, path }),
                else => print("{s}\n", .{err}),
            }
        }
    }
}

fn traverseDir(path: []const u8, group: ?linux.gid_t, user: ?linux.uid_t, verbosity: Verbosity, symlink_traversal: SymlinkTraversal) void {
    var buffer: [8192]u8 = undefined;
    var string_builder = strings.StringBuilder.init(buffer[0..]);
    string_builder.append(path);
    if (path[path.len - 1] != '/') string_builder.append("/");
    const current_index = string_builder.insertion_index;

    const stat = fileinfo.getLstat(path) catch return;

    const current_user = stat.uid;
    const current_group = stat.gid;

    var dir = fs.cwd().openDir(path, .{ .iterate = true }) catch |err| {
        if (verbosity != Verbosity.QUIET) {
            switch (err) {
                OpenError.AccessDenied => print("{s}: Access Denied to '{s}'\n", .{ application_name, path }),
                else => print("{s}\n", .{err}),
            }
        }
        return;
    };

    if (dir.chown(user, group)) {
        if (verbosity == Verbosity.VERBOSE or (verbosity == Verbosity.CHANGED and ((user != null and current_user != user.?) or (group != null and current_group != group.?)))) {
            print("Changed owner/group on '{s}'\n", .{path});
        }
    } else |err| {
        switch (err) {
            ChownError.AccessDenied => print("{s}: Access Denied to '{s}'\n", .{ application_name, path }),
            else => print("{s}\n", .{err}),
        }
    }

    var iterator = dir.iterate();
    while (iterator.next() catch return) |element| {
        string_builder.append(element.name);
        changeItem(string_builder.toSlice(), group, user, verbosity, symlink_traversal);
        string_builder.resetTo(current_index);
    }

    dir.close();
}

fn checkInconsistencies(changed: bool, quiet: bool, verbose: bool, dereference: bool, no_dereference: bool, no_preserve_root: bool, preserve_root: bool, traverse_main_symlink: bool, traverse_all_symlinks: bool, no_traverse: bool) void {
    if (quiet and (verbose or changed)) {
        print("-f cannot be combined with -v or -c. Exiting.\n", .{});
        exit(1);
    }
    if (dereference and no_dereference) {
        print("--dereference and --no-redereference cannot be specified together. Exiting.\n", .{});
        exit(1);
    }

    if (no_preserve_root and preserve_root) {
        print("--preserve-root and --no-preserve-root cannot be specified together. Exiting.\n", .{});
        exit(1);
    }

    if (no_traverse and (traverse_main_symlink or traverse_all_symlinks)) {
        print("-P cannot be combined with -L or -P. Exiting.\n", .{});
        exit(1);
    }
}
