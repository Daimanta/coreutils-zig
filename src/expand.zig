const std = @import("std");
const fs = std.fs;
const os = std.os;
const io = std.io;
const testing = std.testing;

const clap2 = @import("clap2/clap2.zig");
const version = @import("util/version.zig");
const fileinfo = @import("util/fileinfo.zig");

const Allocator = std.mem.Allocator;

const exit = std.posix.exit;
const default_allocator = std.heap.page_allocator;
const print = @import("util/print_tools.zig").print;
const StringBuilder = @import("util/strings.zig").StringBuilder;

const application_name = "expand";

const help_message =
\\Usage: expand [OPTION]... [FILE]...
\\Convert tabs in each FILE to spaces, writing to standard output.
\\
\\With no FILE, or when FILE is -, read standard input.
\\
\\Mandatory arguments to long options are mandatory for short options too.
\\  -i, --initial    do not convert tabs after non blanks
\\  -t, --tabs=N     have tabs N characters apart, not 8
\\  -t, --tabs=LIST  use comma separated list of tab positions
\\                     The last specified position can be prefixed with '/'
\\                     to specify a tab size to use after the last
\\                     explicitly specified tab stop.  Also a prefix of '+'
\\                     can be used to align remaining tab stops relative to
\\                     the last specified tab stop instead of the first column
\\      --help     display this help and exit
\\      --version  output version information and exit
\\
;

const default_tab_size = 8;

pub fn main() !void {
    const args: []const clap2.Argument = &[_]clap2.Argument{
        clap2.Argument.FlagArgument(null, &[_][]const u8{"help"}),
        clap2.Argument.FlagArgument(null, &[_][]const u8{"version"}),
        clap2.Argument.FlagArgument("i", &[_][]const u8{"initial"}),
        clap2.Argument.OptionArgument("t", &[_][]const u8{"tabs"}, false),
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
    if (arguments.len == 0) {
        print("{s}: At least one file must be specified. Exiting.\n",.{application_name});
    }

    const initial = parser.flag("i");
    const tabs = parser.option("t");

    var tab_size: ?u32 = null;
    var tab_list: ?[]u32 = null;
    var post_tab_size: ?u32 = null;
    var post_tab_alignment: ?u32 = null;
    tab_list = tab_list; post_tab_size = post_tab_size; post_tab_alignment = post_tab_alignment;

    if (tabs.found) {
        const int_opt = std.fmt.parseInt(i31, tabs.value.?, 10);
        if (int_opt) |int| {
            if (int <= 0) {
                print("Tab size must be positive\n", .{});
                exit(1);
            }
            tab_size = @intCast(int);
        } else |_| {
            var splitIterator = std.mem.splitScalar(u8, tabs.value.?,',');
            var array_list = std.array_list.Managed([]const u8).init(default_allocator);
            defer array_list.clearAndFree();
            var next = splitIterator.next();
            while (next != null) {
                array_list.append(next.?) catch {
                    print("OOM error!\n", .{});
                    exit(1);
                };
                next = splitIterator.next();
            }
            const last = array_list.items[array_list.items.len - 1];
            var number_index = array_list.items.len;

            if (std.mem.startsWith(u8, last, "/")) {
                if (last.len <= 1) {
                    print("Tab list element must be a number\n", .{});
                    exit(1);
                }

                const value = std.fmt.parseInt(i31, last[1..], 10) catch {
                    print("Tab list element must be a number\n", .{});
                    exit(1);
                };
                post_tab_size = @intCast(value);
                number_index -= 1;
            } else if (std.mem.startsWith(u8, last, "/")) {
                if (last.len <= 1) {
                    print("Tab list element must be a number\n", .{});
                    exit(1);
                }
                const value = std.fmt.parseInt(i31, last[1..], 10) catch {
                    print("Tab list element must be a number\n", .{});
                    exit(1);
                };
                post_tab_alignment = @intCast(value);
                number_index -= 1;
            }
            
            tab_list = default_allocator.alloc(u32, number_index) catch {
                print("OOM error!\n", .{});
                exit(1);
            };
            for (0..number_index) |number| {
                const value = std.fmt.parseInt(i31, array_list.items[number], 10) catch {
                    print("Tab list element must be a number\n", .{});
                    exit(1);
                };
                tab_list.?[number] = @intCast(value);
            }
        }

    } else {
        tab_size = default_tab_size;
    }

    for (arguments) |path| {
        expand(path, initial, tab_size, tab_list, post_tab_size, post_tab_alignment);
    }
}

fn expand(path: []const u8, initial_only: bool, tab_size_opt: ?u32, tab_list_opt: ?[]u32, post_tab_size: ?u32, post_tab_alignment: ?u32) void {
    const stat = fileinfo.getLstat(path) catch {
        print("{s}: Could not access file '{s}'\n", .{application_name, path});
        exit(1);
    };
    if (!fileinfo.fileExists(stat)) {
        print("{s}: File '{s}' does not exist\n", .{ application_name, path });
        exit(1);
    }

    if (fileinfo.isDir(stat)) {
        print("{s}: '{s}' is a directory.\n", .{ application_name, path });
        exit(1);
    }

    const file = fs.cwd().openFile(path, .{ .mode = .read_only }) catch {
        print("{s}: Could not read file '{s}'.\n", .{application_name, path});
        exit(1);
    };
    defer file.close();

    while (true) {
        const lineOpt = file.deprecatedReader().readUntilDelimiterOrEofAlloc(default_allocator, '\n', 1 << 24) catch {
            print("{s}: Error while reading file '{s}'\n", .{application_name, path});
            exit(1);
        };
        if (lineOpt == null) break;
        defer default_allocator.free(lineOpt.?);
        const line = lineOpt.?;

        const number_of_tabs = std.mem.count(u8, line, "\t");
        if (tab_size_opt != null) {
            print_line_with_tabsize(path, line, tab_size_opt.?, number_of_tabs, initial_only);
        } else {
            print_line_with_tabstops(path, line, number_of_tabs, initial_only, tab_list_opt.?, post_tab_size, post_tab_alignment);
        }
    }
}

fn print_line_with_tabsize(path: []const u8, line: []u8, tab_size: u32, number_of_tabs: usize, initial_only: bool) void {
    const buffer: []u8 = default_allocator.alloc(u8, line.len + tab_size * number_of_tabs) catch {
        print("{s}: OOM while reading file '{s}'\n", .{application_name, path});
        exit(1);
    };
    defer default_allocator.free(buffer);

    var stringBuilder = StringBuilder.init(buffer);
    if (initial_only) {
        var convert = true;
        var i: usize = 0;
        while (i < line.len): (i += 1) {
            if (convert) {
                if (line[i] == ' ') {
                    //whitespace, keep converting
                            stringBuilder.appendChar(line[i]);
                } else if (line [i] == '\t') {
                    for (0..tab_size) |_| {
                        stringBuilder.appendChar(' ');
                    }
                } else {
                    convert = false;
                    stringBuilder.appendChar(line[i]);
                }
            } else {
                stringBuilder.appendChar(line[i]);
            }
        }
    } else {
        for (line) |char| {
            if (char == '\t') {
                for (0..tab_size) |_| {
                    stringBuilder.appendChar(' ');
                }
            } else {
                stringBuilder.appendChar(char);
            }
        }
    }
    print("{s}\n", .{stringBuilder.toSlice()});
}

fn print_line_with_tabstops(path: []const u8, line: []u8, number_of_tabs: usize, initial_only: bool, tab_list: []u32, post_tab_size: ?u32, post_tab_alignment: ?u32) void {
    var used_tab_size = tab_list[0];
    if (post_tab_size != null) {
        used_tab_size = post_tab_size.?;
    } else if (post_tab_alignment != null) {
        used_tab_size = post_tab_alignment.?;
    }
    const last_tab_position = tab_list[tab_list.len - 1];
    const first_tab_position = tab_list[0];

    const max_tab_size = @max(used_tab_size, tab_list[tab_list.len - 1]);
    const buffer: []u8 = default_allocator.alloc(u8, line.len + max_tab_size * number_of_tabs) catch {
        print("{s}: OOM while reading file '{s}'\n", .{application_name, path});
        exit(1);
    };
    defer default_allocator.free(buffer);
    var stringBuilder = StringBuilder.init(buffer);
    var current_tabstop: usize = 0;

    var convert = true;
    var i: usize = 0;
    while (i < line.len): (i += 1) {
        if (convert) {
            if (line[i] == ' ') {
                //whitespace, keep converting
                        stringBuilder.appendChar(line[i]);
            } else if (line [i] == '\t') {
                const consider_tab_stop = tab_list[tab_list.len - 1] > stringBuilder.insertion_index;
                if (consider_tab_stop) {
                    while (current_tabstop < tab_list.len) {
                        if (tab_list[current_tabstop] < stringBuilder.insertion_index) {
                            current_tabstop += 1;
                        } else {
                            break;
                        }
                    }
                }
                if (consider_tab_stop and current_tabstop < tab_list.len) {
                    const diff = tab_list[current_tabstop] - stringBuilder.insertion_index + 1;
                    for (0..diff) |_| {
                        stringBuilder.appendChar(' ');
                    }
                } else {
                    if (post_tab_size != null) {
                        for (0..post_tab_size.?) |_| {
                            stringBuilder.appendChar(' ');
                        }
                    } else if (post_tab_alignment != null) {
                        const diff = stringBuilder.insertion_index - last_tab_position;
                        const insert = first_tab_position - @mod(diff, first_tab_position);
                        for (0..insert) |_| {
                            stringBuilder.appendChar(' ');
                        }
                    } else {
                        for (0..first_tab_position) |_| {
                            stringBuilder.appendChar(' ');
                        }
                    }
                }
            } else {
                if (initial_only) {
                    convert = false;
                }
                stringBuilder.appendChar(line[i]);
            }
        } else {
            stringBuilder.appendChar(line[i]);
        }
    }
    print("{s}\n", .{stringBuilder.toSlice()});
}
