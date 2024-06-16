const version_details = @import("./src/util/version_number.zig");

pub const major: u32 = version_details.major;
pub const minor: u32 = version_details.minor;
pub const patch: u32 = version_details.patch;
