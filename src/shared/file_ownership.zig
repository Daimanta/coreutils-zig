const std = @import("std");
const fs = std.fs;
const os = std.os;
const linux = os.linux;

const clap = @import("../clap.zig");
const fileinfo = @import("../util/fileinfo.zig");
const mode_import = @import("../util/mode.zig");
const strings = @import("../util/strings.zig");
const users = @import("../util/users.zig");
const version = @import("../util/version.zig");

const Allocator = std.mem.Allocator;
const ChownError = os.FChownError;
const ChmodError = fileinfo.ChmodError;
const FChmodError = os.FChmodError;
const OpenError = fs.Dir.OpenError;
const OpenFileError = fs.File.OpenError;

const default_allocator = std.heap.page_allocator;
const exit = std.os.exit;
const FollowSymlinkError = fileinfo.FollowSymlinkError;
const KernelStat = linux.Stat;
const mode_t = linux.mode_t;
const print = @import("../util/print_tools.zig").print;

const max_path_length = 1 << 12;

const Verbosity = enum { QUIET, STANDARD, CHANGED, VERBOSE };

const SymlinkTraversal = enum { NO, MAIN, ALL };

const OwnershipOptions = struct { verbosity: Verbosity, dereference_main: bool, recursive: bool, symlink_traversal: SymlinkTraversal, preserve_root: bool, rfile_group: ?[]const u8, only_if_matching: ?[]const u8 };

pub const Program = enum { CHGRP, CHOWN, CHMOD };

const ChangeParams = struct {
    user: ?linux.uid_t,
    group: ?linux.gid_t,
    absolute_mode: ?mode_t,
    mode_string: ?[]const u8,
    from_file: bool,
    original_user_must_match: ?linux.uid_t,
    original_group_must_match: ?linux.gid_t,

    fn isChown(self: @This()) bool {
        return self.user != null or self.group != null;
    }

    fn willChange(self: @This(), stat: KernelStat) bool {
        return (self.original_user_must_match == null or (self.original_user_must_match.? == stat.uid)) and (self.original_group_must_match == null or (self.original_group_must_match.? == stat.gid));
    }
};

pub fn getParams(comptime program: Program) []const clap.Param(clap.Help) {
    const result = switch (program) {
        Program.CHGRP => [_]clap.Param(clap.Help){
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
        },
        Program.CHOWN => [_]clap.Param(clap.Help){
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
            clap.parseParam("--from <STR>") catch unreachable,
            clap.parseParam("-R, --recursive") catch unreachable,
            clap.parseParam("-H") catch unreachable,
            clap.parseParam("-L") catch unreachable,
            clap.parseParam("-P") catch unreachable,
            clap.parseParam("<STRING>") catch unreachable,
        },
        Program.CHMOD => [_]clap.Param(clap.Help){
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
            clap.parseParam("<STRING>") catch unreachable,
        },
    };

    return result[0..];
}

pub fn getOwnershipOptions(comptime params: []const clap.Param(clap.Help), comptime application_name: []const u8, comptime help_message: []const u8, comptime program: Program) OwnershipOptions {
    var diag = clap.Diagnostic{};
    var args = clap.parseAndHandleErrors(clap.Help, params, .{ .diagnostic = &diag }, application_name, 1);

    if (args.flag("--help")) {
        print(help_message, .{});
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
    const traverse_main_symlink = (program != Program.CHMOD) and args.flag("-H");
    const traverse_all_symlinks = (program != Program.CHMOD) and args.flag("-L");
    const no_traverse = (program != Program.CHMOD) and args.flag("-P");
    const only_if_matching = if (program == Program.CHOWN) args.option("--from") else null;

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

    return OwnershipOptions{ .verbosity = verbosity, .dereference_main = dereference_main, .recursive = recursive, .symlink_traversal = symlink_traversal, .preserve_root = preserve_root, .rfile_group = rfile_group, .only_if_matching = only_if_matching };
}

fn traverseDir(path: []const u8, change_params: ChangeParams, verbosity: Verbosity, symlink_traversal: SymlinkTraversal, also_process_dir: bool, application_name: []const u8) void {
    var buffer: [8192]u8 = undefined;
    var string_builder = strings.StringBuilder.init(buffer[0..]);
    string_builder.append(path);
    if (path[path.len - 1] != '/') string_builder.append("/");
    const current_index = string_builder.insertion_index;

    const stat = fileinfo.getLstat(path) catch return;

    const current_user = stat.uid;
    const current_group = stat.gid;

    var dir = fs.cwd().openIterableDir(path, .{}) catch |err| {
        if (verbosity != Verbosity.QUIET) {
            switch (err) {
                OpenError.AccessDenied => print("{s}: Access Denied to '{s}'\n", .{ application_name, path }),
                else => print("{?}\n", .{err}),
            }
        }
        return;
    };

    if (also_process_dir) {
        if (change_params.willChange(stat)) {
            if (dir.chown(change_params.user, change_params.group)) {
                if (verbosity == Verbosity.VERBOSE or (verbosity == Verbosity.CHANGED and ((change_params.group != null and (change_params.group.? != current_group)) or (change_params.user != null and (change_params.user.? != current_user))))) {
                    print("Changed owner/group on '{s}'\n", .{path});
                }
            } else |err| {
                switch (err) {
                    ChownError.AccessDenied => print("{s}: Access Denied to '{s}'\n", .{ application_name, path }),
                    else => print("{?}\n", .{err}),
                }
            }
        }
    }

    var iterator = dir.iterate();
    while (iterator.next() catch return) |element| {
        string_builder.append(element.name);
        changeItem(string_builder.toSlice(), change_params, verbosity, symlink_traversal, application_name);
        string_builder.resetTo(current_index);
    }

    dir.close();
}

pub fn getChangeParams(ownership_options: OwnershipOptions, application_name: []const u8, consider_user: bool, consider_group: bool, consider_mode: bool) ChangeParams {
    var group_id_opt: ?linux.gid_t = null;
    var user_id_opt: ?linux.uid_t = null;
    var mode: ?u64 = null;
    var from_file = false;

    if (ownership_options.rfile_group != null) {
        const lstat = fileinfo.getLstat(ownership_options.rfile_group.?) catch unreachable;
        if (!fileinfo.fileExists(lstat)) {
            print("{s}: RFILE does not exist. Exiting.\n", .{application_name});
            exit(1);
        }
        if (consider_group) {
            group_id_opt = lstat.gid;
        }
        if (consider_user) {
            user_id_opt = lstat.uid;
        }
        if (consider_mode) {
            mode = lstat.mode;
        }
        from_file = true;
    }

    return ChangeParams{ .group = group_id_opt, .user = user_id_opt, .absolute_mode = mode, .mode_string = null, .from_file = from_file, .original_user_must_match = null, .original_group_must_match = null };
}

pub fn changeRights(path: []const u8, change_params: ChangeParams, recursive: bool, verbosity: Verbosity, dereference_main: bool, preserve_root: bool, symlink_traversal: SymlinkTraversal, application_name: []const u8) void {
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

    const is_dir = fileinfo.isDir(stat);
    const is_symlink = fileinfo.isSymlink(stat);

    if (is_dir) {
        var dir = fs.cwd().openIterableDir(path, .{}) catch |err| {
            if (verbosity != Verbosity.QUIET) {
                switch (err) {
                    OpenError.AccessDenied => print("{s}: Access Denied to '{s}'\n", .{ application_name, path }),
                    else => print("{?}\n", .{err}),
                }
            }
            return;
        };
        if (change_params.willChange(stat)) {
            if (change_params.isChown()) {
                if (dir.chown(change_params.user, change_params.group)) {
                    if (verbosity == Verbosity.VERBOSE or (verbosity == Verbosity.CHANGED and ((change_params.group != null and (change_params.group.? != stat.gid)) or (change_params.user != null and (change_params.user.? != stat.uid))))) {
                        print("Changed owner/group on '{s}'\n", .{path});
                    }
                } else |err| {
                    switch (err) {
                        ChownError.AccessDenied => print("{s}: Access Denied to '{s}'\n", .{ application_name, path }),
                        else => print("{?}\n", .{err}),
                    }
                }
            } else {
                const used_mode = if (change_params.absolute_mode != null) change_params.absolute_mode.? else mode_import.getModeFromString(change_params.mode_string.?, stat.mode) catch return;
                if (fileinfo.chmodA(path, used_mode)) {
                    if (verbosity == Verbosity.VERBOSE or (verbosity == Verbosity.CHANGED and ((used_mode != stat.mode)))) {
                        print("Changed mode on '{s}'\n", .{path});
                    }
                } else |err| {
                    print("{s}: Cannot chmod dir '{s}'. {?}\n", .{application_name, path, err});
                }
            }
        }

        defer dir.close();
    } else if (!is_symlink or dereference_main) {
        changePlainFile(path, stat, change_params, verbosity, application_name);
    }

    if (recursive and is_dir) {
        traverseDir(path, change_params, verbosity, symlink_traversal, false, application_name);
    }
}

fn changeItem(path: []const u8, change_params: ChangeParams, verbosity: Verbosity, symlink_traversal: SymlinkTraversal, application_name: []const u8) void {
    const stat = fileinfo.getLstat(path) catch return;

    if (!fileinfo.fileExists(stat)) {
        if (verbosity != Verbosity.QUIET) {
            print("{s}: File '{s}' does not exist.\n", .{ application_name, path });
        }
        return;
    }

    if (fileinfo.isDir(stat)) {
        traverseDir(path, change_params, verbosity, symlink_traversal, true, application_name);
    } else {
        if (symlink_traversal == SymlinkTraversal.ALL or !fileinfo.isSymlink(stat)) {
            changePlainFile(path, stat, change_params, verbosity, application_name);
        }
    }
}

fn changePlainFile(path: []const u8, kernel_stat: ?KernelStat, change_params: ChangeParams, verbosity: Verbosity, application_name: []const u8) void {
    var stat: KernelStat = if (kernel_stat != null) kernel_stat.? else fileinfo.getLstat(path) catch return;

    const current_user = stat.uid;
    const current_group = stat.gid;
    const current_mode = stat.mode;

    if (change_params.willChange(stat)) {
        if (change_params.isChown()) {
            const file = fs.cwd().openFile(path, .{}) catch |err| {
                if (verbosity != Verbosity.QUIET) {
                    switch (err) {
                        OpenFileError.AccessDenied => print("{s}: Access Denied to '{s}'\n", .{ application_name, path }),
                        else => print("{?}\n", .{err}),
                    }
                }
                return;
            };

            defer file.close();

            if (file.chown(change_params.user, change_params.group)) {
                if (verbosity == Verbosity.VERBOSE or (verbosity == Verbosity.CHANGED and ((change_params.user != null and current_user != change_params.user.?) or (change_params.group != null and current_group != change_params.group.?)))) {
                    print("Changed owner/group on '{s}'\n", .{path});
                }
            } else |err| {
                if (verbosity != Verbosity.QUIET) {
                    switch (err) {
                        ChownError.AccessDenied => print("{s}: Access Denied to '{s}'\n", .{ application_name, path }),
                        else => print("{?}\n", .{err}),
                    }
                }
            }
        } else if (!fileinfo.isSymlink(stat)) {
            const used_mode = if (change_params.absolute_mode != null) change_params.absolute_mode.? else mode_import.getModeFromString(change_params.mode_string.?, stat.mode) catch return;
            if (fileinfo.chmodA(path, used_mode)) {
                if (verbosity == Verbosity.VERBOSE or (verbosity == Verbosity.CHANGED and ((current_mode != used_mode)))) {
                    print("Changed owner/group on '{s}'\n", .{path});
                }
            } else |err| {
                if (err == ChmodError.AccessDenied) {
                    print("{s}: Cannot chmod file '{s}'. Access Denied\n", .{application_name, path});
                } else {
                    print("{s}: Cannot chmod file '{s}'. {?}\n", .{application_name, path, err});
                }
                
            }
        }
    }
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
