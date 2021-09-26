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
        version.printVersionInfo(application_name);
        std.os.exit(0);
    }

    var read_file: []const u8 = "/proc/uptime";

    if (args.positionals().len > 1) {
        std.debug.print("Only one file can be specified. Exiting.\n", .{});
        std.os.exit(1);
    } else if (args.positionals().len == 1) {
        read_file = args.positionals()[0];
    }
    std.debug.print("{s}, ", .{getUptimeString(allocator, read_file)});
    std.debug.print("{s}, ", .{getUsersString()});
    std.debug.print("{s}\n", .{getLoadString()});
}

fn getUptimeString(alloc: *std.mem.Allocator, read_file: []const u8) []const u8 {
    var now: time_t = undefined;
    time_info.getCurrentTime(&now);
    const local_time = time_info.getLocalTimeStruct(&now);
    const time_repr = time_info.toTimeStringAlloc(alloc, local_time);

    var can_determine_uptime = true;
    var buffer: [1024]u8 = undefined;
    var contents: []u8 = undefined;
    contents = fs.cwd().readFile(read_file, buffer[0..]) catch "";

    var space_index: usize = undefined;
    var found_space: bool = false;
    strings.indexOf(contents, ' ', &space_index, &found_space);
    var days: u32 = undefined;
    var hours: u32 = undefined;
    var minutes: u32 = undefined;
    var uptime_buffer: [30]u8 = undefined;
    var uptime_buffer_size: usize = undefined;
    if (found_space) {
        const uptime_string = contents[0..space_index];
        const uptime_float = std.fmt.parseFloat(f64, uptime_string) catch std.math.nan(f64);
        if (uptime_float == std.math.nan(f64)) {
            can_determine_uptime = false;
        } else {
            var uptime_int = @floatToInt(u32, uptime_float);
            std.debug.print("{d}\n", .{uptime_int});
        }
    } else {
        can_determine_uptime = false;
    }

    if (can_determine_uptime) {

    } else {

    }
    return "??:??:?? up ???? days ??:??";
}

fn getUsersString() []const u8 {
    return "?? users";
}

fn getLoadString() []const u8 {
    return "load average: ?.? ?.? ?.?";
}
