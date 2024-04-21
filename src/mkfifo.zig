const std = @import("std");
const fs = std.fs;
const os = std.os;
const io = std.io;

const clap = @import("clap.zig");
const fileinfo = @import("util/fileinfo.zig");
const mode = @import("util/mode.zig");
const version = @import("util/version.zig");
const system = @import("util/system.zig");

const Allocator = std.mem.Allocator;
const mode_t = mode.mode_t;
const MakeFifoError = fileinfo.MakeFifoError;

const allocator = std.heap.page_allocator;
const print = @import("util/print_tools.zig").print;

const application_name = "mkfifo";

const help_message =
\\Usage: mkfifo [OPTION]... NAME...
\\Create named pipes (FIFOs) with the given NAMEs.
\\
\\Mandatory arguments to long options are mandatory for short options too.
\\  -m, --mode=MODE    set file permission bits to MODE, not a=rw - umask
\\  -Z                   set the SELinux security context to default type
\\      --context[=CTX]  like -Z, or if CTX is specified then set the SELinux
\\                         or SMACK security context to CTX
\\      --help     display this help and exit
\\      --version  output version information and exit
\\
\\
;

var success = true;

pub fn main() !void {
    const params = comptime [_]clap.Param(clap.Help){
        clap.parseParam("--help") catch unreachable,
        clap.parseParam("--version") catch unreachable,
        clap.parseParam("-m, --mode <STR>") catch unreachable,
        clap.parseParam("-Z") catch unreachable,
        clap.parseParam("--context <STR>") catch unreachable,
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

    const arguments = args.positionals();

    
    var used_mode: mode_t = mode.getModeFromStringAndZeroMode("a=rw") catch unreachable;
    
    const mode_string = args.option("-m");
    const default_selinux_context = args.flag("-Z");
    const special_selinux_context = args.option("--context");
    
    if (default_selinux_context and special_selinux_context != null) {
        print("SELinux context cannot be both default and specific. Exiting.\n", .{});
        std.posix.exit(1);
    }   
    
    if (mode_string != null) {
        used_mode = mode.getModeFromStringAndZeroMode(mode_string.?) catch |err| {
            switch (err) {
                mode.ModeError.InvalidModeString => print("Invalid mode. Exiting.\n", .{}),
                mode.ModeError.UnknownError => print("Unknown mode error. Exiting.\n", .{}),
            }
            std.posix.exit(1);
        };
    }

    for (arguments) |arg| {
        fileinfo.makeFifo(arg, used_mode) catch |err| {
            switch (err) {
                MakeFifoError.WritePermissionDenied => print("{s}: Write Permission Denied\n", .{application_name}),
                MakeFifoError.FileAlreadyExists => print("{s}: File Already exists\n", .{application_name}),
                MakeFifoError.NameTooLong => print("{s}: Name too long\n", .{application_name}),
                MakeFifoError.IncorrectPath => print("{s}: Incorrect path\n", .{application_name}),
                MakeFifoError.ReadOnlyFileSystem => print("{s}: Filesystem is read only\n", .{application_name}),
                MakeFifoError.NotSupported => print("{s}: Operation not supported\n", .{application_name}),
                MakeFifoError.QuotaReached => print("{s}: Quota reached\n", .{application_name}),
                MakeFifoError.NoSpaceLeft => print("{s}: No space left on device\n", .{application_name}),
                MakeFifoError.NotImplemented => print("{s}: Named pipes are not possible on file system\n", .{application_name}),
                MakeFifoError.Unknown => print("{s}: Unknown error encountered: '{?}'\n", .{application_name, err}),
            }
        };
        success = false;
    }
    
    if (!success) {
        std.posix.exit(1);
    }
}




