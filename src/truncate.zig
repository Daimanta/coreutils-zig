const std = @import("std");
const fs = std.fs;
const os = std.os;

const clap2 = @import("clap2/clap2.zig");
const fileinfo = @import("util/fileinfo.zig");
const mode = @import("util/mode.zig");
const version = @import("util/version.zig");
const strings = @import("util/strings.zig");

const Allocator = std.mem.Allocator;
const mode_t = mode.mode_t;
const MakeDirError = std.posix.MakeDirError;
const OpenError = fs.Dir.OpenError;

const allocator = std.heap.page_allocator;
const exit = std.posix.exit;
const print = @import("util/print_tools.zig").print;
const pprintln = @import("util/print_tools.zig").pprintln;
const ftruncate = std.posix.ftruncate;

const application_name = "truncate";

const help_message =
\\Usage: truncate OPTION... FILE...
\\Shrink or extend the size of each FILE to the specified size
\\
\\A FILE argument that does not exist is created.
\\
\\If a FILE is larger than the specified size, the extra data is lost.
\\If a FILE is shorter, it is extended and the sparse extended part (hole)
\\reads as zero bytes.
\\
\\Mandatory arguments to long options are mandatory for short options too.
\\-c, --no-create        do not create any files
\\-o, --io-blocks        treat SIZE as number of IO blocks instead of bytes
\\-r, --reference=RFILE  base size on RFILE
\\-s, --size=SIZE        set or adjust the file size by SIZE bytes
\\--help     display this help and exit
\\--version  output version information and exit
\\
\\The SIZE argument is an integer and optional unit (example: 10K is 10*1024).
\\Units are K,M,G,T,P,E (powers of 1024) or KB,MB,... (powers of 1000).
\\Binary prefixes can be used, too: KiB=K, MiB=M, and so on.
\\
\\SIZE may also be prefixed by one of the following modifying characters:
\\'+' extend by, '-' reduce by, '<' at most, '>' at least,
\\'/' round down to multiple of, '%' round up to multiple of.
\\
;

const SizeType = enum {
    EXACT,
    EXTEND,
    REDUCE,
    AT_MOST,
    AT_LEAST,
    ROUND_DOWN,
    ROUND_UP
};

const SizeValue = struct {
    size_type: SizeType,
    value: u64
};

pub fn main() !void {
    const args: []const clap2.Argument = &[_]clap2.Argument{
        clap2.Argument.FlagArgument(null, &[_][]const u8{"help"}),
        clap2.Argument.FlagArgument(null, &[_][]const u8{"version"}),
        clap2.Argument.FlagArgument("c", &[_][]const u8{"no-create"}),
        clap2.Argument.FlagArgument("o", &[_][]const u8{"io-blocks"}),
        clap2.Argument.OptionArgument("r", &[_][]const u8{"reference"}, false),
        clap2.Argument.OptionArgument("s", &[_][]const u8{"size"}, false),
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
    
    const no_create = parser.flag("c");
    const size_in_blocks = parser.flag("o");
    const reference_file = parser.option("r");
    const size = parser.option("s");

    if (reference_file.found and (size_in_blocks or size.found)) {
        print("{s}: '-r' cannot be active with '-o' or '-s'. Exiting.\n", .{application_name});
        exit(1);
    }

    if (!(reference_file.found or size.found)) {
        print("{s}: Size must be specified by '-r' or '-s'. Exiting.\n", .{application_name});
        exit(1);
    }

    truncate_files(arguments, size.value, size_in_blocks, !no_create, reference_file.value);

}

fn truncate_files(paths: [][]const u8, size_opt: ?[]const u8, size_in_blocks: bool, do_create: bool, reference_file: ?[]const u8) void {
    var size: SizeValue = undefined;
    if (reference_file != null) {
        if (fileinfo.getLstat(reference_file.?)) |file_stat| {
            if (!fileinfo.fileExists(file_stat)) {
                print("{s}: Reference file '{s}' does not exist. Exiting.\n", .{application_name, reference_file.?});
                exit(1);
            } else {
                size = SizeValue{
                    .size_type = .EXACT,
                    .value = @intCast(file_stat.size)
                };
            }
        } else |_|{
            print("{s}: Could not access reference file '{s}'. Exiting.\n", .{application_name, reference_file.?});
            exit(1);
        }
    } else {
        size = parseSize(size_opt.?);
    }
    truncate_files_exec(paths, size, size_in_blocks, do_create);
}

fn truncate_files_exec(paths: [][]const u8, size: SizeValue, size_in_blocks: bool, do_create: bool) void {
    for (paths) |file| {
        const stat = fileinfo.getLstat(file) catch {
            print("{s}: Error accessing file '{s}'. Exiting.\n", .{application_name, file});
            exit(1);
        };

        if (!fileinfo.fileExists(stat)) {
            if (!do_create) continue;
            const created_file = std.fs.cwd().createFile(file, .{}) catch {
                print("{s}: Error creating file '{s}'. Exiting.\n", .{application_name, file});
                exit(1);
            };
            created_file.close();
            truncate_file(file, size, size_in_blocks);

        } else {
            truncate_file(file, size, size_in_blocks);
        }
    }
}

fn truncate_file(file: []const u8, size: SizeValue, size_in_blocks: bool) void {
    var used_size = size.value;
    const stat = fileinfo.getLstat(file) catch {
        print("{s}: Error accessing file '{s}'. Exiting.\n", .{application_name, file});
        exit(1);
    };
    if (size_in_blocks) {
        used_size = @as(u64, @intCast(stat.blksize)) * size.value;
    }

    const opened_file = std.fs.cwd().openFile(file, .{.mode = .write_only}) catch unreachable;
    ftruncate(opened_file.handle, used_size) catch {
        print("{s}: Error truncating file '{s}'. Exiting.\n", .{application_name, file});
        exit(1);
    };
    opened_file.close();
}


fn parseSize(size_string: []const u8) SizeValue {
    if (size_string.len == 0) {
        print("{s}: Could not parse size. Exiting.\n", .{application_name});
        exit(1);
    }
    var start_index: usize = 0;
    var end_index: usize = 0;

    const modifiers: []const u8 = "+-<>/%";
    const size_types = [_]SizeType{.EXTEND, .REDUCE, .AT_MOST, .AT_LEAST, .ROUND_DOWN, .ROUND_UP};
    var used_size_type: SizeType = .EXACT;
    if (size_string[0] < '0' or size_string[0] > '9') {
        start_index = 1;
        const modifiers_index = std.mem.indexOf(u8, modifiers, size_string[0..1]);
        if (modifiers_index == null) {
            print("{s}: Could not parse size. Exiting.\n", .{application_name});
            exit(1);
        }
        used_size_type = size_types[modifiers_index.?];
    }

    if (size_string[start_index] < '0' or size_string[start_index] > '9') {
        print("{s}: Could not parse size. Exiting.\n", .{application_name});
        exit(1);
    }

    var i = start_index;
    while (i < size_string.len): (i += 1) {
        if (size_string[i] < '0' or size_string[i] > '9') {
            break;
        }
    }
    end_index = i;
    if (std.fmt.parseInt(u64, size_string[start_index..end_index], 10)) |value| {
        var used_value = value;
        if (end_index < size_string.len) {
            const multiplier = get_type(size_string[end_index..]) catch {
                print("{s}: Could not parse size. Exiting.\n", .{application_name});
                exit(1);
            };
            used_value = used_value * multiplier;
        }

        return SizeValue{
            .size_type = used_size_type,
            .value = used_value
        };
    } else |_|{
        print("{s}: Could not parse size. Exiting.\n", .{application_name});
        exit(1);
    }
}

fn get_type(postfix: []const u8) !u64 {
    const modifiers: []const u8 = "KMGTPE";
    const decimal = [_]u64{1_000, 1_000_000, 1_000_000_000, 1_000_000_000_000, 1_000_000_000_000_000, 1_000_000_000_000_000_000};
    const binary = [_]u64{1 << 10, 1 << 20, 1 << 30, 1 << 40, 1 << 50, 1 << 60};
    const unit_index = std.mem.indexOf(u8, modifiers, postfix[0..1]);
    if (unit_index == null) return error.InvalidType;
    if (postfix.len == 1) {
        return binary[unit_index.?];
    } else if (postfix.len == 2) {
        if (postfix[1] != 'B') return error.InvalidType;
        return decimal[unit_index.?];
    } else if (postfix.len == 3) {
        if (postfix[1] != 'i' or postfix[2] != 'B') return error.InvalidType;
        return binary[unit_index.?];
    } else {
        return error.InvalidType;
    }
}