const std = @import("std");
const fs = std.fs;
const os = std.os;
const linux = os.linux;
const io = std.io;

const clap = @import("clap.zig");
const strings = @import("util/strings.zig");
const version = @import("util/version.zig");
const users = @import("util/users.zig");

const Allocator = std.mem.Allocator;
const ChildProcess = std.ChildProcess;
const File = std.fs.File;

const default_allocator = std.heap.page_allocator;

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
    const params = comptime [_]clap.Param(clap.Help){
        clap.parseParam("--help") catch unreachable,
        clap.parseParam("--version") catch unreachable,
        clap.parseParam("<STRING>") catch unreachable,
    };

    var diag = clap.Diagnostic{};
    var args = clap.parseAndHandleErrors(clap.Help, &params, .{ .diagnostic = &diag }, application_name, 1);
    defer args.deinit();
    
    const arguments = args.positionals();
    const stout = os.STDOUT_FILENO;
    
    var default_filename = "nohup.out";
    
    var output_file: File = undefined;
    
    if (std.os.isatty(stout)) {
        var can_write = true;
        std.fs.cwd().access(".", .{.write = true}) catch |err| {
            can_write = false;
        };
        
        if (!can_write) {
            const uid = linux.geteuid();
            const pw: *users.Passwd = users.getpwuid(uid);
            const home_dir = strings.convertOptionalSentinelString(pw.pw_dir).?;
            std.debug.print("{s} {d}\n", .{home_dir, home_dir.len});
        } else {
            std.debug.print("{s}: ignoring input and appending output to '{s}'\n", .{application_name, default_filename});
            output_file = try std.fs.cwd().createFile(default_filename, .{.truncate = false});
        }
    }
    
    
    var child = try ChildProcess.init(arguments[0..], default_allocator);
    child.stdout = output_file;
    child.stdout_behavior = ChildProcess.StdIo.Pipe;
    try child.spawn();
}
