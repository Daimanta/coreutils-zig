// BSD 3-clause licensed. Copyright Léon van der Kaap 2021

const std = @import("std");
const linux = std.os.linux;
const pid_t = linux.pid_t;

const UtType = enum(u16) {
    EMPTY,
    RUN_LVL,
    BOOT_TIME,
    NEW_TIME,
    OLD_TIME,
    INIT_PROCESS,
    LOGIN_PROCESS,
    USER_PROCESS,
    DEAD_PROCESS,
    ACCOUNTING
};

const ExitStatus = extern struct {
    e_termination: u16,
    e_exit: u16
};

const TimeEntry = extern struct {
    tv_sec: i32,
    tv_usec: i32
};

const UT_SUFFIXSIZE = 4;
const UT_LINESIZE = 32;
const UT_NAMESIZE = 32;
const UT_HOSTSIZE = 256;

pub const Utmp = extern struct {
    ut_type: UtType,
    ut_pid: pid_t,
    ut_line: [UT_LINESIZE]u8,
    ut_id: [UT_SUFFIXSIZE]u8,
    ut_user: [UT_NAMESIZE]u8,
    ut_host: [UT_HOSTSIZE]u8,
    ut_exit: ExitStatus,
    // TODO: This only works on 64-bit machines with 32-bit compat
    // Implement alternative option as well
    ut_session: i32,
    ut_tv: TimeEntry,
    ut_addr_v6: [4]i32,
    __unused: [20]u8
};

pub fn convertBytesToUtmpRecords(bytes: []u8) []Utmp{
    return std.mem.bytesAsSlice(Utmp, bytes);
}