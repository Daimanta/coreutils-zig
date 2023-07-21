// BSD 3-clause licensed. Copyright Léon van der Kaap 2021

const std = @import("std");
const linking = @import("linking.zig");

const print = @import("util/print_tools.zig").print;
const OpenMode = linking.OpenMode;

pub var selinux_lib: ?*c_void = null;
pub var selinux_present: ?bool = null;

pub const selinux_opt = extern struct {
    type: c_int,
    value: [*:0]u8
};

pub fn initSelinux() void {
    if (selinux_present != null) return;
    selinux_lib = linking.openDynamicLibrary("/lib/x86_64-linux-gnu/libselinux.so.1", OpenMode.RTLD_LAZY) catch null;
    selinux_present = selinux_lib != null;
}

pub fn selinuxActive() bool {
    if (selinux_present == null) initSelinux();
    if (!selinux_present.?) return false;
    const func_pointer = linking.linkDynamicLibrarySymbol(selinux_lib.?, "is_selinux_enabled") catch |err| {
        return false;
    };
    const func = @ptrCast(fn()c_int, func_pointer);
    return func() == 1;
}

pub fn selinuxOpen(backend: i32, options: ?[]selinux_opt) !void {
    initSelinux();
    if (selinux_present == false) {
        return error.SelinuxNotPresent;
    }
        
    const func_pointer = try linking.linkDynamicLibrarySymbol(selinux_lib.?, "selabel_open");
    const func = @ptrCast(fn(c_int, ?[*]selinux_opt, c_uint)*c_void, func_pointer);
    const length = if (options != null) options.?.len else 0;
    const pointer = if (options != null) options.?.ptr else null;
    const result = func(@as(c_int, backend), pointer, @intCast(c_uint, length));   
}
