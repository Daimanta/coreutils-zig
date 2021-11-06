const std = @import("std");
const os = std.os;
const linux = os.linux;

const clap = @import("clap.zig");
const version = @import("util/version.zig");
const strings = @import("util/strings.zig");
const users = @import("util/users.zig");

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const UtType = utmp.UtType;

const default_allocator = std.heap.page_allocator;
const print = std.debug.print;

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


pub fn main() !void {
    const params = comptime [_]clap.Param(clap.Help){
        clap.parseParam("--help") catch unreachable,
        clap.parseParam("--version") catch unreachable,
        clap.parseParam("-Z, --context") catch unreachable,
        clap.parseParam("-g, --group") catch unreachable,
        clap.parseParam("-G, --groups") catch unreachable,
        clap.parseParam("-n, --name") catch unreachable,
        clap.parseParam("-r, --real") catch unreachable,
        clap.parseParam("-u, --user") catch unreachable,
        clap.parseParam("-z, --zero") catch unreachable,
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
    
    const security_context = args.flag("-Z");
    const group_id = args.flag("-g");
    const all_groups = args.flag("-G");
    const name = args.flag("-n");
    const real_id = args.flag("-r");
    const user_id = args.flag("-u");
    const zero_terminator = args.flag("-z");
    
    if ((name or real_id) and !(user_id or group_id or all_groups)) {
        print("{s}: cannot print only names or real IDs in default format\n", .{application_name});
        os.exit(1);
    }
    
    
    const user_list = args.positionals();
    
    if (user_list.len == 0) {
        const my_uid = linux.geteuid();
        const pw: *users.Passwd = users.getpwuid(my_uid);
        printUserInformation(pw);
    } else{
        for (user_list) |user| {
            printUsernameInformation(user);
        }
    }

}

fn printUsernameInformation(user: []const u8) void {
    const user_details: *users.Passwd = users.getUserByNameA(user) catch |err| {
            print("{s}\n", .{err});
            return;
    };
    printUserInformation(user_details);
}

fn printUserInformation(user: *users.Passwd) void {
    print("{s}\n", .{user});
}


