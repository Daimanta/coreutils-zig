const std = @import("std");
const os = std.builtin.os.tag;

pub fn build(b: *std.build.Builder) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const mode = b.standardReleaseOptions();

    const basename = b.addExecutable("basename", "src/basename.zig");
    basename.setTarget(target);
    basename.setBuildMode(mode);
    basename.install();

    const dirname = b.addExecutable("dirname", "src/dirname.zig");
    dirname.setTarget(target);
    dirname.setBuildMode(mode);
    dirname.install();

    const echo = b.addExecutable("echo", "src/echo.zig");
    echo.setTarget(target);
    echo.setBuildMode(mode);
    echo.install();

    const false_app = b.addExecutable("false", "src/false.zig");
    false_app.setTarget(target);
    false_app.setBuildMode(mode);
    false_app.install();

    const groups = b.addExecutable("groups", "src/groups.zig");
    groups.setTarget(target);
    groups.setBuildMode(mode);
    groups.install();

    const hostid = b.addExecutable("hostid", "src/hostid.zig");
    hostid.setTarget(target);
    hostid.setBuildMode(mode);
    hostid.install();

    const hostname = b.addExecutable("hostname", "src/hostname.zig");
    hostname.setTarget(target);
    hostname.setBuildMode(mode);
    hostname.install();

    const link = b.addExecutable("link", "src/link.zig");
    link.setTarget(target);
    link.setBuildMode(mode);
    link.install();

    const logname = b.addExecutable("logname", "src/logname.zig");
    logname.setTarget(target);
    logname.setBuildMode(mode);
    logname.install();
    
    const mkdir = b.addExecutable("mkdir", "src/mkdir.zig");
    mkdir.setTarget(target);
    mkdir.setBuildMode(mode);
    mkdir.install();
    
    const mkfifo = b.addExecutable("mkfifo", "src/mkfifo.zig");
    mkfifo.setTarget(target);
    mkfifo.setBuildMode(mode);
    mkfifo.install();

    const nice = b.addExecutable("nice", "src/nice.zig");
    nice.setTarget(target);
    nice.setBuildMode(mode);
    nice.install();

    const nproc = b.addExecutable("nproc", "src/nproc.zig");
    nproc.setTarget(target);
    nproc.setBuildMode(mode);
    nproc.install();

    const printenv = b.addExecutable("printenv", "src/printenv.zig");
    printenv.setTarget(target);
    printenv.setBuildMode(mode);
    printenv.install();

    const pwd = b.addExecutable("pwd", "src/pwd.zig");
    pwd.setTarget(target);
    pwd.setBuildMode(mode);
    pwd.install();

    const readlink = b.addExecutable("readlink", "src/readlink.zig");
    readlink.setTarget(target);
    readlink.setBuildMode(mode);
    readlink.install();

    const sleep = b.addExecutable("sleep", "src/sleep.zig");
    sleep.setTarget(target);
    sleep.setBuildMode(mode);
    sleep.install();
    
    const sum = b.addExecutable("sum", "src/sum.zig");
    sum.setTarget(target);
    sum.setBuildMode(mode);
    sum.install();

    const true_app = b.addExecutable("true", "src/true.zig");
    true_app.setTarget(target);
    true_app.setBuildMode(mode);
    true_app.install();

    const tty = b.addExecutable("tty", "src/tty.zig");
    tty.setTarget(target);
    tty.setBuildMode(mode);
    tty.install();

    const unlink = b.addExecutable("unlink", "src/unlink.zig");
    unlink.setTarget(target);
    unlink.setBuildMode(mode);
    unlink.install();

    const uptime = b.addExecutable("uptime", "src/uptime.zig");
    uptime.setTarget(target);
    uptime.setBuildMode(mode);
    uptime.install();

    const users = b.addExecutable("users", "src/users.zig");
    users.setTarget(target);
    users.setBuildMode(mode);
    users.install();

    const whoami = b.addExecutable("whoami", "src/whoami.zig");
    whoami.setTarget(target);
    whoami.setBuildMode(mode);
    whoami.install();

    const yes = b.addExecutable("yes", "src/yes.zig");
    yes.setTarget(target);
    yes.setBuildMode(mode);
    yes.install();

    if (os == .linux) {
        groups.linkSystemLibrary("c");
        hostid.linkSystemLibrary("c");
        logname.linkSystemLibrary("c");
        mkfifo.linkSystemLibrary("c");
        nice.linkSystemLibrary("c");
        nproc.linkSystemLibrary("c");
        printenv.linkSystemLibrary("c");
        tty.linkSystemLibrary("c");
        uptime.linkSystemLibrary("c");
        whoami.linkSystemLibrary("c");
    }

}
