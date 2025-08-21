const std = @import("std");

pub const ValueType = enum {
    none,
    one,
    many,
};

pub const Argument = struct {
    shorts: ?[]const u8 = null,
    longs: ?[]const []const u8 = null,
    type: ValueType = .none,
    allow_none: bool = false,

    pub fn FlagArgument(shorts: ?[]const u8, longs: ?[]const []const u8) Argument {
        return Argument{
            .shorts = shorts,
            .longs = longs,
            .type = .none,
            .allow_none = false
        };
    }

    pub fn OptionArgument(shorts: ?[]const u8, longs: ?[]const []const u8, allow_none: bool) Argument {
        return Argument{
            .shorts = shorts,
            .longs = longs,
            .type = .one,
            .allow_none = allow_none
        };
    }
};

pub const ArgValue = struct {
    matched: bool = false,
    singleValue: ?[]const u8 = null,
    multiValue: ?[][]const u8 = null
};

pub const ValuePair = struct {
    argument: Argument,
    value: ArgValue
};

pub const OptionValue = struct {
    found: bool = false,
    hasArgument: bool = false,
    value: ?[]const u8 = null
};

pub const ParserOptions = struct {
    accept_numerical_arguments: bool = true
};

pub const Parser = struct {
    allocator: std.heap.ArenaAllocator,
    pairs: []ValuePair,
    _positionals: [][]const u8,
    parser_options: ParserOptions,

    const Self = @This();
    pub fn init(arguments: []const Argument, parser_options: ParserOptions) Self{
        var result = Self{.allocator = std.heap.ArenaAllocator.init(std.heap.page_allocator), .pairs = undefined, ._positionals = undefined, .parser_options = parser_options};
        result.pairs = result.allocator.allocator().alloc(ValuePair, arguments.len) catch {
            std.debug.print("Error!'\n", .{});
            std.posix.exit(1);
        };
        for (0..arguments.len) |i| {
            result.pairs[i] = .{.argument = arguments[i], .value = .{}};
        }
        construct_values(&result) catch {
            std.debug.print("Error!'\n", .{});
            std.posix.exit(1);
        };
        return result;
    }

    pub fn flag(self: *const Self, reference: []const u8) bool {
        const matched = self.match(reference);
        if (matched != null) {
            if (matched.?.argument.type != .none) {
                std.debug.print("{s}: 'flag' can only be called on an argument without parameters.\n", .{reference});
                std.posix.exit(1);
            }
            return matched.?.value.matched;
        } else {
            std.debug.print("{s}: Argument not found!\n", .{reference});
            std.posix.exit(1);
        }
        return false;
    }

    pub fn option(self: *Self, reference: []const u8) OptionValue {
        const foundArgument = self.match(reference);
        var result = OptionValue{
            .found = false,
            .hasArgument = false,
            .value = null
        };
        if (foundArgument != null) {
            if (foundArgument.?.argument.type != .one) {
                std.debug.print("{s}: 'option' can only be called on an argument with a single parameter.\n", .{reference});
                std.posix.exit(1);
            }

            const singleValue = foundArgument.?.value.singleValue;
            result.value = singleValue;
            result.found = foundArgument.?.value.matched;
            if (result.found) {
                if (singleValue != null) {
                    result.hasArgument = true;
                }
            }

            return result;
        } else {
            std.debug.print("{s}: Argument not found!\n", .{reference});
            std.posix.exit(1);
        }
        return result;
    }

    pub fn options(self: *const Self, reference: []const u8) ?[][]const u8 {
        const matched = self.match(reference);
        if (matched != null) {
            if (matched.?.argument.type != .many) {
                std.debug.print("{s}: 'option' can only be called on an argument with multiple parameters.\n", .{reference});
                std.posix.exit(1);
            }
            return matched.?.value.multiValue;
        }
        return null;
    }

    pub fn positionals(self: *const Self) [][]const u8{
        return self._positionals;
    }

    fn match(self: *const Self, reference: []const u8) ?*ValuePair {
        if (reference.len == 0) {
            std.debug.print("Error!'\n", .{});
            std.posix.exit(1);
        } else {
            for (self.pairs) |*pair| {
                var matched = reference.len == 1 and pair.argument.shorts != null and std.mem.indexOfScalar(u8, pair.argument.shorts.?, reference[0]) != null;
                if (!matched and reference.len > 1 and pair.argument.longs != null) {
                    for (pair.argument.longs.?) |str| {
                        if (std.mem.eql(u8, str, reference)) {
                            matched = true;
                            break;
                        }
                    }
                }
                if (matched) {
                    return pair;
                }
            }
            std.debug.print("{s}: Argument not found!\n", .{reference});
            std.posix.exit(1);
        }
    }

    pub fn deinit(self: *Self) void {
        self.allocator.deinit();
    }

    fn construct_values(self: *Self) !void {
        const arguments_null_term: [][:0]u8 = try std.process.argsAlloc(self.allocator.allocator());
        var arguments = try self.allocator.allocator().alloc([]const u8, arguments_null_term.len);
        for (arguments_null_term, 0..) |arg_prim, i| {
            arguments[i] = arg_prim;
        }

        if (arguments.len == 1) {
            self._positionals = try self.allocator.allocator().alloc([]const u8, 0);
            return;
        }

        var positionalsArrayList = std.array_list.Managed([]const u8).init(std.heap.page_allocator);
        defer positionalsArrayList.deinit();

        var i: usize = 1;
        while (i < arguments.len): (i += 1) {
            const arg = arguments[i];
            if (std.mem.startsWith(u8, arg, "--")) {
                if (arg.len == 2) {
                    std.debug.print("Empty argument '--' found.\n", .{});
                    std.posix.exit(1);
                }
                const matched = self.match(arg[2..]);
                if (matched == null) {
                    std.debug.print("Unrecognized flag '{s}'\n", .{arg});
                    std.posix.exit(1);
                } else {
                    try self.handleMatch(matched.?, arguments, &i, true);
                }
            } else if (std.mem.startsWith(u8, arg, "-") and arg.len > 1 and (self.parser_options.accept_numerical_arguments or !arguments_are_numeric(arg))) {
                if (arg.len > 2) {
                    var j: usize = 1;
                    while (j < arg.len - 1): (j += 1) {
                        if (!(self.parser_options.accept_numerical_arguments or (arg[j] < '0' and arg[j] > '9'))) continue;
                        const matched = self.match(arg[j..j+1]);
                        if (matched == null) {
                            std.debug.print("Unrecognized flag '{s}'\n", .{arg[j..j+1]});
                            std.posix.exit(1);
                        }
                        try self.handleMatch(matched.?, arguments, &i, false);
                    }
                }
                const last_arg = arg[arg.len-1..];
                const matched = self.match(last_arg);
                if (matched == null) {
                    std.debug.print("Unrecognized flag '{s}'\n", .{arg});
                    std.posix.exit(1);
                } else {
                    try self.handleMatch(matched.?, arguments, &i, true);
                }
            } else {
                try positionalsArrayList.append(arg);
            }
        }
        self._positionals = try positionalsArrayList.toOwnedSlice();
    }

    fn getNextAsPositional(arguments: [][]const u8, index: usize, accept_numerical_arguments: bool) ?[]const u8 {
        if (index >= arguments.len - 1) {
            return null;
        }
        if (isPositional(arguments[index + 1], accept_numerical_arguments)) {
            return arguments[index + 1];
        } else {
            return null;
        }
    }

    fn isPositional(str: []const u8, accept_numerical_arguments: bool) bool {
        return str.len == 1 or !std.mem.startsWith(u8, str, "-") or ((arguments_are_numeric(str) and !accept_numerical_arguments));
    }

    fn handleMatch(self: *Self, matched: *ValuePair, arguments: [][]const u8, i: *usize, look_forward: bool) !void {
        const arg = arguments[i.*];
        matched.value.matched = true;
        const allowNone = matched.argument.allow_none;
        if (matched.argument.type == .one) {
            const next = getNextAsPositional(arguments, i.*, self.parser_options.accept_numerical_arguments);
            if (!look_forward and !allowNone) {
                std.debug.print("Expected an option for '{s}' but received none.\n", .{arg});
                std.posix.exit(1);
            }
            if (!look_forward) {
                return;
            }
            if (!allowNone and next == null) {
                std.debug.print("Expected an option for '{s}' but received none.\n", .{arg});
                std.posix.exit(1);
            } else if (next != null) {
                matched.value.singleValue = next;
                i.* += 1;
            }
        } else if (matched.argument.type == .many) {
            var next = getNextAsPositional(arguments, i.*, self.parser_options.accept_numerical_arguments);
            if (!look_forward and !allowNone) {
                std.debug.print("Expected an option for '{s}' but received none.\n", .{arg});
                std.posix.exit(1);
            }
            if (!look_forward) {
                matched.value.multiValue = try self.allocator.allocator().alloc([]const u8, 0);
                return;
            }
            if (!allowNone and next == null) {
                std.debug.print("Expected an option for '{s}' but received none.\n", .{arg});
                std.posix.exit(1);
            } else if (next != null) {
                var multiList = std.array_list.Managed([]const u8).init(std.heap.page_allocator);
                defer multiList.deinit();
                while (next != null) {
                    try multiList.append(next.?);
                    i.* += 1;
                    next = getNextAsPositional(arguments, i.*, self.parser_options.accept_numerical_arguments);
                }
                matched.value.multiValue = try multiList.toOwnedSlice();
            } else {
                matched.value.multiValue = try self.allocator.allocator().alloc([]const u8, 0);
            }
        }
    }

    fn arguments_are_numeric(str: []const u8) bool {
        if (str.len <= 1) return false;
        for (str[1..]) |val| {
            if (val >= '0' and val <= '9') return true;
        }
        return false;
    }
};



test "a" {
    const args: []const Argument = &[_]Argument{.{.shorts = "abc", .longs = &[_][]const u8{"foo", "bar"}, .type = .none}};
    const parser = Parser.init(args);
    _ = parser;
}

