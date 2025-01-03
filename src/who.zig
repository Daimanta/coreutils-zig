const std = @import("std");
const linux = std.os.linux;
const fs = std.fs;

const mem = std.mem;
const uid = linux.uid_t;
const gid = linux.gid_t;

const clap2 = @import("clap2/clap2.zig");
const version = @import("util/version.zig");
const users = @import("util/users.zig");
const strings = @import("util/strings.zig");
const time_info = @import("util/time.zig");
const utmp = @import("util/utmp.zig");


const Allocator = std.mem.Allocator;
const print = @import("util/print_tools.zig").print;
const UtType = utmp.UtType;

const default_allocator = std.heap.page_allocator;

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
\\If FILE is not specified, use /var/run/utmp first and /var/log/wtmp second.  /var/log/wtmp as FILE is common.
\\If ARG1 ARG2 given, -m presumed: 'am i' or 'mom likes' are usual.
\\
;

extern fn getgrouplist(user: [*:0]const u8, group: gid, groups: [*]gid, ngroups: *c_int) callconv(.C) c_int;

pub fn main() !void {
    const args: []const clap2.Argument = &[_]clap2.Argument{
        clap2.Argument.FlagArgument(null, &[_][]const u8{"help"}),
        clap2.Argument.FlagArgument(null, &[_][]const u8{"version"}),
        clap2.Argument.FlagArgument("a", &[_][]const u8{"all"}),
        clap2.Argument.FlagArgument("b", &[_][]const u8{"boot"}),
        clap2.Argument.FlagArgument("d", &[_][]const u8{"dead"}),
        clap2.Argument.FlagArgument("H", &[_][]const u8{"heading"}),
        clap2.Argument.FlagArgument(null, &[_][]const u8{"ips"}),
        clap2.Argument.FlagArgument("l", &[_][]const u8{"login"}),
        clap2.Argument.FlagArgument(null, &[_][]const u8{"lookup"}),
        clap2.Argument.FlagArgument("m", null),
        clap2.Argument.FlagArgument("p", &[_][]const u8{"process"}),
        clap2.Argument.FlagArgument("q", &[_][]const u8{"count"}),
        clap2.Argument.FlagArgument("r", &[_][]const u8{"runlevel"}),
        clap2.Argument.FlagArgument("s", &[_][]const u8{"short"}),
        clap2.Argument.FlagArgument("tw", &[_][]const u8{"mesg"}),
        clap2.Argument.FlagArgument("u", &[_][]const u8{"users"}),
        clap2.Argument.FlagArgument("v", &[_][]const u8{"verbose"}),
        clap2.Argument.FlagArgument(null, &[_][]const u8{"message"}),
        clap2.Argument.FlagArgument(null, &[_][]const u8{"writable"}),
    };

    var parser = clap2.Parser.init(args);
    defer parser.deinit();

    if (parser.flag("help")) {
        print(help_message, .{});
        std.posix.exit(0);
    } else if (parser.flag("version")) {
        version.printVersionInfo(application_name);
        std.posix.exit(0);
    }

    const all = parser.flag("a");
    const boot = parser.flag("b") or all;
    const dead = parser.flag("d") or all;
    const heading = parser.flag("H");
    const ips = parser.flag("ips");
    const login = parser.flag("l") or all;
    const lookup = parser.flag("lookup");
    const stdin_users = parser.flag("m");
    const processes = parser.flag("p") or all;
    const count = parser.flag("q");
    const runlevel = parser.flag("r") or all;
    const short = parser.flag("s");
    const time = parser.flag("t") or all;
    const message_status = parser.flag("T") or parser.flag("message") or parser.flag("writable") or all;
    const list_users = parser.flag("u") or all;
  
    checkConflicts(boot, dead, heading, ips, login, lookup, stdin_users, processes, count, runlevel, short, time, message_status, list_users);

    const arguments = parser.positionals();

    if (arguments.len == 0) {
        try printInformation(default_allocator, utmp.determine_utmp_file(), boot, dead, heading, ips, login, lookup, stdin_users, processes, count, runlevel, short, time, message_status, list_users);
    } else if (arguments.len == 1) {
        try printInformation(default_allocator, arguments[0], boot, dead, heading, ips, login, lookup, stdin_users, processes, count, runlevel, short, time, message_status, list_users);   
    } else if (arguments.len == 2){
        
    } else {
        print("Zero, one or two arguments expected.\n", .{});
        std.posix.exit(1);
    }
}

fn checkConflicts(boot: bool, dead: bool, heading: bool, ips: bool, login: bool, lookup: bool, stdin_users: bool, processes: bool, count_users: bool, runlevel: bool, short: bool, time: bool, message_status: bool, list_users: bool) void {
    _ = lookup;
    _ = lookup;
    if (count_users and (boot or dead or heading or ips or login or stdin_users or processes or runlevel or short or time or message_status or list_users)) {
        print("{s}: \"-q\" cannot be combined with other output flags", .{application_name});
        std.posix.exit(1);
    }
}

fn intOfBool(boolean: bool) u8 {
    if (boolean) {
        return 1;
    } else {
        return 0;
    }
}


fn printInformation(alloc: std.mem.Allocator, file_name: []const u8, boot: bool, dead: bool, heading: bool, ips: bool, login: bool, lookup: bool, stdin_users: bool, processes: bool, count_users: bool, runlevel: bool, short: bool, time: bool, message_status: bool, list_users: bool) !void {
    _ = ips;
    _ = lookup;
    _ = short;
    _ = time;
    const file_contents = fs.cwd().readFileAlloc(alloc, file_name, 1 << 20) catch "";
    if (file_contents.len > 0 and file_contents.len % @sizeOf(utmp.Utmp) == 0) {
        const utmp_logs = utmp.convertBytesToUtmpRecords(file_contents);
        var count: u32 = 0;
        for (utmp_logs) |log| {
            //print("{s}\n", .{log});
            if (log.ut_type == UtType.USER_PROCESS) {
                count += 1;
            }
        }
        if (count_users) {
            var login_info = try alloc.alloc([]const u8, count);
            var insert_index: usize = 0;
            for (utmp_logs) |log| {
                if (log.ut_type == UtType.USER_PROCESS) {
                    var null_index = strings.indexOf(log.ut_user[0..], 0);
                    if (null_index == null) null_index = 32;
                    const copy = try alloc.alloc(u8, null_index.?);
                    std.mem.copyForwards(u8, copy, log.ut_user[0..null_index.?]);
                    var check_index: usize = 0;
                    var insert = true;
                    while (check_index < insert_index) {
                        if (std.mem.eql(u8, copy, login_info[check_index])) {
                            insert = false;
                        }
                        check_index += 1;
                    }
                    if (insert) {
                        login_info[insert_index] = copy;
                        insert_index+=1;
                    }
                }
            }
            for (login_info[0..insert_index], 0..insert_index) |user, i| {
                print("{s}", .{user});
                if (i != login_info[0..insert_index].len - 1) {
                    print(" ", .{});
                }
            }
            print("\n# users={d}\n", .{insert_index});
        } else {
            if (heading) {
                if (message_status) {
                    print("{s: <10} {s: <12} {s: <17}", .{"NAME", "LINE", "TIME"});
                } else {
                    print("{s: <8} {s: <12} {s: <17}", .{"NAME", "LINE", "TIME"});
                }
                if (login or runlevel or stdin_users) {
                    print("{s: <13}", .{"IDLE"});
                }
                if (login or processes or stdin_users or boot) {
                    print(" {s: <4}", .{"PID"});
                }
                print(" {s: <8}", .{"COMMENT"});
                if (dead) {
                    print(" {s: <8}", .{"EXIT"});
                }
                print("\n", .{});
            }
            for (utmp_logs) |log| {
                if (log.ut_type == UtType.USER_PROCESS and (list_users or !(boot or dead))) {
                    //print("{s}\n", .{log});
                    const username = strings.substringFromNullTerminatedSlice(log.ut_user[0..]);
                    const term = strings.substringFromNullTerminatedSlice(log.ut_line[0..]);
                    const time_struct = time_info.getLocalTimeStructFromi32(log.ut_tv.tv_sec);
                    const time_string = try time_info.toLocalDateTimeStringAlloc(default_allocator, time_struct);
                    if (message_status) {
                        print("{s: <8} +", .{username});
                    } else {
                        print("{s: <8}", .{username});
                    }
                    print(" {s: <12} {s: <16}", .{term, time_string});
                    try printConditionalDetails(alloc, log, login, runlevel, stdin_users, processes, boot);
                } else if (log.ut_type == UtType.BOOT_TIME and boot) {
                    const name = "";
                    const term = "system boot";
                    const time_struct = time_info.getLocalTimeStructFromi32(log.ut_tv.tv_sec);
                    const time_string = try time_info.toLocalDateTimeStringAlloc(default_allocator, time_struct);
                    if (message_status) {
                        print("{s: <10}", .{name});
                    } else {
                        print("{s: <8}", .{name});
                    }
                    print(" {s: <12} {s: <16}", .{term, time_string});
                    print("\n", .{});
                } else if (log.ut_type == UtType.RUN_LVL and runlevel) {
                    const name = "";
                    const term = "run-level 5";
                    const time_struct = time_info.getLocalTimeStructFromi32(log.ut_tv.tv_sec);
                    const time_string = try time_info.toLocalDateTimeStringAlloc(default_allocator, time_struct);
                    if (message_status) {
                        print("{s: <10}", .{name});
                    } else {
                        print("{s: <8}", .{name});
                    }
                    print(" {s: <12} {s: <16}", .{term, time_string});
                    try printConditionalDetails(alloc, log, login, runlevel, stdin_users, processes, boot);
                } else if (log.ut_type == UtType.LOGIN_PROCESS and login) {
                    //print("{s}\n", .{log});
                    const name = "LOGIN";
                    const term = strings.substringFromNullTerminatedSlice(log.ut_line[0..]);
                    const time_struct = time_info.getLocalTimeStructFromi32(log.ut_tv.tv_sec);
                    const time_string = try time_info.toLocalDateTimeStringAlloc(default_allocator, time_struct);
                    if (message_status) {
                        print("{s: <10}", .{name});
                    } else {
                        print("{s: <8}", .{name});
                    }
                    print(" {s: <12} {s: <16}", .{term, time_string});
                    try printConditionalDetails(alloc, log, login, runlevel, stdin_users, processes, boot);
                } else if (log.ut_type == UtType.DEAD_PROCESS and dead) {
                    const name = "";
                    const term = strings.substringFromNullTerminatedSlice(log.ut_line[0..]);
                    const time_struct = time_info.getLocalTimeStructFromi32(log.ut_tv.tv_sec);
                    const time_string = try time_info.toLocalDateTimeStringAlloc(default_allocator, time_struct);
                    if (message_status) {
                        print("{s: <10}", .{name});
                    } else {
                        print("{s: <8}", .{name});
                    }
                    print(" {s: <12} {s: <16}", .{term, time_string});
                    try printConditionalDetails(alloc, log, login, runlevel, stdin_users, processes, boot);
                }
            }
            
        }
    }
}

fn printConditionalDetails(alloc: std.mem.Allocator, utmp_log: utmp.Utmp, login: bool, runlevel: bool, stdin_users: bool, processes: bool, boot: bool) !void {
    _ = alloc;
    if (login or runlevel or stdin_users) {
        if (utmp_log.ut_type == UtType.USER_PROCESS) {
            print("   {s: <10}", .{"."});
        } else {
            print("   {s: <10}", .{""});
        }
    }
    if (login or processes or stdin_users or boot) {
        var pid: []const u8 = "";
        if (utmp_log.ut_pid != 0 and utmp_log.ut_type != UtType.RUN_LVL) {
            var buffer: [10]u8 = undefined;
            pid = std.fmt.bufPrintIntToSlice(buffer[0..], utmp_log.ut_pid, 10, .lower, std.fmt.FormatOptions{});
        }
        print("{s: >5}", .{pid});
    }

    if (utmp_log.ut_type == UtType.RUN_LVL or utmp_log.ut_type == UtType.BOOT_TIME) {
        print(" {s: <9}", .{""});
    } else {
        if (utmp_log.ut_type == UtType.USER_PROCESS) {
            const host_ref = strings.substringFromNullTerminatedSlice(utmp_log.ut_host[0..]);
            if (host_ref.len > 0) {
                print(" ({s})", .{strings.substringFromNullTerminatedSlice(utmp_log.ut_host[0..])});
            } else {
                print(" ", .{});
            }
            
        } else {
            print(" id={s: <6}", .{strings.substringFromNullTerminatedSlice(utmp_log.ut_line[0..])});
        }
    }
    
    if (utmp_log.ut_type == UtType.DEAD_PROCESS) {
        print("term={d} exit={d}", .{utmp_log.ut_exit.e_termination, utmp_log.ut_exit.e_exit});
    }
    print("\n", .{});
}
