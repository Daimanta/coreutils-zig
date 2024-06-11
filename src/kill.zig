const std = @import("std");
const fs = std.fs;
const os = std.os;
const io = std.io;
const testing = std.testing;

const clap = @import("clap.zig");
const clap2 = @import("clap2/clap2.zig");
const version = @import("util/version.zig");

const Allocator = std.mem.Allocator;
const LinkError = os.LinkError;

const default_allocator = std.heap.page_allocator;
const print = @import("util/print_tools.zig").print;
const application_name = "kill";

const help_message =
\\Usage: kill [-s SIGNAL | -SIGNAL] PID...
\\  or:  kill -l [SIGNAL]...
\\  or:  kill -t [SIGNAL]...
\\Send signals to processes, or list signals.
\\  -s, --signal=SIGNAL
\\                   specify the name or number of the signal to be sent
\\  -l, --list       list signal names, or convert signal names to/from numbers
\\  -t, --table      print a table of signal information
\\      --help     display this help and exit
\\      --version  output version information and exit
\\  
\\SIGNAL may be a signal name like 'HUP', or a signal number like '1',
\\or the exit status of a process terminated by a signal.
\\PID is an integer; if negative it identifies a process group. 
\\
\\
;

const SIGNALS = [_][]const u8{"SIGHUP", "SIGINT", "SIGQUIT", "SIGILL", "SIGTRAP", "SIGABRT", "SIGBUS", "SIGFPE",
    "SIGKILL", "SIGUSR1", "SIGSEGV", "SIGUSR2", "SIGPIPE", "SIGALRM", "SIGTERM", "SIGSTKFLT", "SIGCHLD", "SIGCONT",
    "SIGSTOP", "SIGTSTP", "SIGTTIN", "SIGTTOU", "SIGURG", "SIGXCPU", "SIGXFSZ", "SIGVTALRM", "SIGPROF", "SIGWINCH",
    "SIGIO", "SIGPWR", "SIGSYS"};

pub fn main() !void {
    const args: []const clap2.Argument = &[_]clap2.Argument{
        .{.shorts = null, .longs = &[_][]const u8{"help"}, .type = .none},
        .{.shorts = null, .longs = &[_][]const u8{"version"}, .type = .none},
        .{.shorts = "l", .longs = &[_][]const u8{"list"}, .type = .many, .allow_none = true},
        .{.shorts = "t", .longs = &[_][]const u8{"table"}, .type = .none},
        .{.shorts = "s", .longs = &[_][]const u8{"signal"}, .type = .one, .allow_none = false},
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

    const list = parser.options("l");
    const table = parser.flag("t");
    const signal_opt = parser.option("s");

    if (list != null and signal_opt != null) {
        print("-l and -s cannot be combined.\n", .{});
        std.posix.exit(1);
    }

    if (list != null) {
        list_signals(list.?, table);
    } else {
        const processes: []const u32 = &[1]u32{2};
        send_signal(signal_opt.?[0], processes);
    }

}

fn list_signals(list: [][]const u8, table: bool) void {
    if (list.len == 0) {
        if (table) {
            const max_digits = 2;
            var max_signame_length: usize = 0;
            for (SIGNALS) |signal| {
                if (signal.len > max_signame_length) {
                    max_signame_length = signal.len;
                }
            }
            const column_width = max_digits + 2 + max_signame_length + 1;
            var i: usize = 0;
            while (i < SIGNALS.len): (i += 1) {
                const signal = SIGNALS[i];
                print("{d}) {s}", .{i, signal});
                var used_length = 1 + 2 + signal.len;
                if (i >= 10) {
                    used_length += 1;
                }

                const extra_spaces = column_width - used_length;
                for (0..extra_spaces) |_| {
                    print(" ", .{});
                }
                if (i % 5 == 4) {
                    print("\n", .{});
                }
            }
            print("\n", .{});
        } else {
            for (SIGNALS, 1..SIGNALS.len+1) |signal, index| {
                print("{d}) {s}\n", .{index, signal});
            }
        }
    } else {
        for (list) |signal| {
            print_signal(signal);
        }
    }
}

fn print_signal(signal: []const u8) void {
    _ = signal;
}

fn send_signal(signal: []const u8, processes:[]const u32) void {
    _ = signal; _ = processes;
}