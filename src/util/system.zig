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
    const result = linux.syscall2(set_hostname_syscall, @intFromPtr(&name[0]), name.len);
    if (result != 0) {
        const errno = std.posix.errno(result);
        return switch (errno) {
            .PERM => SetHostnameError.AccessDenied,
            .FAULT => SetHostnameError.InvalidAddress,
            .INVAL => SetHostnameError.NegativeLength,
            else => unreachable
        };
    }
    return;
}

pub const id_t = u32;
extern fn setpriority(which: c_int, who: id_t, prio: c_int) c_int;

pub fn setPriority(which: PriorityType, who: id_t, prio: c_int) SetPriorityError!void {
    const result = setpriority(@intFromEnum(which), who, prio);
    if (result != 0) {
        return switch (std.posix.errno(result)) {
            .SRCH, .INVAL => SetPriorityError.ProcessNotFound,
            .PERM => SetPriorityError.ProcessUserMismatch,
            .ACCES => SetPriorityError.NoRightsForNiceValue,
            else => SetPriorityError.UnknownError
        };
    }
    return;
}

pub fn getErrnoValue(input: usize) std.posix.E {
    const signed: isize = @bitCast(input);
    return @enumFromInt(signed * -1);
}