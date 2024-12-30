const std = @import("std");
const fs = std.fs;
const os = std.os;
const io = std.io;

const clap = @import("clap.zig");
const clap2 = @import("clap2/clap2.zig");
const version = @import("util/version.zig");
const strings = @import("util/strings.zig");
const time_info = @import("util/time.zig");
const utmp = @import("util/utmp.zig");

const Allocator = std.mem.Allocator;
const time_t = time_info.time_t;
const Case = std.fmt.Case;

const allocator = std.heap.page_allocator;
const print = @import("util/print_tools.zig").print;

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
        print(help_message, .{});
        std.posix.exit(0);
    } else if (args.flag("--version")) {
        version.printVersionInfo(application_name);
        std.posix.exit(0);
    }

    var current_user_file: []const u8 = "/var/run/utmp";

    if (args.positionals().len > 1) {
        print("Only one file can be specified. Exiting.\n", .{});
        std.posix.exit(1);
    } else if (args.positionals().len == 1) {
        current_user_file = args.positionals()[0];
    }
    print(" {s},  ", .{try getUptimeString(allocator)});
    print("{s},  ", .{try getUsersString(allocator, current_user_file)});
    print("{s}\n", .{try getLoadString(allocator)});
}

fn getUptimeString(alloc: std.mem.Allocator) ![]const u8 {
    const read_file: []const u8 = "/proc/uptime";
    var now: time_t = undefined;
    time_info.getCurrentTime(&now);
    const local_time = time_info.getLocalTimeStruct(&now);
    const time_repr = try time_info.toTimeStringAlloc(alloc, local_time);
    defer alloc.free(time_repr);

    var can_determine_uptime = true;
    var buffer: [1024]u8 = undefined;
    var contents: []u8 = undefined;
    contents = fs.cwd().readFile(read_file, buffer[0..]) catch "";

    const space_index = strings.indexOf(contents, ' ');
    var days: u32 = undefined;
    var hours: u32 = undefined;
    var minutes: u32 = undefined;
    var uptime_buffer: [30]u8 = undefined;
    var stringBuilder = strings.StringBuilder.init(uptime_buffer[0..]);
    if (space_index != null) {
        const uptime_string = contents[0..space_index.?];
        const uptime_float = std.fmt.parseFloat(f64, uptime_string) catch std.math.nan(f64);
        if (uptime_float == std.math.nan(f64)) {
            can_determine_uptime = false;
        } else {
            var uptime_int: u32 = @intFromFloat(uptime_float);
            days = uptime_int / std.time.s_per_day;
            uptime_int -= days * std.time.s_per_day;
            hours = uptime_int / std.time.s_per_hour;
            uptime_int -= hours * std.time.s_per_hour;
            minutes = uptime_int / std.time.s_per_min;
        }
    } else {
        can_determine_uptime = false;
    }
    
    stringBuilder.append(time_repr);

    if (can_determine_uptime) {
        stringBuilder.append(" up ");
        var num_buffer: [10]u8 = undefined;
        if (days > 0) {
            stringBuilder.append(std.fmt.bufPrintIntToSlice(num_buffer[0..], days, 10, Case.lower, std.fmt.FormatOptions{}));
            const descr: []const u8 = switch(days > 1) {
                true => " days ",
                false => " day ",
            };
            stringBuilder.append(descr);
        }
        stringBuilder.append(std.fmt.bufPrintIntToSlice(num_buffer[0..], hours, 10, Case.lower, std.fmt.FormatOptions{}));
        stringBuilder.append(":");
        stringBuilder.append(std.fmt.bufPrintIntToSlice(num_buffer[0..], minutes, 10, Case.lower, std.fmt.FormatOptions{.width=2, .fill='0'}));
    } else {
        stringBuilder.append(" up ???? days ??:??");
    }
    return stringBuilder.toOwnedSlice(alloc);
}

fn getUsersString(alloc: std.mem.Allocator, file_name: []const u8) ![]const u8 {
    const backup: []u8 = &.{};
    const file_contents = fs.cwd().readFileAlloc(alloc, file_name, 1 << 20) catch backup;
    const count = switch (file_contents.len > 0 and file_contents.len % @sizeOf(utmp.Utmp) == 0) {
        false => 0,
        true => utmp.countActiveUsers(utmp.convertBytesToUtmpRecords(file_contents))
    };
    var buffer: [64]u8 = undefined;
    var numbuffer: [10]u8 = undefined;
    var stringBuilder = strings.StringBuilder.init(buffer[0..]);
    stringBuilder.append(std.fmt.bufPrintIntToSlice(numbuffer[0..], count, 10, Case.lower, std.fmt.FormatOptions{}));
    if (count == 1) {
        stringBuilder.append(" user");
    } else {
        stringBuilder.append(" users");
    }
    return stringBuilder.toOwnedSlice(alloc);
}

fn getLoadString(alloc: std.mem.Allocator) ![]const u8 {
    const file_name: []const u8 = "/proc/loadavg";
    const begin: []const u8 = "load average: ";
    const unknown: []const u8 = "?.?, ?.?, ?.?";
    const file_contents = fs.cwd().readFileAlloc(alloc, file_name, 2 << 20) catch "";
    if (file_contents.len == 0) {
        return begin ++ unknown;
    } else {
        var index: usize = 0;
        var matches: [3]usize = undefined;
        var count: u8 = 0;
        while (index < file_contents.len and count < 3): (index += 1) {
            if (file_contents[index] == ' ') {
                matches[@as(usize, count)] = index;
                count += 1;
            }
            if (count == 3) break;
        }
        if (count == 3) {
            var buffer: [30]u8 = undefined;
            var stringBuilder = strings.StringBuilder.init(buffer[0..]);
            stringBuilder.append(begin);
            stringBuilder.append(file_contents[0..matches[0]]);
            stringBuilder.append(", ");
            stringBuilder.append(file_contents[matches[0]+1..matches[1]]);
            stringBuilder.append(", ");
            stringBuilder.append(file_contents[matches[1]+1..matches[2]]);
            return try stringBuilder.toOwnedSlice(alloc);
        } else {
            return begin ++ unknown;
        }
    }
}
