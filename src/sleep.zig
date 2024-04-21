const std = @import("std");
const os = std.os;
const mem = std.mem;

const clap = @import("clap.zig");
const version = @import("util/version.zig");

const Allocator = std.mem.Allocator;

const allocator = std.heap.page_allocator;
const print = @import("util/print_tools.zig").print;

const application_name = "sleep";
const help_message =
\\Usage: sleep NUMBER[SUFFIX]...
\\  or:  sleep OPTION
\\Pause for NUMBER seconds.  SUFFIX may be 's' for seconds (the default),
\\'m' for minutes, 'h' for hours or 'd' for days.  Unlike most implementations
\\that require NUMBER be an integer, here NUMBER may be an arbitrary floating
\\point number.  Given two or more arguments, pause for the amount of time
\\specified by the sum of their values.
\\
\\      --help     display this help and exit
\\      --version  output version information and exit
\\
;

const TimeType = enum {
    second,
    minute,
    hour,
    day,
};

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

    const arguments = try std.process.argsAlloc(allocator);

    if (arguments.len == 1) {
        print("{s}: missing operand\nTry 'sleep --help' for more information.\n", .{application_name});
    }

    var seconds: u64 = 0;
    var nanos: u64 = 0;

    for (arguments[1..]) |argument| {
        updateTimes(argument, &seconds, &nanos) catch {
            print("sleep: invalid time interval '{s}'\n", .{argument});
            std.posix.exit(1);
        };
    }

    std.posix.nanosleep(seconds, nanos);
}

fn updateTimes(string: []const u8, seconds: *u64, nanos: *u64) !void {
    var i = string.len - 1;
    var found_number = false;
    while (i >= 0) {
        if ((string[i] >= '0' and string[i] <= '9') or string[i] == '.') {
            found_number = true;
            break;
        }
        if (i == 0) break;
        i-=1;
    }
    if (!found_number) return error.TimeStringNotValid;

    var double: f64 = -1.0;
    var int: u64 = 0xffffffffffffffff;
    try parseString(string[0..i+1], &double, &int);
    const timeType = getTimeType(string[i+1..]) catch {
        print("sleep: invalid time interval '{s}'\n", .{string});
        std.posix.exit(1);
    };
    var add_seconds: u64 = undefined;
    var add_nanos: u64 = undefined;
    if (double == -1.0) {
        getTimesFromIntegerAndTimeType(int, timeType, &add_seconds, &add_nanos);
    } else {
        getTimesFromDoubleAndTimeType(double, timeType, &add_seconds, &add_nanos);
    }
    seconds.* += add_seconds;
    nanos.* += add_nanos;
    if (nanos.* > 1_000_000_000) {
        seconds.* += 1;
        nanos.* -= 1_000_000_000;
    }
}

fn getTimesFromDoubleAndTimeType(double: f64, time_type: TimeType, seconds: *u64, nanos: *u64) void {
    var multiplied_value = double;
    if (time_type == TimeType.second) {
        multiplied_value = double;
    } else if (time_type == TimeType.minute) {
        multiplied_value = double * 60;
    } else if (time_type == TimeType.hour) {
        multiplied_value = double * 60 * 60;
    } else if (time_type == TimeType.day) {
        multiplied_value = double * 60 * 60 * 24;
    }

    const int_part: u64 = @intFromFloat(multiplied_value);
    const nanos_part: u64 = @intFromFloat((multiplied_value-@as(f64, @floatFromInt(int_part))) * 1_000_000_000);
    seconds.* = int_part;
    nanos.* = nanos_part;
}

fn getTimesFromIntegerAndTimeType(int: u64, time_type: TimeType, seconds: *u64, nanos: *u64) void {
    nanos.* = 0;
    if (time_type == TimeType.second) {
        seconds.* = int;
    } else if (time_type == TimeType.minute) {
        seconds.* = int * 60;
    } else if (time_type == TimeType.hour) {
        seconds.* = int * 60 * 60;
    } else if (time_type == TimeType.day) {
        seconds.* = int * 60 * 60 * 24;
    }
}

fn getTimeType(string: []const u8) !TimeType {
    if (string.len == 0 or mem.eql(u8, string, "s")) {
        return TimeType.second;
    } else if (mem.eql(u8, string, "m")) {
        return TimeType.minute;
    } else if (mem.eql(u8, string, "h")) {
        return TimeType.hour;
    } else if (mem.eql(u8, string, "d")) {
        return TimeType.day;
    }

    return error.TimeTypeNotFound;
}

fn parseString(str: []const u8, double: *f64, int: *u64) !void {
    var has_dot = false;
    for (str) |char| {
        if (char == '.') {
            has_dot = true;
            break;
        }
    }
    if (!has_dot) {
        int.* = try std.fmt.parseInt(u64, str[0..], 10);
        return;
    } else {
        double.* = try std.fmt.parseFloat(f64, str[0..]);
        return;
    }
    return;
}
