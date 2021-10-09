// BSD 3-clause licensed. Copyright Léon van der Kaap 2021

const std = @import("std");
const linux = std.os.linux;

const set_hostname_syscall = linux.SYS.sethostname;
const Allocator = std.mem.Allocator;

const allocator = std.heap.page_allocator;

pub const MINIMAL_NICENESS = 20;
pub const MAXIMAL_NICENESS = -19;

pub const SetHostnameError = error {
    InvalidAddress,
    NegativeLength,
    AccessDenied
};

pub const SetPriorityError = error {
    NoRightsForNiceValue,
    InvalidProcessTarget,
    ProcessUserMismatch,
    ProcessNotFound,
    UnknownError
};

pub const PriorityType = enum(u8) {
    PRIO_PROCESS = 0,
    PRIO_PGRP = 1,
    PRIO_USER = 2
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

pub const id_t = u32;
extern fn setpriority(which: c_int, who: id_t, prio: c_int) c_int;

pub fn setPriority(which: PriorityType, who: id_t, prio: c_int) SetPriorityError!void {
    const result = setpriority(@enumToInt(which), who, prio);
    if (result != 0) {
        return switch (result * -1) {
            1 => SetPriorityError.NoRightsForNiceValue,
            else => SetPriorityError.UnknownError
        };
    }
    return;
}