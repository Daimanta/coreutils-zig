const std = @import("std");
const linux = std.os.linux;

const mode_t = linux.mode_t;

pub const SUID: u12 = 0o4000; // set user id
pub const SGID: u12 = 0o2000; // set group id
pub const SVTX: u12 = 0o1000; // sticky, t
pub const RUSR: u12 = 0o0400;
pub const WUSR: u12 = 0o0200;
pub const XUSR: u12 = 0o0100;
pub const RGRP: u12 = 0o0040;
pub const WGRP: u12 = 0o0020;
pub const XGRP: u12 = 0o0010;
pub const ROTH: u12 = 0o0004;
pub const WOTH: u12 = 0o0002;
pub const XOTH: u12 = 0o0001;


pub const Operation = enum {
    ADD,
    REMOVE,
    SET
};

pub const ModeChange = struct {
    owner: bool,
    group: bool,
    other: bool,
    operation: Operation,
    owner
    read: bool,
    write: bool,
    execute: bool,
    search: bool,
    set_id: bool,
    sticky: bool
};

fn applyModeChange(change: *const ModeChange, mode: *mode_t) void {
    if (change.operation == Operation.SET) {

    } else if (change.operation == Operation.ADD) {

    } else if (change.operation == Operation.REMOVE) {

    } else {
        unreachable;
    }
}

