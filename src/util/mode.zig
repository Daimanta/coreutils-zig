// BSD 3-clause licensed. Copyright Léon van der Kaap 2021

const std = @import("std");
const linux = std.os.linux;
const testing = std.testing;

pub const mode_t = linux.mode_t;

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

pub const ChangeDerivation = enum {
    ABSOLUTE,
    RELATIVE
};

pub const UserType = enum {
    USER,
    GROUP,
    OTHER
};

pub const AbsoluteChange = struct {
    read: bool,
    write: bool,
    execute: bool,
    search: bool,
    set_gid: bool,
    sticky: bool,
};

pub const ChangeSource = union(ChangeDerivation) {
    ABSOLUTE: AbsoluteChange,
    RELATIVE: UserType
};

pub const ModeChange = struct {
    owner: bool,
    group: bool,
    other: bool,
    operation: Operation,
    source: ChangeSource
};

pub fn applyModeChange(change: *const ModeChange, mode: *mode_t) void {
    var used_source: AbsoluteChange = getAbsoluteChange(change, mode);
    
    if (change.owner) updateUserType(mode, UserType.USER, change.operation, used_source);
    if (change.group) updateUserType(mode, UserType.GROUP, change.operation, used_source);
    if (change.group) updateUserType(mode, UserType.OTHER, change.operation, used_source);
}

fn getAbsoluteChange(change: *const ModeChange, mode: *mode_t) AbsoluteChange {
    switch(change.source) {
        ChangeSource.ABSOLUTE => {
            return change.source.ABSOLUTE;
        },
        ChangeSource.RELATIVE => {
            switch (change.source.RELATIVE) {
                    UserType.USER => {
                        return AbsoluteChange{
                            .read = false,
                            .write = false,
                            .execute = false,
                            .search = false,
                            .set_gid = false,
                            .sticky = false,
                        };
                    },
                    UserType.GROUP => {
                        return AbsoluteChange{
                            .read = false,
                            .write = false,
                            .execute = false,
                            .search = false,
                            .set_gid = false,
                            .sticky = false,
                        };
                    },
                    UserType.OTHER => {
                        return AbsoluteChange{
                            .read = false,
                            .write = false,
                            .execute = false,
                            .search = false,
                            .set_gid = false,
                            .sticky = false,
                        };
                    }
            }
        },
    }
}

fn updateUserType(mode: *mode_t, user: UserType, operation: Operation, absolute_change: AbsoluteChange) void {
    switch (user) {
        UserType.USER => updateUser(mode, operation, absolute_change),
        UserType.GROUP => updateGroup(mode, operation, absolute_change),
        UserType.OTHER => updateOther(mode, operation, absolute_change),
    }
}

fn updateUser(mode: *mode_t, operation: Operation, absolute_change: AbsoluteChange) void {
    switch (operation) {
        Operation.SET => {
            if (absolute_change.read) mode.* |= RUSR else mode.* &= ~RUSR;
            if (absolute_change.write) mode.* |= WUSR else mode.* &= ~WUSR;
            if (absolute_change.execute) mode.* |= XUSR else mode.* &= ~XUSR;
        },
        Operation.ADD => {
            if (absolute_change.read) mode.* |= RUSR;
            if (absolute_change.write) mode.* |= WUSR;
            if (absolute_change.execute) mode.* |= XUSR;
        },
        Operation.REMOVE => {
            if (absolute_change.read) mode.* &= ~RUSR;
            if (absolute_change.write) mode.* &= ~WUSR;
            if (absolute_change.execute) mode.* &= ~XUSR;
        }
    }
}

fn updateGroup(mode: *mode_t, operation: Operation, absolute_change: AbsoluteChange) void {
    switch (operation) {
        Operation.SET => {
            if (absolute_change.read) mode.* |= RGRP else mode.* &= ~RGRP;
            if (absolute_change.write) mode.* |= WGRP else mode.* &= ~WGRP;
            if (absolute_change.execute) mode.* |= XGRP else mode.* &= ~XGRP;        
        },
        Operation.ADD => {
            if (absolute_change.read) mode.* |= RGRP;
            if (absolute_change.write) mode.* |= WGRP;
            if (absolute_change.execute) mode.* |= XGRP;            
        },
        Operation.REMOVE => {
            if (absolute_change.read) mode.* &= ~RGRP;
            if (absolute_change.write) mode.* &= ~WGRP;
            if (absolute_change.execute) mode.* &= ~XGRP;            
        }
    }
}

fn updateOther(mode: *mode_t, operation: Operation, absolute_change: AbsoluteChange) void {
    switch (operation) {
        Operation.SET => {
            if (absolute_change.read) mode.* |= ROTH else mode.* &= ~ROTH;
            if (absolute_change.write) mode.* |= WOTH else mode.* &= ~WOTH;
            if (absolute_change.execute) mode.* |= XOTH else mode.* &= ~XOTH;        
        },
        Operation.ADD => {
            if (absolute_change.read) mode.* |= ROTH;
            if (absolute_change.write) mode.* |= WOTH;
            if (absolute_change.execute) mode.* |= XOTH;            
        },
        Operation.REMOVE => {
            if (absolute_change.read) mode.* &= ~ROTH;
            if (absolute_change.write) mode.* &= ~WOTH;
            if (absolute_change.execute) mode.* &= ~XOTH;            
        }
    }
}

pub fn getModeFromString (string:[]const u8) !mode_t {
    //TODO: Implement the conversion process
    return RUSR | WUSR | XUSR | RGRP | XGRP | ROTH | XOTH;
}

test "set zero" {
    var mode: mode_t = 0;
    const mode_change: ModeChange = ModeChange {
        .owner = true,
        .group = true,
        .other = true,
        .operation = Operation.SET,
        .source = ChangeSource {
            .ABSOLUTE = AbsoluteChange {
                .read = false,
                .write = false,
                .execute = false,
                .search = false,
                .set_gid = false,
                .sticky = false,
            }
        }
    };
    applyModeChange(&mode_change, &mode);
    
    const expected: mode_t = 0;
    try testing.expectEqual(expected, mode);
}
