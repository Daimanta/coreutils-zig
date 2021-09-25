const std = @import("std");
const fs = std.fs;
const os = std.os;
const io = std.io;

const clap = @import("clap.zig");
const version = @import("util/version.zig");
const strings = @import("util/strings.zig");
const time_info = @import("util/time.zig");

const Allocator = std.mem.Allocator;
const time_t = time_info.time_t;

const allocator = std.heap.page_allocator;

const application_name = "uptime";

const help_message =
\\Usage: uptime [OPTION]... [FILE]
\\Print the current time, the length of time the system has been up,
\\the number of users on the system, and the average number of jobs
\\in the run queue over the last 1, 5 and 15 minutes.
\\Processes in an uninterruptible sleep state also contribute to the load average.
\\If FILE is not specified, use /var/run/utmp.  /var/log/wtmp as FILE is common.
\\
;


pub fn main() !void {
    const params = comptime [_]clap.Param(clap.Help){
        clap.parseParam("--help") catch unreachable,
        clap.parseParam("--version") catch unreachable,
        clap.parseParam("<STRING>") catch unreachable,
    };

    var diag = clap.Diagnostic{};
    var args = clap.parseAndHandleErrors(clap.Help, &params, .{ .diagnostic = &diag }, application_name, 1);
    defer args.deinit();


    if (args.flag("--help")) {
        std.debug.print(help_message, .{});
        std.os.exit(0);
    } else if (args.flag("--version")) {
        version.print_version_info(application_name);
        std.os.exit(0);
    }

    var read_file: []const u8 = "/proc/uptime";

    if (args.positionals().len > 1) {
        std.debug.print("Only one file can be specified. Exiting.\n", .{});
        std.os.exit(1);
    } else if (args.positionals().len == 1) {
        read_file = args.positionals()[0];
    }
    std.debug.print("{s}, ", .{get_uptime_string(allocator, read_file)});
    std.debug.print("{s}, ", .{get_users_string()});
    std.debug.print("{s}\n", .{get_load_string()});
}

fn get_uptime_string(alloc: *std.mem.Allocator, read_file: []const u8) []const u8 {
    var now: time_t = undefined;
    time_info.get_current_time(&now);
    const local_time = time_info.get_local_time_struct(&now);
    const repr = time_info.to_time_string_alloc(alloc, local_time);
    std.debug.print("{s}\n", .{repr});
    var buffer: [1024]u8 = undefined;
    var contents: []u8 = undefined;
    contents = fs.cwd().readFile("/proc/uptime", buffer[0..]) catch unreachable;
    return "??:??:?? up ???? days ??:??";
}

fn get_users_string() []const u8 {
    return "?? users";
}

fn get_load_string() []const u8 {
    return "load average: ?.? ?.? ?.?";
}

fn intToString(int: u32, buf: []u8) ![]const u8 {
    return try std.fmt.bufPrint(buf, "{}", .{int});
}