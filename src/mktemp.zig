const std = @import("std");
const fs = std.fs;
const os = std.os;
const io = std.io;
const mem = std.mem;

const clap2 = @import("clap2/clap2.zig");
const fileinfo = @import("util/fileinfo.zig");
const mode = @import("util/mode.zig");
const version = @import("util/version.zig");
const system = @import("util/system.zig");
const strings = @import("util/strings.zig");

const Allocator = std.mem.Allocator;
const mode_t = mode.mode_t;
const MakeFifoError = fileinfo.MakeFifoError;

const allocator = std.heap.page_allocator;
const exit = std.posix.exit;
const print = @import("util/print_tools.zig").print;
const println = @import("util/print_tools.zig").println;

const application_name = "mktemp";

const help_message =
\\Usage: mktemp [OPTION]... [TEMPLATE]
\\Create a temporary file or directory, safely, and print its name.
\\TEMPLATE must contain at least 3 consecutive 'X's in last component.
\\If TEMPLATE is not specified, use tmp.XXXXXXXXXX, and --tmpdir is implied.
\\Files are created u+rw, and directories u+rwx, minus umask restrictions.
\\
\\-d, --directory     create a directory, not a file
\\-u, --dry-run       do not create anything; merely print a name (unsafe)
\\-q, --quiet         suppress diagnostics about file/dir-creation failure
\\--suffix=SUFF   append SUFF to TEMPLATE; SUFF must not contain a slash.
\\This option is implied if TEMPLATE does not end in X
\\-p DIR, --tmpdir[=DIR]  interpret TEMPLATE relative to DIR; if DIR is not
\\specified, use $TMPDIR if set, else /tmp.  With
\\this option, TEMPLATE must not be an absolute name;
\\TEMPLATE may contain slashes, but
\\mktemp creates only the final component
\\--help     display this help and exit
\\--version  output version information and exit
\\
;

const default_template = "tmp.XXXXXXXXXX";
const default_dir = "/tmp";
const random_chars = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ";

pub fn main() !void {
    const args: []const clap2.Argument = &[_]clap2.Argument{
        .{.shorts = null, .longs = &[_][]const u8{"help"}, .type = .none},
        .{.shorts = null, .longs = &[_][]const u8{"version"}, .type = .none},
        .{.shorts = "d", .longs = &[_][]const u8{"directory"}, .type = .none},
        .{.shorts = "u", .longs = &[_][]const u8{"dry-run"}, .type = .none},
        .{.shorts = "q", .longs = &[_][]const u8{"quiet"}, .type = .none},
        .{.shorts = null, .longs = &[_][]const u8{"suffix"}, .type = .one, .allow_none = false},
        .{.shorts = "p", .longs = &[_][]const u8{"tmpdir"}, .type = .one, .allow_none = false},
    };
    var parser = clap2.Parser.init(args, .{});
    defer parser.deinit();

    if (parser.flag("help")) {
        print(help_message, .{});
        exit(0);
    } else if (parser.flag("version")) {
        version.printVersionInfo(application_name);
        exit(0);
    }

    const arguments = parser.positionals();
    const is_directory = parser.flag("d");
    const dryrun = parser.flag("u");
    const quiet = parser.flag("q");
    const suffix = parser.option("suffix");
    const relative_template = parser.option("p");

    if (arguments.len > 1) {
        println("At most one template can be used.", .{});
        exit(1);
    }



    const template = if(arguments.len == 1) arguments[0] else null;
    const suffix_val = if(suffix.found) suffix.value.? else null;
    const relative_template_val = if (relative_template.found) relative_template.value.? else null;

    _ = try create_temp(template, is_directory, dryrun, quiet, suffix_val, relative_template_val);
}

fn create_temp(template: ?[]const u8, create_directory: bool, dryrun: bool, quiet: bool, suffix: ?[]const u8, relative_template: ?[]const u8) !void {
    const used_template = if (template != null) template.? else default_template;
    var used_relative_template: []const u8 = undefined;
    if (relative_template != null) {
        used_relative_template = relative_template.?;
    } else {
        const env_tempdir = std.posix.getenv("TMPDIR");
        if (env_tempdir != null) {
            used_relative_template = env_tempdir.?;
        } else if (template == null) {
            used_relative_template = default_dir;
        } else {
            used_relative_template = "./";
        }
    }
    const used_suffix = if (suffix != null) suffix.? else "";

    return create_temp_exec(used_template, create_directory, dryrun, quiet, used_suffix, used_relative_template);
}

fn create_temp_exec(template: []const u8, create_directory: bool, dryrun: bool, quiet: bool, suffix: []const u8, relative_template: []const u8) !void {
    const last_xxx_index_opt = mem.lastIndexOf(u8, template, "XXX");
    if (last_xxx_index_opt == null) {
        println("Template should contain at least consecutive 'X' characters.", .{});
        exit(1);
    }
    const last_xxx_index = last_xxx_index_opt.?;
    var template_start = last_xxx_index;
    while (template[template_start] == 'X') {
        if (template_start == 0) break;
        if (template[template_start - 1] == 'X') {
            template_start -= 1;
        } else {
            break;
        }
    }
    const template_end = last_xxx_index + 3;
    var result_string = try allocator.alloc(u8, template.len);
    std.mem.copyForwards(u8, result_string[0..template_start], template[0..template_start]);
    std.mem.copyForwards(u8, result_string[template_end..], template[template_end..]);

    const seed: u64 = @truncate(@as(u128, @bitCast(std.time.nanoTimestamp())));
    var prng = std.Random.DefaultPrng.init(seed);

    for (result_string[template_start..template_end], template_start..template_end) |_, i| {
        const random_index = @mod(prng.random().int(u8), random_chars.len);
        result_string[i] = random_chars[random_index];
    }

    if (std.mem.indexOf(u8, suffix, "/") != null) {
        println("Suffix '{s}' contains illegal directory character '/'", .{suffix});
        exit(1);
    }

    const file_path = try allocator.alloc(u8, relative_template.len + result_string.len + 1 + suffix.len);
    var string_builder = strings.StringBuilder.init(file_path);
    string_builder.append(relative_template);
    string_builder.append("/");
    string_builder.append(result_string);
    string_builder.append(suffix);

    var success = true;
    
    _ = std.fs.cwd().openDir(relative_template, .{}) catch {
        if (!quiet) {
            println("Could not open relative directory '{s}'", .{relative_template});
        }
        success = false;
    };

    if (success) {
        const kernel_stat_opt = fileinfo.getLstat(file_path);
        if (kernel_stat_opt) |kernel_stat| {
            if (fileinfo.fileExists(kernel_stat)) {
                println("Path '{s}' already exists", .{file_path});
                success = false;
            }
        } else |_| {
            if (!quiet) {
                println("Could not access absolute path '{s}'", .{file_path});
            }
            success = false;
        }
    }

    if (!success) {
        std.posix.exit(1);
    }

    if (!dryrun) {
        if (create_directory) {
            std.posix.mkdirat(std.fs.cwd().fd, file_path, 0o700) catch {
                if (!quiet) {
                    println("Could not create directory at '{s}'", .{file_path});
                    exit(1);
                }
            };
        } else {
            _ = std.fs.cwd().createFile(file_path, .{.mode = 0o600}) catch {
                if (!quiet) {
                    println("Could not create file at '{s}'", .{file_path});
                    exit(1);
                }
            };
        }
    }

    println("{s}", .{file_path});
    exit(0);
}

