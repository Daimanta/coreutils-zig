const std = @import("std");
const fs = std.fs;
const os = std.os;
const io = std.io;

const clap2 = @import("clap2/clap2.zig");
const version = @import("util/version.zig");
const strings = @import("util/strings.zig");
const time_info = @import("util/time.zig");
const utmp = @import("util/utmp.zig");

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const UtType = utmp.UtType;
const time_t = time_info.time_t;

const allocator = std.heap.page_allocator;
const print = @import("util/print_tools.zig").print;

const application_name = "users";

const help_message =
\\Usage: users [OPTION]... [FILE]
\\Output who is currently logged in according to FILE.
\\If FILE is not specified, use /var/run/utmp.  /var/log/wtmp as FILE is common.
\\
\\      --help     display this help and exit
\\      --version  output version information and exit
\\
;


pub fn main() !void {
    const args: []const clap2.Argument = &[_]clap2.Argument{
        clap2.Argument.FlagArgument(null, &[_][]const u8{"help"}),
        clap2.Argument.FlagArgument(null, &[_][]const u8{"version"}),
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

    const positionals = parser.positionals();

    var current_user_file: []const u8 = "/var/run/utmp";

    if (positionals.len > 1) {
        print("Only one file can be specified. Exiting.\n", .{});
        std.posix.exit(1);
    } else if (positionals.len == 1) {
        current_user_file = positionals[0];
    }
    try printUsers(allocator, current_user_file);
}

fn printUsers(alloc: std.mem.Allocator, file_name: []const u8) !void {
    const backup: []u8 = &.{};
    const file_contents = fs.cwd().readFileAlloc(alloc, file_name, 1 << 20) catch backup;
    if (file_contents.len > 0 and file_contents.len % @sizeOf(utmp.Utmp) == 0) {
        const utmp_logs = utmp.convertBytesToUtmpRecords(file_contents);
        var count: u32 = 0;
        for (utmp_logs) |log| {
            if (log.ut_type == UtType.USER_PROCESS) {
                count += 1;
            }
        }
        var users = try alloc.alloc([]const u8, count);
        var insert_index: usize = 0;
        for (utmp_logs) |log| {
            if (log.ut_type == UtType.USER_PROCESS) {
                var null_index = strings.indexOf(log.ut_user[0..], 0);
                if (null_index == null) null_index = 32;
                const copy = try allocator.alloc(u8, null_index.?);
                std.mem.copyForwards(u8, copy, log.ut_user[0..null_index.?]);
                var check_index: usize = 0;
                var insert = true;
                while (check_index < insert_index) {
                    if (std.mem.eql(u8, copy, users[check_index])) {
                        insert = false;
                    }
                    check_index += 1;
                }
                if (insert) {
                    users[insert_index] = copy;
                    insert_index+=1;
                }
            }
        }
        for (users[0..insert_index], 0..) |user, i| {
            print("{s}", .{user});
            if (i != users[0..insert_index].len - 1) {
                print(" ", .{});
            }
        }
        print("\n", .{});
    }
}


