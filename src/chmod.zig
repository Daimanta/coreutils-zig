const std = @import("std");
const fs = std.fs;
const os = std.os;
const linux = os.linux;

const file_ownership = @import("shared/file_ownership.zig");
const mode = @import("util/mode.zig");
const strings = @import("util/strings.zig");
const users = @import("util/users.zig");

const Allocator = std.mem.Allocator;

const default_allocator = std.heap.page_allocator;
const exit = std.posix.exit;
const print = @import("util/print_tools.zig").print;

const application_name = "chmod";
const help_message =
    \\Usage: chmod [OPTION]... MODE[,MODE]... FILE...
    \\  or:  chmod [OPTION]... OCTAL-MODE FILE...
    \\  or:  chmod [OPTION]... --reference=RFILE FILE...
    \\Change the mode of each FILE to MODE.
    \\With --reference, change the mode of each FILE to that of RFILE.
    \\
    \\  -c, --changes          like verbose but report only when a change is made
    \\  -f, --silent, --quiet  suppress most error messages
    \\  -v, --verbose          output a diagnostic for every file processed
    \\      --no-preserve-root  do not treat '/' specially (the default)
    \\      --preserve-root    fail to operate recursively on '/'
    \\      --reference=RFILE  use RFILE's mode instead of MODE values
    \\  -R, --recursive        change files and directories recursively
    \\      --help     display this help and exit
    \\      --version  output version information and exit
    \\
    \\Each MODE is of the form '[ugoa]*([-+=]([rwxXst]*|[ugo]))+|[-+=][0-7]+'.
    \\
;

const consider_user = false;
const consider_group = false;
const consider_mode = true;

pub fn main() !void {
    const params = comptime file_ownership.getParams2(file_ownership.Program.CHMOD);
    const ownership_options = file_ownership.getOwnershipOptions2(params, application_name, help_message, file_ownership.Program.CHMOD);
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
        change_params.mode_string = positionals[0];
        
    }
    for (positionals[start..]) |arg| {
        file_ownership.changeRights(arg, change_params, ownership_options.recursive, ownership_options.verbosity, ownership_options.dereference_main, ownership_options.preserve_root, ownership_options.symlink_traversal, application_name);
    }
}
