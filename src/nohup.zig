const std = @import("std");
const fs = std.fs;
const os = std.os;
const linux = os.linux;
const io = std.io;

const clap2 = @import("clap2/clap2.zig");
const strings = @import("util/strings.zig");
const version = @import("util/version.zig");
const users = @import("util/users.zig");

const Allocator = std.mem.Allocator;
const ChildProcess = std.process.Child;
const File = std.fs.File;

const default_allocator = std.heap.page_allocator;
const print = @import("util/print_tools.zig").print;

const application_name = "nohup";

const help_message =
\\ Usage: nohup COMMAND [ARG]...
\\   or:  nohup OPTION
\\ Run COMMAND, ignoring hangup signals.
\\ 
\\       --help     display this help and exit
\\       --version  output version information and exit
\\ 
\\ If standard input is a terminal, redirect it from an unreadable file.
\\ If standard output is a terminal, append output to 'nohup.out' if possible,
\\ '$HOME/nohup.out' otherwise.
\\ If standard error is a terminal, redirect it to standard output.
\\ To save output to FILE, use 'nohup COMMAND > FILE'.
\\ 
\\ NOTE: your shell may have its own version of nohup, which usually supersedes
\\ the version described here.  Please refer to your shell's documentation
\\ for details about the options it supports.
\\
\\
;


pub fn main() !void {
    const args: []const clap2.Argument = &[_]clap2.Argument{
        clap2.Argument.FlagArgument(null, &[_][]const u8{"help"}),
        clap2.Argument.FlagArgument(null, &[_][]const u8{"version"}),
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

    const arguments = parser.positionals();
    const stout = std.c.STDOUT_FILENO;
    
    var default_filename = "nohup.out";
    
    var output_file: File = undefined;
    
    if (std.posix.isatty(stout)) {
        var can_write = true;
        std.fs.cwd().access(".", .{.mode = .write_only}) catch {
            can_write = false;
        };
        
        var target: []const u8 = default_filename[0..];
        
        if (!can_write) {
            const uid = linux.geteuid();
            const pw: *users.Passwd = users.getpwuid(uid);
            const home_dir = strings.convertOptionalSentinelString(pw.pw_dir).?;
            var path_buffer: [4096]u8 = undefined;
            var string_builder = strings.StringBuilder.init(path_buffer[0..]);
            string_builder.append(home_dir);
            if (home_dir[home_dir.len - 1] != '/') string_builder.append("/"[0..]);
            string_builder.append(default_filename[0..]);
            target = string_builder.toSlice();
        }
        
        print("{s}: ignoring input and appending output to '{s}'\n", .{application_name, target});
        output_file = try std.fs.cwd().createFile(target, .{.truncate = false});
    }
    
    
    var child = ChildProcess.init(arguments[0..], default_allocator);
    
    if (std.posix.isatty(stout)) {
        _ = linux.dup2(output_file.handle, std.c.STDOUT_FILENO);
    }
    
    try child.spawn();
}
