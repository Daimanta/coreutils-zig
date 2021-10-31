const std = @import("std");
const fs = std.fs;
const os = std.os;

const clap = @import("clap.zig");
const mode = @import("util/mode.zig");
const version = @import("util/version.zig");
const strings = @import("util/strings.zig");

const Allocator = std.mem.Allocator;
const mode_t = mode.mode_t;

const allocator = std.heap.page_allocator;

const application_name = "mkdir";

const help_message =
\\Usage: mkdir [OPTION]... DIRECTORY...
\\Create the DIRECTORY(ies), if they do not already exist.
\\
\\Mandatory arguments to long options are mandatory for short options too.
\\  -m, --mode=MODE   set file mode (as in chmod), not a=rwx - umask
\\  -p, --parents     no error if existing, make parent directories as needed
\\  -v, --verbose     print a message for each created directory
\\  -Z                   set SELinux security context of each created directory
\\                         to the default type
\\      --context[=CTX]  like -Z, or if CTX is specified then set the SELinux
\\                         or SMACK security context to CTX
\\      --help     display this help and exit
\\      --version  output version information and exit
\\
\\
;


pub fn main() !void {
    const params = comptime [_]clap.Param(clap.Help){
        clap.parseParam("--help") catch unreachable,
        clap.parseParam("--version") catch unreachable,
        clap.parseParam("-m, --mode <STR>") catch unreachable,
        clap.parseParam("-Z") catch unreachable,
        clap.parseParam("--context <STR>") catch unreachable,
        clap.parseParam("-p, --parents") catch unreachable,
        clap.parseParam("-v, --verbose") catch unreachable,
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

    const arguments = args.positionals();
    
    var used_mode: mode_t = mode.getModeFromString("a=rw") catch unreachable;
    
    const mode_string = args.option("-m");
    const create_parents = args.flag("-p");
    const verbose = args.flag("-v");
    const default_selinux_context = args.flag("-Z");
    const special_selinux_context = args.option("--context");
    
    if (default_selinux_context and special_selinux_context != null) {
        std.debug.print("SELinux context cannot be both default and specific. Exiting.\n", .{});
        std.os.exit(1);
    }   
    
    if (mode_string != null) {
        used_mode = mode.getModeFromString(mode_string.?) catch |err| {
            switch (err) {
                mode.ModeError.InvalidModeString => std.debug.print("Invalid mode. Exiting.\n", .{}),
                mode.ModeError.UnknownError => std.debug.print("Unknown mode error. Exiting.\n", .{}),
            }
            std.os.exit(1);
        };
    }

    for (arguments) |arg| {
        create_dir(arg, create_parents, verbose, used_mode);
    }
}

fn create_dir(path: []const u8, create_parents: bool, verbose: bool, used_mode: mode_t) void {
    const absolute = (path[0] == '/');
        if (absolute and path.len == 1) {
            std.debug.print("'/' cannot be created.\n", .{});
            return;
        }
        var used_dir: []const u8 = undefined;
        if (path[path.len - 1] == '/') {
            const last_non_index = strings.lastNonIndexOf(path, '/');
            if (last_non_index == null) {
                std.debug.print("'/' cannot be created.\n", .{});
                return;
            }
            used_dir = path[0..last_non_index.?+1];
        } else {
            used_dir = path;
        }
        
        var slash_position = strings.indexOf(used_dir, '/');
        if (slash_position == null) {
            std.os.mkdir(used_dir, @intCast(u32, used_mode)) catch |err| {
                std.debug.print("Error: {s}\n", .{err});
            };
        } else {
            while (slash_position != null) {
                
            }
        }
        
        
        std.debug.print("{s} {s}\n", .{used_dir, absolute});
}




