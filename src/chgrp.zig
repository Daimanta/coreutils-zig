const std = @import("std");
const fs = std.fs;
const os = std.os;
const linux = os.linux;

const file_ownership = @import("shared/file_ownership.zig");
const users = @import("util/users.zig");

const Allocator = std.mem.Allocator;

const default_allocator = std.heap.page_allocator;
const exit = std.posix.exit;
const print = @import("util/print_tools.zig").print;

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

const consider_user = false;
const consider_group = true;
const consider_mode = false;

pub fn main() !void {
    const params = comptime file_ownership.getParams2(file_ownership.Program.CHGRP);
    const ownership_options = file_ownership.getOwnershipOptions2(params, application_name, help_message, file_ownership.Program.CHGRP);
    var change_params = file_ownership.getChangeParams(ownership_options, application_name, consider_user, consider_group, consider_mode);
    const positionals = ownership_options.parser.positionals();
    var start: usize = 1;

    if (positionals.len == 0) {
        print("{s}: Group and file(s) missing. Exiting.\n", .{application_name});
        exit(1);
    } else if (positionals.len == 1 and !change_params.from_file) {
        print("{s}: Group specified but file(s) missing. Exiting.\n", .{application_name});
        exit(1);
    }

    if (change_params.from_file) {
        start = 0;
    } else {
        const group = positionals[0];
        var group_id: linux.gid_t = undefined;
        const group_details = users.getGroupByName(group) catch {
            print("{s}: Group not found. Exiting.\n", .{application_name});
            exit(1);
        };
        group_id = group_details.gr_gid;
        change_params.group = group_id;
    }

    for (positionals[start..]) |arg| {
        file_ownership.changeRights(arg, change_params, ownership_options.recursive, ownership_options.verbosity, ownership_options.dereference_main, ownership_options.preserve_root, ownership_options.symlink_traversal, application_name);
    }
}
