const std = @import("std");
const os = @import("builtin").os.tag;

pub fn build(b: *std.build.Builder) void {
    const current_zig_version = @import("builtin").zig_version;
    if (current_zig_version.major != 0 or current_zig_version.minor < 9) {
        std.debug.print("This project does not compile with a Zig version <0.9.x. Exiting.", .{});
        std.os.exit(1);
    }

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
    
    const chgrp = b.addExecutable("chgrp", "src/chgrp.zig");
    chgrp.setTarget(target);
    chgrp.setBuildMode(mode);
    chgrp.install();
    
    const chmod = b.addExecutable("chmod", "src/chmod.zig");
    chmod.setTarget(target);
    chmod.setBuildMode(mode);
    chmod.install();
    
    const chown = b.addExecutable("chown", "src/chown.zig");
    chown.setTarget(target);
    chown.setBuildMode(mode);
    chown.install();
    
    const cksum = b.addExecutable("cksum", "src/cksum.zig");
    cksum.setTarget(target);
    cksum.setBuildMode(mode);
    cksum.install();
    
    const dircolors = b.addExecutable("dircolors", "src/dircolors.zig");
    dircolors.setTarget(target);
    dircolors.setBuildMode(mode);
    dircolors.install();
    
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
    
    const fold = b.addExecutable("fold", "src/fold.zig");
    fold.setTarget(target);
    fold.setBuildMode(mode);
    fold.install();

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
    
    const id = b.addExecutable("id", "src/id.zig");
    id.setTarget(target);
    id.setBuildMode(mode);
    id.install();

    const link = b.addExecutable("link", "src/link.zig");
    link.setTarget(target);
    link.setBuildMode(mode);
    link.install();

    const logname = b.addExecutable("logname", "src/logname.zig");
    logname.setTarget(target);
    logname.setBuildMode(mode);
    logname.install();
    
    const md5sum = b.addExecutable("md5sum", "src/md5sum.zig");
    md5sum.setTarget(target);
    md5sum.setBuildMode(mode);
    md5sum.install();
    
    const mkdir = b.addExecutable("mkdir", "src/mkdir.zig");
    mkdir.setTarget(target);
    mkdir.setBuildMode(mode);
    mkdir.addPackagePath("libselinux", "/lib/x86_64-linux-gnu/libselinux.so.1");
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
    
    const realpath = b.addExecutable("realpath", "src/realpath.zig");
    realpath.setTarget(target);
    realpath.setBuildMode(mode);
    realpath.install();
    
    const rmdir = b.addExecutable("rmdir", "src/rmdir.zig");
    rmdir.setTarget(target);
    rmdir.setBuildMode(mode);
    rmdir.install();

    const sleep = b.addExecutable("sleep", "src/sleep.zig");
    sleep.setTarget(target);
    sleep.setBuildMode(mode);
    sleep.install();
    
    const sum = b.addExecutable("sum", "src/sum.zig");
    sum.setTarget(target);
    sum.setBuildMode(mode);
    sum.install();
    
    const sync = b.addExecutable("sync", "src/sync.zig");
    sync.setTarget(target);
    sync.setBuildMode(mode);
    sync.install();

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
    
    const uname = b.addExecutable("uname", "src/uname.zig");
    uname.setTarget(target);
    uname.setBuildMode(mode);
    uname.install();

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
        chgrp.linkSystemLibrary("c");
        chmod.linkSystemLibrary("c");
        chown.linkSystemLibrary("c");
        groups.linkSystemLibrary("c");
        hostid.linkSystemLibrary("c");
        id.linkSystemLibrary("c");
        logname.linkSystemLibrary("c");
        mkdir.linkSystemLibrary("c");
        mkfifo.linkSystemLibrary("c");
        nice.linkSystemLibrary("c");
        nproc.linkSystemLibrary("c");
        printenv.linkSystemLibrary("c");
        tty.linkSystemLibrary("c");
        uptime.linkSystemLibrary("c");
        whoami.linkSystemLibrary("c");
    }

}
