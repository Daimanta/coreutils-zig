const std = @import("std");
const fs = std.fs;
const os = std.os;
const io = std.io;

const clap = @import("clap.zig");
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
    const params = comptime [_]clap.Param(clap.Help){
        clap.parseParam("--help") catch unreachable,
        clap.parseParam("--version") catch unreachable,
        clap.parseParam("-a, --all") catch unreachable,
        clap.parseParam("-s, --kernel-name") catch unreachable,
        clap.parseParam("-n, --nodename") catch unreachable,
        clap.parseParam("-r, --kernel-release") catch unreachable,
        clap.parseParam("-v, --kernel-version") catch unreachable,
        clap.parseParam("-m, --machine") catch unreachable,
        clap.parseParam("-p, --processor") catch unreachable,
        clap.parseParam("-i, --hardware-platform") catch unreachable,
        clap.parseParam("-o, --operating-system") catch unreachable,
        clap.parseParam("<STRING>") catch unreachable,
    };

    var diag = clap.Diagnostic{};
    var args = clap.parseAndHandleErrors(clap.Help, &params, .{ .diagnostic = &diag }, application_name, 1);
    defer args.deinit();
    
    const kernel_name = args.flag("-s") or args.flag("-a");
    const node_name = args.flag("-n") or args.flag("-a");
    const kernel_release = args.flag("-r") or args.flag("-a");
    const kernel_version = args.flag("-v") or args.flag("-a");
    const machine = args.flag("-m") or args.flag("-a");
    const processor = args.flag("-p") or args.flag("-a");
    const hardware_platform = args.flag("-i") or args.flag("-a");
    const operating_system = args.flag("-o") or args.flag("-a");
        
    if (args.flag("--help")) {
        print(help_message, .{});
        std.posix.exit(0);
    } else if (args.flag("--version")) {
        version.printVersionInfo(application_name);
        std.posix.exit(0);
    }
    
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
