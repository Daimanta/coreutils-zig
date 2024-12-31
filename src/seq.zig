const std = @import("std");
const fs = std.fs;
const os = std.os;
const linux = os.linux;

const clap2 = @import("clap2/clap2.zig");
const fileinfo = @import("util/fileinfo.zig");
const print_tools = @import("util/print_tools.zig");
const printf = @import("util/printf.zig");
const strings = @import("util/strings.zig");
const version = @import("util/version.zig");
const zig_fixes = @import("util/fmt_zig_temp.zig");

const Allocator = std.mem.Allocator;
const FormatString = printf.FormatString;

const default_allocator = std.heap.page_allocator;
const FollowSymlinkError = fileinfo.FollowSymlinkError;
const kernel_stat = linux.Stat;
const print = print_tools.print;
const pprint = print_tools.pprint;

const application_name = "seq";
const help_message =
\\Usage: seq [OPTION]... LAST
\\  or:  seq [OPTION]... FIRST LAST
\\  or:  seq [OPTION]... FIRST INCREMENT LAST
\\Print numbers from FIRST to LAST, in steps of INCREMENT.
\\
\\Mandatory arguments to long options are mandatory for short options too.
\\  -f, --format=FORMAT      use printf style floating-point FORMAT
\\  -s, --separator=STRING   use STRING to separate numbers (default: \n)
\\  -w, --equal-width        equalize width by padding with leading zeroes
\\      --help     display this help and exit
\\      --version  output version information and exit
\\
\\If FIRST or INCREMENT is omitted, it defaults to 1.  That is, an
\\omitted INCREMENT defaults to 1 even when LAST is smaller than FIRST.
\\The sequence of numbers ends when the sum of the current number and
\\INCREMENT would become greater than LAST.
\\FIRST, INCREMENT, and LAST are interpreted as floating point values.
\\INCREMENT is usually positive if FIRST is smaller than LAST, and
\\INCREMENT is usually negative if FIRST is greater than LAST.
\\INCREMENT must not be 0; none of FIRST, INCREMENT and LAST may be NaN.
\\FORMAT must be suitable for printing one argument of type 'double';
\\it defaults to %.PRECf if FIRST, INCREMENT, and LAST are all fixed point
\\decimal numbers with maximum precision PREC, and to %g otherwise.
\\
\\
;

pub fn main() !void {
    const args: []const clap2.Argument = &[_]clap2.Argument{
        clap2.Argument.FlagArgument(null, &[_][]const u8{"help"}),
        clap2.Argument.FlagArgument(null, &[_][]const u8{"version"}),
        clap2.Argument.FlagArgument("f", &[_][]const u8{"format"}),
        clap2.Argument.OptionArgument("s", &[_][]const u8{"separator"}, false),
        clap2.Argument.FlagArgument("w", &[_][]const u8{"equal-width"}),
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

    const format = parser.option("-f");
    const separatorFlag = parser.option("-s");
    const equal_width = parser.flag("-w");
    const arguments = parser.positionals();

    if (equal_width and format.found) {
        print("{s}: -w and -f cannot be active at the same time. Exiting\n", .{application_name});
        std.posix.exit(1);
    }

    var separator: []const u8 = "\n";
    if (separatorFlag.found) {
        separator = separatorFlag.value.?;
    }

    if (arguments.len == 0) {
        print("{s}: At least one argument required. Exiting\n", .{application_name});
        std.posix.exit(1);
    } else if (arguments.len > 3) {
        print("{s}: At most three arguments are accepted. Exiting\n", .{application_name});
        std.posix.exit(1);
    }
    if (all_integer_arguments(arguments)) {
        process_integers(arguments, equal_width, separator, format.value);
    } else {
        // Either floats or invalid data
    }
}

fn all_integer_arguments(arguments: []const []const u8) bool {
    for (arguments) |arg| {
        if (arg.len == 0) return false;
        const start: usize = if (arg[0] == '-') 1 else 0;
        for (arg[start..]) |char| {
            if (char < '0' or char > '9') return false;
        }
    }
    return true;
}

fn count_digits(input: i64) u8 {
    if (input == 0) return 1;
    if (input < 0) return 1 + count_digits(-1 * input);
    var result: u8 = 0;
    var it = input;
    while (it > 0) {
        result += 1;
        it = @divFloor(it, 10);
    }
    return result;
}

fn process_integers(arguments: []const []const u8, equal_width: bool, separator: []const u8, format: ?[]const u8) void {
    var last: i64 = undefined;
    var increment: i64 = 1;
    var first: i64 = 1;

    if (arguments.len == 1) {
        last = std.fmt.parseInt(i64, arguments[0], 10) catch {
            print("{s}: Argument 1 is too big or too small\n", .{application_name});
            std.posix.exit(1);
        };
    } else if (arguments.len == 2) {
        first = std.fmt.parseInt(i64, arguments[0], 10) catch {
            print("{s}: Argument 1 is too big or too small\n", .{application_name});
            std.posix.exit(1);
        };
        last = std.fmt.parseInt(i64, arguments[1], 10) catch {
            print("{s}: Argument 2 is too big or too small\n", .{application_name});
            std.posix.exit(1);
        };
    } else {
        first = std.fmt.parseInt(i64, arguments[0], 10) catch {
            print("{s}: Argument 1 is too big or too small\n", .{application_name});
            std.posix.exit(1);
        };
        increment = std.fmt.parseInt(i64, arguments[1], 10) catch {
            print("{s}: Argument 2 is too big or too small\n", .{application_name});
            std.posix.exit(1);
        };
        last = std.fmt.parseInt(i64, arguments[2], 10) catch {
            print("{s}: Argument 3 is too big or too small\n", .{application_name});
            std.posix.exit(1);
        };
    }
    if (increment == 0) {
        print("{s}: Increment value cannot be '0'\n", .{application_name});
        std.posix.exit(1);
    }

    if ((last > first and increment < 0) or (last < first and increment > 0)) return;
    var iterator: i64 = first;
    var width: ?u8 = null;
    if (equal_width) {
        width = 1;
        const actual_last_value = first + (@divFloor(last-first, increment) * increment);
        width = @max(count_digits(first), count_digits(actual_last_value));
    }
    var format_string: ?FormatString = null;
    if (format != null) {
        format_string = FormatString.init(format.?, default_allocator) catch std.posix.exit(1);
    }
    defer if (format_string != null) format_string.?.deinit();

    var buffer: [255]u8 = undefined;

    if (increment > 0) {
        while (iterator <= last): (iterator += increment) {
            print_integer(iterator, separator, width, format_string, &buffer);
        }
    } else {
        while (iterator >= last): (iterator += increment) {
            print_integer(iterator, separator, width, format_string, &buffer);
        }
    }
}

fn print_integer(iterator: i64, separator: []const u8, width: ?u8, format: ?FormatString, buffer: []u8) void {
    if (width != null) {
        const len = zig_fixes.formatIntBuf(buffer, iterator, 10, .lower, .{.fill = '0', .width = width.?});
        print("{s}{s}", .{buffer[0..len], separator});
    } else if (format != null) {
        format.?.printf(&.{printf.FormatArgument{.FLOAT = @floatFromInt(iterator)}}) catch std.posix.exit(1);
    } else {
        print("{d}{s}", .{iterator, separator});
    }
}
