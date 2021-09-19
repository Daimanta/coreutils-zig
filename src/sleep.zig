const std = @import("std");
const fs = std.fs;
const os = std.os;

const clap = @import("clap.zig");
const version = @import("util/version.zig");

const Allocator = std.mem.Allocator;

const allocator = std.heap.page_allocator;

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

pub fn main() !void {
    const params = comptime [_]clap.Param(clap.Help){
        clap.parseParam("--help") catch unreachable,
        clap.parseParam("--version") catch unreachable,
        clap.parseParam("<STRING>") catch unreachable,
    };

    var diag = clap.Diagnostic{};
    var args = clap.parseAndHandleErrors(clap.Help, &params, .{ .diagnostic = &diag }, application_name, 1);
    defer args.deinit();

    var resolve_symlink = false;

    if (args.flag("--help")) {
        std.debug.print(help_message, .{});
        std.os.exit(0);
    } else if (args.flag("--version")) {
        version.print_version_info(application_name);
        std.os.exit(0);
    }

    const arguments = try std.process.argsAlloc(allocator);

    var seconds: u64 = 0;
    var nanos: u64 = 0;

    for (arguments[1..]) |argument| {
        update_times(argument, &seconds, &nanos) catch |err| {
            std.debug.print("sleep: invalid time interval '{s}'\n", .{argument});
            std.os.exit(1);
        };
    }

    std.debug.print("{d} {d}\n", .{seconds, nanos});
}

fn update_times(string: []const u8, seconds: *u64, nanos: *u64) !void {
    var i = string.len - 1;
    while (i >= 0) {
        if ((string[i] >= '0' and string[i] <= '9') or string[i] == '.') break;
        if (i == 0) break;
        i-=1;
    }
    if (i == 0) {
       if (string.len == 1) {
            if (string[0] >= '0' and string[0] <= '9') {
                seconds.* += string[0] - '0';
            } else {
                return error.TimeStringNotValid;
            }
       } else {
            if (string[0] >= '0' and string[0] <= '9') {
                // seconds.* += string[0] - '0';
            } else {
                return error.TimeStringNotValid;
            }
       }
    } else {
        var double: f64 = -1.0;
        var int: u64 = 0xffffffffffffffff;
        try parseString(string[0..i+1], &double, &int);
        if (double == -1.0) {
            seconds.* += int;
        } else {
            var int_part = @floatToInt(u64, double);
            var nanos_part = @floatToInt(u64, (double-@intToFloat(f64, int_part)) * 1_000_000_000);
            seconds.* += int_part;
            nanos.* += nanos_part;
        }
    }
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
