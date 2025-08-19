const std = @import("std");
const fs = std.fs;
const mem = std.mem;
const os = std.os;
const posix = std.posix;
const io = std.io;
const testing = std.testing;

const clap = @import("clap2/clap2.zig");
const fileinfo = @import("util/fileinfo.zig");
const version = @import("util/version.zig");

const Allocator = std.mem.Allocator;
const LinkError = os.LinkError;

const default_allocator = std.heap.page_allocator;
const exit = std.posix.exit;
const print = @import("util/print_tools.zig").print;

const application_name = "ln";

const help_message =
\\Usage: ln [OPTION]... [-T] TARGET LINK_NAME
\\  or:  ln [OPTION]... TARGET
\\  or:  ln [OPTION]... TARGET... DIRECTORY
\\  or:  ln [OPTION]... -t DIRECTORY TARGET...
\\In the 1st form, create a link to TARGET with the name LINK_NAME.
\\In the 2nd form, create a link to TARGET in the current directory.
\\In the 3rd and 4th forms, create links to each TARGET in DIRECTORY.
\\Create hard links by default, symbolic links with --symbolic.
\\By default, each destination (name of new link) should not already exist.
\\When creating hard links, each TARGET must exist.  Symbolic links
\\can hold arbitrary text; if later resolved, a relative link is
\\interpreted in relation to its parent directory.
\\
\\Mandatory arguments to long options are mandatory for short options too.
\\      --backup[=CONTROL]      make a backup of each existing destination file
\\  -b                          like --backup but does not accept an argument
\\  -d, -F, --directory         allow the superuser to attempt to hard link
\\                                directories (note: will probably fail due to
\\                                system restrictions, even for the superuser)
\\  -f, --force                 remove existing destination files
\\  -i, --interactive           prompt whether to remove destinations
\\  -L, --logical               dereference TARGETs that are symbolic links
\\  -n, --no-dereference        treat LINK_NAME as a normal file if
\\                                it is a symbolic link to a directory
\\  -P, --physical              make hard links directly to symbolic links
\\  -r, --relative              create symbolic links relative to link location
\\  -s, --symbolic              make symbolic links instead of hard links
\\  -S, --suffix=SUFFIX         override the usual backup suffix
\\  -t, --target-directory=DIRECTORY  specify the DIRECTORY in which to create
\\                                the links
\\  -T, --no-target-directory   treat LINK_NAME as a normal file always
\\  -v, --verbose               print name of each linked file
\\      --help     display this help and exit
\\      --version  output version information and exit
\\
\\The backup suffix is '~', unless set with --suffix or SIMPLE_BACKUP_SUFFIX.
\\The version control method may be selected via the --backup option or through
\\the VERSION_CONTROL environment variable.  Here are the values:
\\
\\  none, off       never make backups (even if --backup is given)
\\  numbered, t     make numbered backups
\\  existing, nil   numbered if numbered backups exist, simple otherwise
\\  simple, never   always make simple backups
\\
\\
;

var handled_stdin = false;

const BackupMode = enum { Disabled, Numbered, Simple, NumberedIfPresent};
const LinkMode = enum { PhysicalDir, Physical, Symbolic, SymbolicRelative};
const InteractionMode = enum { Default, Interactive, Overwrite};

const targets_and_dir = struct {
      directory: ?[]const u8,
      targets: [][]const u8,
      link_name: ?[]const u8
};


pub fn main() !void {
    const args: []const clap.Argument = &[_]clap.Argument{
        clap.Argument.FlagArgument(null, &[_][]const u8{"help"}),
        clap.Argument.FlagArgument(null, &[_][]const u8{"version"}),
        clap.Argument.FlagArgument("b", null),
        clap.Argument.FlagArgument("d", &[_][]const u8{"directory"}),
        clap.Argument.FlagArgument("F", null),
        clap.Argument.FlagArgument("f", &[_][]const u8{"force"}),
        clap.Argument.FlagArgument("i", &[_][]const u8{"interactive"}),
        clap.Argument.FlagArgument("L", &[_][]const u8{"logical"}),
        clap.Argument.FlagArgument("n", &[_][]const u8{"no-dereference"}),
        clap.Argument.FlagArgument("P", &[_][]const u8{"physical"}),
        clap.Argument.FlagArgument("r", &[_][]const u8{"relative"}),
        clap.Argument.FlagArgument("s", &[_][]const u8{"symbolic"}),
        clap.Argument.FlagArgument("T", &[_][]const u8{"no-target-directory"}),
        clap.Argument.FlagArgument("v", &[_][]const u8{"verbose"}),
        clap.Argument.OptionArgument(null, &[_][]const u8{"backup"}, true),
        clap.Argument.OptionArgument("S", &[_][]const u8{"suffix"}, false),
        clap.Argument.OptionArgument("t", &[_][]const u8{"target-directory"}, false),
    };

    var parser = clap.Parser.init(args, .{});
    defer parser.deinit();

    if (parser.flag("help")) {
        print(help_message, .{});
        exit(0);
    } else if (parser.flag("version")) {
        version.printVersionInfo(application_name);
        exit(0);
    }

    const backup = parser.option("backup");
    const directory = parser.flag("d") or parser.flag("F");
    const force = parser.flag("f");
    const interactive = parser.flag("i");
    const logical = parser.flag("L");
    const no_dereference = parser.flag("n");
    const physical = parser.flag("P");
    const relative = parser.flag("r");
    const symbolic = parser.flag("s");
    const suffix = parser.option("S");
    const target_directory_option = parser.option("t");
    const no_target_directory = parser.flag("T");
    const verbose = parser.flag("v");
    const backupWithoutType = parser.flag("b");

    _ = suffix; _ = verbose;
    checkInconsistencies(directory, symbolic, physical, relative, force, interactive, target_directory_option.found, no_target_directory, logical, no_dereference, backup, backupWithoutType);
    
    const positionals = parser.positionals();
    const backupType = getBackupType(backup, backupWithoutType);

    if (positionals.len == 0) {
        print("{s}: No targets specified. Exiting.\n", .{application_name});
        exit(1);
    } else {
        const target_inputs = getTargetsAndDir(target_directory_option, positionals);
        const link_mode = getLinkMode(directory, physical, relative, symbolic);
        const interaction_mode = getInteractionMode(force, interactive);
        createLinks(target_inputs, backupType, interaction_mode, link_mode, !no_dereference);
    }
}

fn checkInconsistencies(directory: bool, symbolic: bool, physical: bool, relative: bool, force: bool, interactive: bool, target_directory: bool, no_target_directory: bool, logical: bool, no_dereference: bool, backup: clap.OptionValue, backupWithoutType: bool) void {
    if (target_directory and no_target_directory) {
        print("{s}: -t and -T cannot be active at the same time. Exiting.\n", .{application_name});
        exit(1);
    }
    
    if (force and interactive) {
        print("{s}: -f and -i cannot be active at the same time. Exiting.\n", .{application_name});
        exit(1);
    }
    
    if ((directory or physical) and (symbolic or relative)) {
        print("{s}: -d or -P cannot be combined with -s or -r. Exiting.\n", .{application_name});
        exit(1);
    }
    
    if (logical and no_dereference) {
        print("{s}: -L and -n cannot be active at the same time. Exiting.\n", .{application_name});
        exit(1);
    }

    if (backup.found and backupWithoutType) {
        print("{s}: --backup and -b cannot be active at the same time. Exiting.\n", .{application_name});
        exit(1);
    }

}

fn getBackupType(backup: clap.OptionValue, backupWithoutType: bool) BackupMode {
    // We already checked that both values are not set at the same time
    if (!backup.found and !backupWithoutType) {
        return BackupMode.Disabled;
    } else if (backupWithoutType) {
        return BackupMode.Simple;
    } else {
        if (!backup.hasArgument) {
            return BackupMode.Simple;
        } else {
            const argumentValue = backup.value.?;
            if (std.mem.eql(u8, argumentValue, "simple") or std.mem.eql(u8, argumentValue, "never")) {
                return BackupMode.Simple;
            } else if (std.mem.eql(u8, argumentValue, "existing") or std.mem.eql(u8, argumentValue, "nil")) {
                return BackupMode.NumberedIfPresent;
            } else if (std.mem.eql(u8, argumentValue, "numbered") or std.mem.eql(u8, argumentValue, "t")) {
                return BackupMode.Numbered;
            } else if (std.mem.eql(u8, argumentValue, "none") or std.mem.eql(u8, argumentValue, "off")) {
                return BackupMode.Disabled;
            } else {
                print("{s}: option '{s}' for backup not recognized. Exiting.\n", .{application_name, argumentValue});
                exit(1);
            }
        }
    }
}

fn getLinkMode(directory: bool, physical: bool, relative: bool, symbolic: bool) LinkMode {
    // Clashing settings are filtered out already
    if (directory) return LinkMode.PhysicalDir;
    if (physical) return LinkMode.Physical;
    if (relative) return LinkMode.SymbolicRelative;
    if (symbolic) return LinkMode.Symbolic;
    return LinkMode.Physical;
}

fn getInteractionMode(force: bool, interactive: bool) InteractionMode {
    if (force) return InteractionMode.Overwrite;
    if (interactive) return InteractionMode.Interactive;
    return InteractionMode.Default;
}

fn getTargetsAndDir(targetDirectory: clap.OptionValue, positionals: [][]const u8) targets_and_dir {
    if (targetDirectory.found and targetDirectory.hasArgument) {
        return targets_and_dir{.directory = targetDirectory.value.?, .targets = positionals, .link_name = null};
    } else if (positionals.len == 1) {
        return targets_and_dir{.directory = ".", .targets = positionals, .link_name = null};
    } else if (positionals.len > 2) {
        return targets_and_dir{.directory = positionals[positionals.len - 1], .targets = positionals[0..positionals.len - 1], .link_name = null};
    } else {
        // len == 2
        return targets_and_dir{.directory = null, .targets = positionals[0..1], .link_name = positionals[1]};
    }
}

fn createLinks(target_inputs: targets_and_dir, backup_type: BackupMode, interaction_mode: InteractionMode, link_mode: LinkMode, dereference: bool) void {
    if (target_inputs.link_name != null) {
        createLink(target_inputs.targets[0], target_inputs.link_name.?, backup_type, interaction_mode, link_mode, dereference);
    } else {
        
    }
    std.debug.print("{any} {any} {any}\n", .{target_inputs.directory, target_inputs.link_name, target_inputs.targets});
}

fn createLink(target: []const u8, link_location: []const u8, backup_type: BackupMode, interaction_mode: InteractionMode, link_mode: LinkMode, dereference: bool) void {
    _ = backup_type; _ = interaction_mode; _ = dereference;
    if (link_mode == .Symbolic or link_mode == .SymbolicRelative) {
        std.posix.symlink(target, link_location) catch |err|{
            print("{any}\n", .{err});
            print("{s}: Failed to create symbolic link. Exiting.\n", .{application_name});
            exit(1);
        };
    } else {
        std.posix.link(target, link_location) catch {
            print("{s}: Failed to create link. Exiting.\n", .{application_name});
            exit(1);
        };
    }

}