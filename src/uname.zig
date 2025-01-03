const std = @import("std");
const fs = std.fs;
const os = std.os;
const io = std.io;

const clap2 = @import("clap2/clap2.zig");
const system = @import("util/system.zig");
const version = @import("util/version.zig");

const Allocator = std.mem.Allocator;
const SetHostnameError = system.SetHostnameError;

const default_allocator = std.heap.page_allocator;
const HOST_NAME_MAX = os.linux.HOST_NAME_MAX;
const print = @import("util/print_tools.zig").print;

const application_name = "uname";

const help_message =
\\Usage: uname [OPTION]...
\\Print certain system information.  With no OPTION, same as -s.
\\
\\  -a, --all                print all information, in the following order,
\\                             except omit -p and -i if unknown:
\\  -s, --kernel-name        print the kernel name
\\  -n, --nodename           print the network node hostname
\\  -r, --kernel-release     print the kernel release
\\  -v, --kernel-version     print the kernel version
\\  -m, --machine            print the machine hardware name
\\  -p, --processor          print the processor type (non-portable)
\\  -i, --hardware-platform  print the hardware platform (non-portable)
\\  -o, --operating-system   print the operating system
\\      --help     display this help and exit
\\      --version  output version information and exit
\\
;


pub fn main() !void {
    const args: []const clap2.Argument = &[_]clap2.Argument{
        clap2.Argument.FlagArgument(null, &[_][]const u8{"help"}),
        clap2.Argument.FlagArgument(null, &[_][]const u8{"version"}),
        clap2.Argument.FlagArgument("a", &[_][]const u8{"all"}),
        clap2.Argument.FlagArgument("s", &[_][]const u8{"kernel-name"}),
        clap2.Argument.FlagArgument("n", &[_][]const u8{"node-name"}),
        clap2.Argument.FlagArgument("r", &[_][]const u8{"kernel-release"}),
        clap2.Argument.FlagArgument("v", &[_][]const u8{"kernel-version"}),
        clap2.Argument.FlagArgument("m", &[_][]const u8{"machine"}),
        clap2.Argument.FlagArgument("p", &[_][]const u8{"processor"}),
        clap2.Argument.FlagArgument("i", &[_][]const u8{"hardware-platform"}),
        clap2.Argument.FlagArgument("o", &[_][]const u8{"operating-system"}),
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

    const all = parser.flag("a");
    const kernel_name = all or parser.flag("s");
    const node_name = all or parser.flag("n");
    const kernel_release = all or parser.flag("r");
    const kernel_version = all or parser.flag("v");
    const machine = all or parser.flag("m");
    const processor = all or parser.flag("p");
    const hardware_platform = all or parser.flag("i");
    const operating_system = all or parser.flag("o");

    
    const uname_info = std.posix.uname();
    if (kernel_name) print("{s} ", .{uname_info.sysname});
    if (node_name) print("{s} ", .{uname_info.nodename});
    if (kernel_release) print("{s} ", .{uname_info.release});
    if (kernel_version) print("{s} ", .{uname_info.version});
    if (machine) print("{s} ", .{uname_info.machine});
    if (processor) printProcessor(uname_info);
    if (hardware_platform) print("{s} ", .{uname_info.machine});
    if (operating_system) print("{s}", .{"GNU/Linux"});
    
    if (!kernel_name and !node_name and !kernel_release and !kernel_version and !machine and !operating_system and !hardware_platform and !processor) {
        print("{s}", .{uname_info.sysname});
    }
    print("\n", .{});

}

fn printProcessor(uname_info: std.posix.utsname) void {
    const file_contents = fs.cwd().readFileAlloc(default_allocator, "/proc/cpuinfo", 1 << 20) catch {
        print("{s} ", .{uname_info.machine});
        return;
    };
    defer default_allocator.free(file_contents);
    var lines = std.mem.tokenize(u8, file_contents, "\n"[0..]);
    while (lines.next()) |line| {
        if (std.mem.startsWith(u8, line, "model name")) {
            const separator = std.mem.indexOf(u8, line, ":");
            if (separator != null) {
                print("{s} ", .{line[separator.?+2..]});
            } else {
                print("{s} ", .{uname_info.machine});
            }
            return;
        }
    }
    print("{s} ", .{uname_info.machine});
}
