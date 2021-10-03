// BSD 3-clause licensed. Copyright Léon van der Kaap 2021

const std = @import("std");
const linux = std.os.linux;

const set_hostname_syscall = linux.SYS.sethostname;
const Allocator = std.mem.Allocator;

const allocator = std.heap.page_allocator;

pub const SetHostnameError = error {
    InvalidAddress,
    NegativeLength,
    AccessDenied
};


pub fn setHostname(name: []const u8) SetHostnameError!void {
    const result = linux.syscall2(set_hostname_syscall, @ptrToInt(&name[0]), name.len);
    if (result != 0) {
        const errno = linux.getErrno(result);
        return switch (errno) {
            linux.EPERM => SetHostnameError.AccessDenied,
            linux.EFAULT => SetHostnameError.InvalidAddress,
            linux.EINVAL => SetHostnameError.NegativeLength,
            else => unreachable
        };
    }
    return;
}