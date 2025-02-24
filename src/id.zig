const std = @import("std");
const os = std.os;
const linux = os.linux;

const clap2 = @import("clap2/clap2.zig");
const version = @import("util/version.zig");
const strings = @import("util/strings.zig");
const users = @import("util/users.zig");

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const default_allocator = std.heap.page_allocator;
const print = @import("util/print_tools.zig").print;

const application_name = "id";

const help_message =
\\Usage: id [OPTION]... [USER]...
\\Print user and group information for each specified USER,
\\or (when USER omitted) for the current user.
\\
\\  -Z, --context  print only the security context of the process
\\  -g, --group    print only the effective group ID
\\  -G, --groups   print all group IDs
\\  -n, --name     print a name instead of a number, for -ugG
\\  -r, --real     print the real ID instead of the effective ID, with -ugG
\\  -u, --user     print only the effective user ID
\\  -z, --zero     delimit entries with NUL characters, not whitespace;
\\                   not permitted in default format
\\      --help     display this help and exit
\\      --version  output version information and exit
\\
\\Without any OPTION, print some useful set of identified information.
\\
\\
;

const Mode = enum {
    DEFAULT,
    USER_ONLY,
    USERGROUP_ONLY,
    GROUPS
};


pub fn main() !void {
    const args: []const clap2.Argument = &[_]clap2.Argument{
        clap2.Argument.FlagArgument(null, &[_][]const u8{"help"}),
        clap2.Argument.FlagArgument(null, &[_][]const u8{"version"}),
        clap2.Argument.FlagArgument("Z", &[_][]const u8{"context"}),
        clap2.Argument.FlagArgument("g", &[_][]const u8{"group"}),
        clap2.Argument.FlagArgument("G", &[_][]const u8{"groups"}),
        clap2.Argument.FlagArgument("n", &[_][]const u8{"name"}),
        clap2.Argument.FlagArgument("r", &[_][]const u8{"real"}),
        clap2.Argument.FlagArgument("u", &[_][]const u8{"user"}),
        clap2.Argument.FlagArgument("z", &[_][]const u8{"zero"}),
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

    const security_context = parser.flag("Z");
    _ = security_context;
    const group_id = parser.flag("g");
    const all_groups = parser.flag("G");
    const name = parser.flag("n");
    const real_id = parser.flag("r");
    const user_id = parser.flag("u");
    const zero_terminator = parser.flag("z");
    
    if ((name or real_id) and !(user_id or group_id or all_groups)) {
        print("{s}: cannot print only names or real IDs in default format\n", .{application_name});
        std.posix.exit(1);
    }
    
    if (group_id and all_groups) {
        print("{s}: cannot print \"only\" of more than one choice\n", .{application_name});
        std.posix.exit(1);
    }
    
    if (name and real_id) {
        print("{s}: cannot print \"only\" of more than one choice\n", .{application_name});
        std.posix.exit(1);
    }
    
    var mode = Mode.DEFAULT;
    if (group_id) mode = Mode.USERGROUP_ONLY;
    if (all_groups) mode = Mode.GROUPS;
    if (user_id) mode = Mode.USER_ONLY;
    
    if (mode == Mode.DEFAULT and zero_terminator) {
        print("{s}: option --zero not permitted in default format\n", .{application_name});
        std.posix.exit(1);
    }
    
    const user_list = parser.positionals();
    
    if (user_list.len == 0) {
        const my_uid = linux.geteuid();
        const pw: *users.Passwd = users.getpwuid(my_uid);
        printUserInformation(pw, mode, name, zero_terminator);
    } else{
        for (user_list) |user| {
            printUsernameInformation(user, mode, name, zero_terminator);
        }
    }

}

fn printUsernameInformation(user: []const u8, mode: Mode, name: bool, zero_terminator: bool) void {
    const user_details: *users.Passwd = users.getUserByNameA(user) catch {
            print("{s}: user '{s}' not found\n", .{application_name, user});
            return;
    };
    printUserInformation(user_details, mode, name, zero_terminator);
}

fn printUserInformation(user_details: *users.Passwd, mode: Mode, name: bool, zero_terminator: bool) void {
    if (mode == Mode.DEFAULT) {
        var buffer: [1 << 16]u8 = undefined;
        
        var string_builder = strings.StringBuilder.init(buffer[0..]);
        string_builder.append("uid=");
        string_builder.appendBufPrint("{d}", .{user_details.pw_uid});
        string_builder.append("(");
        string_builder.append(strings.convertOptionalSentinelString(user_details.pw_name).?);
        string_builder.append(") gid=");
        string_builder.appendBufPrint("{d}", .{user_details.pw_gid});
        string_builder.append("(");
        // TODO: Actually use correct group
        string_builder.append(strings.convertOptionalSentinelString(user_details.pw_name).?);
        string_builder.append(") groups=");
        const groups = users.getGroupsFromPasswd(user_details, default_allocator) catch unreachable;
        for (groups, 0..) |group, i| {
            const group_struct = users.getgrgid(group);
            string_builder.appendBufPrint("{d}({s})", .{group_struct.gr_gid, group_struct.gr_name});
            if (i < groups.len - 1) {
                string_builder.append(",");
            }
        }
        print("{s}", .{string_builder.toSlice()});
        print_terminator(zero_terminator, "\n");
    } else if (mode == Mode.USER_ONLY) {
        if (name) {
            print("{s}", .{user_details.pw_name});
        } else {
            print("{d}", .{user_details.pw_uid});
        }
        print_terminator(zero_terminator, "\n");
    } else if (mode == Mode.USERGROUP_ONLY) {
        if (name) {
            print("{s}", .{user_details.pw_name});
        } else {
            // TODO: Actually use correct group
            print("{d}", .{user_details.pw_gid});
        }
        print_terminator(zero_terminator, "\n");
    } else if (mode == Mode.GROUPS) {
        const groups = users.getGroupsFromPasswd(user_details, default_allocator) catch unreachable;
        for (groups, 0..) |group, i| {
            const group_struct = users.getgrgid(group);
            if (name) {
                print("{s}", .{group_struct.gr_name});
            } else {
                print("{d}", .{group_struct.gr_gid});
            }
            if (i < groups.len - 1) {
                print_terminator(zero_terminator, " ");
            }
        }
        print_terminator(zero_terminator, "\n");
    } else {
        unreachable;
    }
    
}


fn print_terminator(zero_terminator: bool, comptime default: []const u8) void {
    if (zero_terminator) {
            print("\u{00}", .{});
        } else {
            print(default, .{});
        }
}
