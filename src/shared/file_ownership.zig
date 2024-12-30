const std = @import("std");
const fs = std.fs;
const os = std.os;
const linux = os.linux;

const clap = @import("../clap.zig");
const clap2 = @import("../clap2/clap2.zig");
const fileinfo = @import("../util/fileinfo.zig");
const mode_import = @import("../util/mode.zig");
const strings = @import("../util/strings.zig");
const users = @import("../util/users.zig");
const version = @import("../util/version.zig");

const Allocator = std.mem.Allocator;
const ChownError = std.posix.FChownError;
const ChmodError = fileinfo.ChmodError;
const FChmodError = std.posix.FChmodError;
const OpenError = fs.Dir.OpenError;
const OpenFileError = fs.File.OpenError;

const default_allocator = std.heap.page_allocator;
const exit = std.posix.exit;
const FollowSymlinkError = fileinfo.FollowSymlinkError;
const KernelStat = linux.Stat;
const mode_t = linux.mode_t;
const print = @import("../util/print_tools.zig").print;

const max_path_length = 1 << 12;

const Verbosity = enum { QUIET, STANDARD, CHANGED, VERBOSE };

const SymlinkTraversal = enum { NO, MAIN, ALL };

const OwnershipOptions = struct { verbosity: Verbosity, dereference_main: bool, recursive: bool, symlink_traversal: SymlinkTraversal, preserve_root: bool, rfile_group: ?[]const u8, only_if_matching: ?[]const u8, parser: clap2.Parser };

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

pub fn getParams(comptime program: Program) []const clap2.Argument{
    const baseArgs = [_]clap2.Argument{
        clap2.Argument.FlagArgument(null, &[_][]const u8{"help"}),
        clap2.Argument.FlagArgument(null, &[_][]const u8{"version"}),
        clap2.Argument.FlagArgument("c", &[_][]const u8{"changes"}),
        clap2.Argument.FlagArgument("f", &[_][]const u8{"silent"}),
        clap2.Argument.FlagArgument(null, &[_][]const u8{"quiet"}),
        clap2.Argument.FlagArgument("v", &[_][]const u8{"verbose"}),
        clap2.Argument.FlagArgument(null, &[_][]const u8{"derefence"}),
        clap2.Argument.FlagArgument("h", &[_][]const u8{"no-redereference"}),
        clap2.Argument.FlagArgument(null, &[_][]const u8{"no-preserve-root"}),
        clap2.Argument.FlagArgument(null, &[_][]const u8{"preserve-root"}),
        clap2.Argument.FlagArgument("R", &[_][]const u8{"recursive"}),
        clap2.Argument.OptionArgument(null, &[_][]const u8{"reference"}, false)
    };
    switch (program) {
        Program.CHGRP => {
            return baseArgs ++ &[_]clap2.Argument{
                clap2.Argument.FlagArgument("H", null),
                clap2.Argument.FlagArgument("L", null),
                clap2.Argument.FlagArgument("P", null),
            };
        },
        Program.CHOWN => {
            return baseArgs ++ &[_]clap2.Argument{
                clap2.Argument.FlagArgument("H", null),
                clap2.Argument.FlagArgument("L", null),
                clap2.Argument.FlagArgument("P", null),
                clap2.Argument.OptionArgument(null, &[_][]const u8{"from"}, false),
            };
        },
        Program.CHMOD => {
            return baseArgs ++ &[_]clap2.Argument{};
        }
    }
    unreachable;
}

pub fn getOwnershipOptions(comptime args: []const clap2.Argument, comptime application_name: []const u8, comptime help_message: []const u8, comptime program: Program) OwnershipOptions {
    var parser = clap2.Parser.init(args);
    defer parser.deinit();

    if (parser.flag("help")) {
        print(help_message, .{});
        exit(0);
    } else if (parser.flag("version")) {
        version.printVersionInfo(application_name);
        exit(0);
    }

    const changed = parser.flag("c");
    const quiet = parser.flag("quiet") or parser.flag("f");
    const verbose = parser.flag("v");
    const dereference = parser.flag("dereference");
    const no_dereference = parser.flag("h");
    const no_preserve_root = parser.flag("no-preserve-root");
    const preserve_root = parser.flag("preserve-root");
    const rfile_group = parser.option("reference");
    const recursive = parser.flag("R");
    const traverse_main_symlink = (program != Program.CHMOD) and parser.flag("H");
    const traverse_all_symlinks = (program != Program.CHMOD) and parser.flag("L");
    const no_traverse = (program != Program.CHMOD) and parser.flag("P");
    const only_if_matching = if (program == Program.CHOWN) parser.option("from") else clap2.OptionValue{};

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

    return OwnershipOptions{ .verbosity = verbosity, .dereference_main = dereference_main, .recursive = recursive, .symlink_traversal = symlink_traversal, .preserve_root = preserve_root, .rfile_group = rfile_group.value, .only_if_matching = only_if_matching.value, .parser = parser };
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

    var dir = fs.cwd().openDir(path, .{}) catch |err| {
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
        var dir = fs.cwd().openDir(path, .{}) catch |err| {
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
    const stat: KernelStat = if (kernel_stat != null) kernel_stat.? else fileinfo.getLstat(path) catch return;

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
