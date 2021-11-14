const std = @import("std");
const linux = std.os.linux;

const mem = std.mem;
const uid = linux.uid_t;
const gid = linux.gid_t;

const clap = @import("clap.zig");
const version = @import("util/version.zig");
const users = @import("util/users.zig");
const strings = @import("util/strings.zig");

const Allocator = std.mem.Allocator;
const print = std.debug.print;

const allocator = std.heap.page_allocator;

const application_name = "who";

const help_message =
\\Usage: who [OPTION]... [ FILE | ARG1 ARG2 ]
\\Print information about users who are currently logged in.
\\
\\  -a, --all         same as -b -d --login -p -r -t -T -u
\\  -b, --boot        time of last system boot
\\  -d, --dead        print dead processes
\\  -H, --heading     print line of column headings
\\      --ips         print ips instead of hostnames. with --lookup,
\\                    canonicalizes based on stored IP, if available,
\\                    rather than stored hostname
\\  -l, --login       print system login processes
\\      --lookup      attempt to canonicalize hostnames via DNS
\\  -m                only hostname and user associated with stdin
\\  -p, --process     print active processes spawned by init
\\  -q, --count       all login names and number of users logged on
\\  -r, --runlevel    print current runlevel
\\  -s, --short       print only name, line, and time (default)
\\  -t, --time        print last system clock change
\\  -T, -w, --mesg    add user's message status as +, - or ?
\\  -u, --users       list users logged in
\\      --message     same as -T
\\      --writable    same as -T
\\      --help     display this help and exit
\\      --version  output version information and exit
\\
\\If FILE is not specified, use /var/run/utmp.  /var/log/wtmp as FILE is common.
\\If ARG1 ARG2 given, -m presumed: 'am i' or 'mom likes' are usual.
\\
;

extern fn getgrouplist(user: [*:0]const u8, group: gid, groups: [*]gid, ngroups: *c_int) callconv(.C) c_int;

pub fn main() !void {

    const params = comptime [_]clap.Param(clap.Help){
        clap.parseParam("--help") catch unreachable,
        clap.parseParam("--version") catch unreachable,
        clap.parseParam("-a, --all") catch unreachable,
        clap.parseParam("-b, --boot") catch unreachable,
        clap.parseParam("-h, --heading") catch unreachable,
        clap.parseParam("--ips") catch unreachable,
        clap.parseParam("-l, --login") catch unreachable,
        clap.parseParam("--lookup") catch unreachable,
        clap.parseParam("-m") catch unreachable,
        clap.parseParam("-p, --process") catch unreachable,
        clap.parseParam("-q, --count") catch unreachable,
        clap.parseParam("-r, --runlevel") catch unreachable,
        clap.parseParam("-s, --short") catch unreachable,
        clap.parseParam("-t, --time") catch unreachable,
        clap.parseParam("-T -w, --mesg") catch unreachable,
        clap.parseParam("-u, --users") catch unreachable,
        clap.parseParam("--message") catch unreachable,
        clap.parseParam("--writable") catch unreachable,
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
    
    const all = args.flag("-a");
    const boot = args.flag("-b");
    const heading = args.flag("-h");
    const ips = args.flag("--ips");
    const login = args.flag("-l");
    const lookup = args.flag("--lookup");
    const stdin_users = args.flag("-m");
    const processes = args.flag("-p") or all;
    const count = args.flag("-q");
    const runlevel = args.flag("-r");
    const short = args.flag("-s");
    const time = args.flag("-t");
    const message_status = args.flag("-T") or args.flag("--message") or args.flag("--writable") or all;
    const list_users = args.flag("-u");
  
    

    const arguments = args.positionals();
    
    
}
