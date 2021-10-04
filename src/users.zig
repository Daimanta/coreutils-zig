const std = @import("std");
const fs = std.fs;
const os = std.os;
const io = std.io;

const clap = @import("clap.zig");
const version = @import("util/version.zig");
const strings = @import("util/strings.zig");
const time_info = @import("util/time.zig");
const utmp = @import("util/utmp.zig");

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const UtType = utmp.UtType;
const time_t = time_info.time_t;

const allocator = std.heap.page_allocator;

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

    var current_user_file: []const u8 = "/var/run/utmp";

    if (args.positionals().len > 1) {
        std.debug.print("Only one file can be specified. Exiting.\n", .{});
        std.os.exit(1);
    } else if (args.positionals().len == 1) {
        current_user_file = args.positionals()[0];
    }
    try printUsers(allocator, current_user_file);
}

fn printUsers(alloc: *std.mem.Allocator, file_name: []const u8) !void {
    const file_contents = fs.cwd().readFileAlloc(alloc, file_name, 1 << 20) catch "";
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
                var null_index: usize = undefined;
                var found = true;
                strings.indexOf(log.ut_user[0..], 0, &null_index, &found);
                if (!found) null_index = 32;
                const copy = try allocator.alloc(u8, null_index);
                std.mem.copy(u8, copy, log.ut_user[0..null_index]);
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
        for (users[0..insert_index]) |user, i| {
            std.debug.print("{s}", .{user});
            if (i != users[0..insert_index].len - 1) {
                std.debug.print(" ", .{});
            }
        }
        std.debug.print("\n", .{});
    }
}


