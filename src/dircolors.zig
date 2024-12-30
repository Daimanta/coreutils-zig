const std = @import("std");
const fs = std.fs;
const mem = std.mem;
const os = std.os;
const io = std.io;

const clap = @import("clap.zig");
const clap2 = @import("clap2/clap2.zig");
const version = @import("util/version.zig");
const strings = @import("util/strings.zig");

const defaults = @embedFile("./data/dircolors.defaults");

const Allocator = std.mem.Allocator;

const default_allocator = std.heap.page_allocator;
const print = @import("util/print_tools.zig").print;
const startsWith = mem.startsWith;
const eql = mem.eql;

const application_name = "dircolors";

const help_message =
    \\Usage: dircolors [OPTION]... [FILE]
    \\Output commands to set the LS_COLORS environment variable.
    \\
    \\Determine format of output:
    \\  -b, --sh, --bourne-shell    output Bourne shell code to set LS_COLORS
    \\  -c, --csh, --c-shell        output C shell code to set LS_COLORS
    \\  -p, --print-database        output defaults
    \\      --help     display this help and exit
    \\      --version  output version information and exit
    \\
    \\If FILE is specified, read it to determine which colors to use for which
    \\file types and extensions.  Otherwise, a precompiled database is used.
    \\For details on the format of these files, run 'dircolors --print-database'.
    \\
    \\
;

const env_name: []const u8 = "LS_COLORS";

pub fn main() !void {
    const args: []const clap2.Argument = &[_]clap2.Argument{
        clap2.Argument.FlagArgument(null, &[_][]const u8{"help"}),
        clap2.Argument.FlagArgument(null, &[_][]const u8{"version"}),
        clap2.Argument.FlagArgument("b", &[_][]const u8{"sh"}),
        clap2.Argument.FlagArgument(null, &[_][]const u8{"bourne-shell"}),
        clap2.Argument.FlagArgument("c", &[_][]const u8{"csh"}),
        clap2.Argument.FlagArgument("p", &[_][]const u8{"print-database"}),
        clap2.Argument.FlagArgument("z", &[_][]const u8{"zero"}),
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
    
    const bourne = parser.flag("b") or parser.flag("bourne-shell");
    const csh = parser.flag("c");
    const print_database = parser.flag("p");
    
    const flag_count = @intFromBool(bourne) + @intFromBool(csh) + @intFromBool(print_database);
    if (flag_count > 1) {
        print("A maximum of one of -b, -c, and -p is allowed. Exiting.\n", .{});
        std.posix.exit(1);
    }
    
    const arguments = parser.positionals();
    
    if (arguments.len > 1) {
        print("Either no argument, or one file needs to be specified. Exiting.\n", .{});
        std.posix.exit(1);
    }
    
    if (arguments.len == 1) {
        try parseDircolorsFile(arguments[0], csh);
    } else {
        const env = std.posix.getenv(env_name);
        if (env != null) {
            if (print_database) {
                print("{s}", .{defaults});
            } else if (csh) {
                print("setenv LS_COLORS '{s}'\n", .{env.?});
            } else {
                // Bourne shell implied
                print("LS_COLORS='{s}';\nexport LS_COLORS\n", .{env.?});
            }
            
        }
    }
}

fn parseDircolorsFile(path: []const u8, csh: bool) !void {
    const file_contents = fs.cwd().readFileAlloc(default_allocator, path, 1 << 20) catch "";
    defer default_allocator.free(file_contents);
    var lines = std.mem.tokenize(u8, file_contents, "\n"[0..]);
    var buffer: [1 << 20]u8 = undefined;
    var string_builder = strings.StringBuilder.init(buffer[0..]);
    if (csh) {
        string_builder.append("setenv LS_COLORS '");
    } else {
        string_builder.append("LS_COLORS='");
    }
    
    while (lines.next()) |line| {
        if (line.len > 0 and !std.mem.startsWith(u8, line, "#") and !std.mem.startsWith(u8, line, " #") and !std.mem.startsWith(u8, line, "TERM")) {
            const considered = line[0..std.mem.indexOf(u8, line, " #") orelse line.len];
            var pair = std.mem.tokenize(u8, considered, " ");
            var first: []const u8 = undefined;
            var second: []const u8 = undefined;
            
            if (pair.next()) |value| {
                first = value;
            } else {
                continue;
            }
            
            if (pair.next()) |value| {
                second = value;
            } else {
                continue;
            }
            
            if (!validColorString(second)) {
                continue;
            }
            
            if (std.mem.startsWith(u8, considered, ".")) {
                // Extension
                string_builder.append("*");
                string_builder.append(first);
            } else {
                // Builtin
                const matched = matchBuiltin(first);
                if (matched == null) {
                    continue;
                }
                string_builder.append(matched.?);
            }
            string_builder.append("=");
            string_builder.append(second);
            string_builder.append(":");
        }
    }
    if (csh) {
        string_builder.append("'\n");
    } else {
        string_builder.append("';\nexport LS_COLORS\n");
    }
    
    print("{s}", .{string_builder.toSlice()});
}

fn matchBuiltin(key: []const u8) ?[]const u8 {
    if (eql(u8, key, "NORMAL"[0..])) {
        return "no"[0..];
    }
    if (eql(u8, key, "FILE"[0..])) {
        return "fi"[0..];
    }
    if (eql(u8, key, "RESET"[0..])) {
        return "rs"[0..];
    }
    if (eql(u8, key, "DIR"[0..])) {
        return "di"[0..];
    }
    if (eql(u8, key, "LINK"[0..])) {
        return "ln"[0..];
    }
    if (eql(u8, key, "MULTIHARDLINK"[0..])) {
        return "mh"[0..];
    }
    if (eql(u8, key, "FIFO"[0..])) {
        return "pi"[0..];
    }
    if (eql(u8, key, "SOCK"[0..])) {
        return "so"[0..];
    }
    if (eql(u8, key, "DOOR"[0..])) {
        return "do"[0..];
    }
    if (eql(u8, key, "BLK"[0..])) {
        return "rs"[0..];
    }
    if (eql(u8, key, "CHR"[0..])) {
        return "cd"[0..];
    }
    if (eql(u8, key, "ORPHAN"[0..])) {
        return "or"[0..];
    }
    if (eql(u8, key, "MISSING"[0..])) {
        return "mi"[0..];
    }
    if (eql(u8, key, "SETUID"[0..])) {
        return "su"[0..];
    }
    if (eql(u8, key, "SETGID"[0..])) {
        return "sg"[0..];
    }
    if (eql(u8, key, "CAPABILITY"[0..])) {
        return "ca"[0..];
    }
    if (eql(u8, key, "STICKY_OTHER_WRITABLE"[0..])) {
        return "tw"[0..];
    }
    if (eql(u8, key, "OTHER_WRITABLE"[0..])) {
        return "ow"[0..];
    }
    if (eql(u8, key, "STICKY"[0..])) {
        return "st"[0..];
    }
    if (eql(u8, key, "EXEC"[0..])) {
        return "ex"[0..];
    }
    
    return null;
}

fn validColorString(value: []const u8) bool {
    var counter: u8 = 0;
    var iterator = std.mem.tokenize(u8, value, ";");
    while (iterator.next()) |number_string| {
        const number = std.fmt.parseInt(u32, number_string, 10) catch return false;
        if (number > 47 or (number > 8 and number < 30) or (number > 37 and number < 40)) {
            return false;
        }
        counter += 1;
        if (counter > 3) {
            return false;
        }
    }
    
    return true;
}
