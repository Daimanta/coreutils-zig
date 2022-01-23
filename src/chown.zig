const std = @import("std");
const fs = std.fs;
const os = std.os;
const linux = os.linux;

const clap = @import("clap.zig");
const file_ownership = @import("shared/file_ownership.zig");
const strings = @import("util/strings.zig");
const users = @import("util/users.zig");

const Allocator = std.mem.Allocator;

const default_allocator = std.heap.page_allocator;
const exit = std.os.exit;
const print = std.debug.print;

const application_name = "chown";
const help_message =
    \\Usage: chown [OPTION]... [OWNER][:[GROUP]] FILE...
    \\  or:  chown [OPTION]... --reference=RFILE FILE...
    \\Change the owner and/or group of each FILE to OWNER and/or GROUP.
    \\With --reference, change the owner and group of each FILE to those of RFILE.
    \\
    \\  -c, --changes          like verbose but report only when a change is made
    \\  -f, --silent, --quiet  suppress most error messages
    \\  -v, --verbose          output a diagnostic for every file processed
    \\      --dereference      affect the referent of each symbolic link (this is
    \\                         the default), rather than the symbolic link itself
    \\  -h, --no-dereference   affect symbolic links instead of any referenced file
    \\                         (useful only on systems that can change the
    \\                         ownership of a symlink)
    \\      --from=CURRENT_OWNER:CURRENT_GROUP
    \\                         change the owner and/or group of each file only if
    \\                         its current owner and/or group match those specified
    \\                         here.  Either may be omitted, in which case a match
    \\                         is not required for the omitted attribute
    \\      --no-preserve-root  do not treat '/' specially (the default)
    \\      --preserve-root    fail to operate recursively on '/'
    \\      --reference=RFILE  use RFILE's owner and group rather than
    \\                         specifying OWNER:GROUP values
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
    \\Owner is unchanged if missing.  Group is unchanged if missing, but changed
    \\to login group if implied by a ':' following a symbolic OWNER.
    \\OWNER and GROUP may be numeric as well as symbolic.
    \\
    \\Examples:
    \\  chown root /u        Change the owner of /u to "root".
    \\  chown root:staff /u  Likewise, but also change its group to "staff".
    \\  chown -hR root /u    Change the owner of /u and subfiles to "root".
    \\
;

const consider_user = true;
const consider_group = true;
const consider_mode = false;

pub fn main() !void {
    const params = comptime file_ownership.getParams(file_ownership.Program.CHOWN);
    const ownership_options = file_ownership.getOwnershipOptions(params, application_name, help_message, file_ownership.Program.CHOWN);
    var change_params = file_ownership.getChangeParams(ownership_options, application_name, consider_user, consider_group, consider_mode);
    var diag = clap.Diagnostic{};
    var args = clap.parseAndHandleErrors(clap.Help, params, .{ .diagnostic = &diag }, application_name, 1);
    const positionals = args.positionals();
    var start: usize = 1;

    if (positionals.len == 0) {
        print("{s}: Group and file(s) missing. Exiting.\n", .{application_name});
        exit(1);
    } else if (positionals.len == 1 and !change_params.from_file) {
        print("{s}: Group specified but file(s) missing. Exiting.\n", .{application_name});
        exit(1);
    }

    if (ownership_options.only_if_matching != null and ownership_options.only_if_matching.?.len > 0) {
        const colon_index = strings.indexOf(ownership_options.only_if_matching.?, ':');

        var user: []const u8 = undefined;
        var group: ?[]const u8 = null;

        if (colon_index != null) {
            if (colon_index == ownership_options.only_if_matching.?.len - 1) {
                print("{s}: Empty group provided. Exiting.\n", .{application_name});
                exit(1);
            }
            user = ownership_options.only_if_matching.?[0..colon_index.?];
            group = ownership_options.only_if_matching.?[colon_index.? + 1 ..];
        } else {
            user = ownership_options.only_if_matching.?;
        }
        const user_details = users.getUserByNameA(ownership_options.only_if_matching.?) catch {
            print("{s}: Group not found. Exiting.\n", .{application_name});
            exit(1);
        };
        change_params.original_user_must_match = user_details.pw_uid;

        if (group != null) {
            const group_details = users.getGroupByName(group.?) catch {
                print("{s}: Group not found. Exiting.\n", .{application_name});
                exit(1);
            };
            change_params.original_group_must_match = group_details.gr_gid;
        }
    }

    if (change_params.from_file) {
        start = 0;
    } else {
        const owner_and_group = positionals[0];
        const colon_index = strings.indexOf(owner_and_group, ':');

        var user: []const u8 = undefined;
        var group: ?[]const u8 = null;

        if (colon_index != null) {
            if (colon_index == owner_and_group.len - 1) {
                print("{s}: Empty group provided. Exiting.\n", .{application_name});
                exit(1);
            }
            user = owner_and_group[0..colon_index.?];
            group = owner_and_group[colon_index.? + 1 ..];
        } else {
            user = owner_and_group;
        }

        const user_details = users.getUserByNameA(owner_and_group) catch {
            print("{s}: Group not found. Exiting.\n", .{application_name});
            exit(1);
        };
        change_params.user = user_details.pw_uid;

        if (group != null) {
            const group_details = users.getGroupByName(group.?) catch {
                print("{s}: Group not found. Exiting.\n", .{application_name});
                exit(1);
            };
            change_params.group = group_details.gr_gid;
        }
    }
    for (positionals[start..]) |arg| {
        file_ownership.changeRights(arg, change_params, ownership_options.recursive, ownership_options.verbosity, ownership_options.dereference_main, ownership_options.preserve_root, ownership_options.symlink_traversal, application_name);
    }
}
