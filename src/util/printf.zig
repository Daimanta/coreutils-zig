const std = @import("std");
const mem = std.mem;

const Allocator = std.mem.Allocator;
const print_tools = @import("print_tools.zig");
const test_allocator = std.testing.allocator;
const testing = std.testing;
const strings = @import("strings.zig");
const startsWith = mem.startsWith;
const print = print_tools.print;
const pprint = print_tools.pprint;

pub const ParameterType = enum{
    UNSIGNED_CHAR,
    SIGNED_INT,
    UNSIGNED_INT,
    UNSIGNED_LOWERCASE_HEX,
    UNSIGNED_UPPERCASE_HEX,
    DOUBLE_SCIENTIFIC_LOWERCASE,
    DOUBLE_SCIENTIFIC_UPPERCASE,
    DOUBLE,
    STRING,
    OCTAL
};

const flags: []const u8 = "-#+ 0,";

pub const Formatter = struct {
    parameter_type: ParameterType,
    left_align: bool = false,
    prepend_positive: bool = false,
    prepend_space: bool = false,
    prepend_zeros: bool = false,
    grouping_separator: bool = false,
    width_supplied_as_argument: bool = false,
    width: ?u32 = 0,
    precision: ?u32 = 0
};

const FormatTag = enum {
    STRING,
    FORMATTER
};

pub const FormatStringElement = union(FormatTag) {
    STRING: []const u8,
    FORMATTER: Formatter
};

pub const ArgumentTag = enum {
    UNSIGNED_INT,
    SIGNED_INT,
    STRING,
    FLOAT
};

pub const FormatArgument = union(ArgumentTag) {
    UNSIGNED_INT: u64,
    SIGNED_INT: i64,
    STRING: []const u8,
    FLOAT: f64
};

pub const FormatString = struct {
    allocator: Allocator,
    format_string_parts: []const FormatStringElement,
    backing_string: []const u8, // backing string can be released immediately at destruction, which is cheap

    pub fn init(string: []const u8, allocator: Allocator) !FormatString {
        var result = FormatString{
            .allocator = allocator,
            .format_string_parts = undefined,
            .backing_string = try allocator.dupe(u8, string)
        };

        errdefer allocator.free(result.backing_string);

        var count_percents: u32 = 0;
        for (string) |char| {
            if (char == '%') count_percents += 1;
        }
        var temp_array = try allocator.alloc(FormatStringElement, count_percents + 2);
        var temp_array_used_element: usize = 0;
        defer allocator.free(temp_array);
        if (count_percents == 0) {
            // Plain string, don't try to find formatting elements
            temp_array[0] = FormatStringElement{.STRING = result.backing_string};
            temp_array_used_element = 1;
        } else {
            var part_start: usize = 0;
            var part_end: usize = 0;
            while (part_end < string.len): (part_end += 1) {
                const char = string[part_end];
                if (char != '%') continue;
                // Percent as last character is invalid
                if (part_end == string.len - 1) return error.IncorrectFormatString;
                if (string[part_end + 1] == '%') {
                    // Literal percent sign
                    temp_array[temp_array_used_element] = FormatStringElement{.STRING = result.backing_string[part_start..part_end+1]};
                    temp_array_used_element += 1;
                    part_end += 2;
                    part_start = part_end;
                } else {
                    // Add string literal first
                    temp_array[temp_array_used_element] = FormatStringElement{.STRING = result.backing_string[part_start..part_end]};
                    temp_array_used_element += 1;

                    var formatter_iterator: usize = part_end + 1;
                    const formatter_struct = try get_formatter(string, &formatter_iterator);
                    temp_array[temp_array_used_element] = FormatStringElement{.FORMATTER = formatter_struct};
                    temp_array_used_element += 1;
                    part_start = formatter_iterator;
                    part_end = part_start;
                }
            }
            const to = min(part_end, string.len);
            if (to > part_start) {
                temp_array[temp_array_used_element] = FormatStringElement{.STRING = result.backing_string[part_start..to]};
                temp_array_used_element += 1;
            }
        }

        result.format_string_parts = try allocator.dupe(FormatStringElement, temp_array[0..temp_array_used_element]);

        return result;
    }

    pub fn printf(self: *const FormatString, args: []const FormatArgument) !void {
        const counts = self.count_types();
        if (counts[1] != args.len) return error.ArgumentCountMismatch;
        if (args.len == 0) {
            const string = self.format_string_parts[0].STRING;
            print("{s}",.{string});
            return;
        }
        var arg_it: usize = 0;
        for (self.format_string_parts) |elem| {
            switch (elem) {
                FormatStringElement.STRING => print("{s}", .{elem.STRING}),
                FormatStringElement.FORMATTER => |val| {
                    const arg = args[arg_it];
                    const param_type = val.parameter_type;
                    if (any_match(&.{ParameterType.SIGNED_INT, ParameterType.UNSIGNED_INT}, param_type)) {
                        if (arg != .UNSIGNED_INT and arg != .SIGNED_INT) return error.TypeMismatch;
                        if (arg == .UNSIGNED_INT) {
                            print("{d}", .{arg.UNSIGNED_INT});
                        } else {
                            print("{d}", .{arg.SIGNED_INT});
                        }
                    } else if (any_match(&.{ParameterType.STRING}, param_type)) {
                        if (arg != .STRING) return error.TypeMismatch;
                        print("{s}", .{arg.STRING});
                    }

                    arg_it += 1;
                }
            }
        }

    }

    pub fn count_types(self: *const FormatString) [2]u32 {
        var result: [2] u32 = [2]u32{0, 0};
        for (self.format_string_parts) |elem| {
            switch (elem) {
                FormatStringElement.STRING => result[0] += 1,
                FormatStringElement.FORMATTER => result[1] += 1
            }
        }
        return result;
    }

    pub fn deinit(self: *FormatString) void {
        self.allocator.free(self.backing_string);
        self.allocator.free(self.format_string_parts);
    }
};

pub fn main() !void {
    var input_string: []const u8 = "This is a %d plain string";
    var result = try FormatString.init(input_string, std.heap.page_allocator);
    defer result.deinit();
    try result.printf(&.{FormatArgument{.UNSIGNED_INT = 3}});
}

fn any_match(list: []const ParameterType, parameter_type: ParameterType) bool {
    for (list) |elem| {
        if (elem == parameter_type) return true;
    }
    return false;
}

fn min(a: usize, b: usize) usize {
    if (a < b) return a;
    return b;
}

fn get_formatter(string: []const u8, formatter_iterator: *usize) !Formatter {
    // determine flags
    var found_flags: [6]?bool = .{null, null, null, null, null, null};
    var flag_index = strings.indexOf(flags, string[formatter_iterator.*]);
    while (formatter_iterator.* < string.len and flag_index != null) {
        if (found_flags[flag_index.?] != null) return error.DuplicateFlag;
        found_flags[flag_index.?] = true;
        // Guaranteed to be one of six flags, none else
        formatter_iterator.* += 1;
        flag_index = strings.indexOf(flags, string[formatter_iterator.*]);
    }

    if (formatter_iterator.* == string.len) return error.InvalidFormatter;
    var width_supplied_as_argument = false;
    var width: ?u32 = null;
    var precision: ?u32 = null;
    // determine width
    if (string[formatter_iterator.*] == '*') {
        width_supplied_as_argument = true;
        formatter_iterator.* += 1;
    } else if (string[formatter_iterator.*] >= '0' and string[formatter_iterator.*] <= '9') {
        var number_iterator = formatter_iterator.*;
        while (string[number_iterator] >= '0' and string[number_iterator] <= '9'): (number_iterator += 1 ){}
        const width_string = string[formatter_iterator.*..number_iterator];
        if (std.fmt.parseInt(u32, width_string, 10)) |num| {
            width = num;
        } else |_| {
            return error.InvalidFormatter;
        }
        formatter_iterator.* += width_string.len;
    }
    // Retrieve precision
    if (string[formatter_iterator.*] == '.') {
        formatter_iterator.* += 1;
        if (formatter_iterator.* >= string.len or !(string[formatter_iterator.*] >= '0' and string[formatter_iterator.*] <= '9')) return error.InvalidFormatter;
        var number_iterator = formatter_iterator.*;
        while (string[number_iterator] >= '0' and string[number_iterator] <= '9'): (number_iterator += 1 ){}
        const precision_string = string[formatter_iterator.*..number_iterator];
        if (std.fmt.parseInt(u32, precision_string, 10)) |num| {
            precision = num;
        } else |_| {
            return error.InvalidFormatter;
        }
        formatter_iterator.* += precision_string.len;
    }
    var type_length: usize = undefined;
    const formatter_type = get_formatter_type(string[formatter_iterator.*..], &type_length) catch return error.InvalidFormatter;
    formatter_iterator.* += type_length;
    return Formatter{
        .parameter_type = formatter_type,
        .left_align = found_flags[0] != null,
        .prepend_positive = found_flags[2] != null,
        .prepend_space = found_flags[3] != null,
        .prepend_zeros = found_flags[4] != null,
        .grouping_separator = found_flags[5] != null,
        .width_supplied_as_argument = false,
        .width = width,
        .precision = precision
    };
}


fn get_formatter_type(string: []const u8, type_length: *usize) !ParameterType {
    if (startsWithAny(string, &[_][]const u8{"d", "i"})) {
        type_length.* = 1;
        return ParameterType.SIGNED_INT;
    } else if (startsWithAny(string, &[_][]const u8{"u"})) {
        type_length.* = 1;
        return ParameterType.UNSIGNED_INT;
    } else if (startsWithAny(string, &[_][]const u8{"o"})) {
        type_length.* = 1;
        return ParameterType.OCTAL;
    }else if (startsWithAny(string, &[_][]const u8{"x"})) {
        type_length.* = 1;
        return ParameterType.UNSIGNED_INT;
    } else if (startsWithAny(string, &[_][]const u8{"X"})) {
        type_length.* = 1;
        return ParameterType.UNSIGNED_INT;
    } else if (startsWithAny(string, &[_][]const u8{"f", "F", "g", "G", "a", "A"})) {
        type_length.* = 1;
        return ParameterType.DOUBLE;
    } else if (startsWithAny(string, &[_][]const u8{"c"})) {
        type_length.* = 1;
        return ParameterType.UNSIGNED_CHAR;
    } else if (startsWithAny(string, &[_][]const u8{"s"})) {
        type_length.* = 1;
        return ParameterType.STRING;
    } else if (startsWithAny(string, &[_][]const u8{"hhd", "hhi"})) {
        type_length.* = 3;
        return ParameterType.SIGNED_INT;
    }

    return error.InvalidParameter;
}

fn startsWithAny(string: []const u8, matchers: []const []const u8) bool {
    for (matchers) |matcher| {
        if (startsWith(u8, string, matcher)) return true;
    }
    return false;
}

test "parse plain string" {
    const input_string: []const u8 = "This is a plain string";
    var result = try FormatString.init(input_string, test_allocator);
    defer result.deinit();
    try testing.expectEqual(@as(usize, 1), result.format_string_parts.len);
    const counters = result.count_types();
    try testing.expectEqual(@as(u32,1), counters[0]);
    try testing.expectEqual(@as(u32,0), counters[1]);
    try testing.expectEqual(input_string.len, result.format_string_parts[0].STRING.len);
}

test "string with one literal percent sign" {
    const input_string: []const u8 = "This is a '%%' plain string";
    var result = try FormatString.init(input_string, test_allocator);
    defer result.deinit();
    try testing.expectEqual(@as(usize, 2), result.format_string_parts.len);
    const counters = result.count_types();
    try testing.expectEqual(@as(u32,2), counters[0]);
    try testing.expectEqual(@as(u32,0), counters[1]);
    try testing.expectEqual(@as(usize, 12), result.format_string_parts[0].STRING.len);
    try testing.expectEqual(@as(usize, 14), result.format_string_parts[1].STRING.len);
}

test "string with two literal percent signs" {
    const input_string: []const u8 = "This is a '%%' plain '%%' string";
    var result = try FormatString.init(input_string, test_allocator);
    defer result.deinit();
    var plain_strings: u32 = 0;
    var formatters: u32 = 0;
    try testing.expectEqual(@as(usize, 3), result.format_string_parts.len);
    for (result.format_string_parts) |elem| {
        switch (elem) {
            FormatStringElement.STRING => plain_strings += 1,
            FormatStringElement.FORMATTER => formatters += 1
        }
    }
    try testing.expectEqual(@as(usize,3), plain_strings);
    try testing.expectEqual(@as(usize,0), formatters);
    try testing.expectEqual(@as(usize, 12), result.format_string_parts[0].STRING.len);
    try testing.expectEqual(@as(usize, 10), result.format_string_parts[1].STRING.len);
    try testing.expectEqual(@as(usize, 8), result.format_string_parts[2].STRING.len);
}

test "string with percent sign at end" {
    const input_string: []const u8 = "This is a sentence ends with a %%";
    var result = try FormatString.init(input_string, test_allocator);
    defer result.deinit();
    var plain_strings: u32 = 0;
    var formatters: u32 = 0;
    try testing.expectEqual(@as(usize, 1), result.format_string_parts.len);
    for (result.format_string_parts) |elem| {
        switch (elem) {
            FormatStringElement.STRING => plain_strings += 1,
            FormatStringElement.FORMATTER => formatters += 1
        }
    }
    try testing.expectEqual(@as(usize,1), plain_strings);
    try testing.expectEqual(@as(usize,0), formatters);
    try testing.expectEqual(input_string.len - 1, result.format_string_parts[0].STRING.len);
}

test "string with one decimal mark" {
    const input_string: []const u8 = "There are %d elements";
    var result = try FormatString.init(input_string, test_allocator);
    defer result.deinit();
    var plain_strings: u32 = 0;
    var formatters: u32 = 0;
    try testing.expectEqual(@as(usize, 3), result.format_string_parts.len);
    for (result.format_string_parts) |elem| {
        switch (elem) {
            FormatStringElement.STRING => plain_strings += 1,
            FormatStringElement.FORMATTER => formatters += 1
        }
    }
    try testing.expectEqual(@as(usize,2), plain_strings);
    try testing.expectEqual(@as(usize,1), formatters);
    try testing.expectEqual(@as(usize,10), result.format_string_parts[0].STRING.len);
    try testing.expectEqual(ParameterType.SIGNED_INT, result.format_string_parts[1].FORMATTER.parameter_type);
    try testing.expectEqual(@as(usize,9), result.format_string_parts[2].STRING.len);
}

test "string with one decimal mark with flags" {
    const input_string: []const u8 = "There are %+0d elements";
    var result = try FormatString.init(input_string, test_allocator);
    defer result.deinit();
    try testing.expectEqual(@as(usize, 3), result.format_string_parts.len);
    const actual = result.format_string_parts[1].FORMATTER;
    const expected = Formatter{
        .parameter_type = .SIGNED_INT,
        .left_align = false,
        .prepend_positive = true,
        .prepend_space = false,
        .prepend_zeros = true,
        .grouping_separator = false,
        .width_supplied_as_argument = false,
        .width = null,
        .precision = null
    };
    try testing.expectEqual(expected, actual);
}

test "string with one decimal mark with width" {
    const input_string: []const u8 = "There are %10d elements";
    var result = try FormatString.init(input_string, test_allocator);
    defer result.deinit();
    try testing.expectEqual(@as(usize, 3), result.format_string_parts.len);
    const actual = result.format_string_parts[1].FORMATTER;
    const expected = Formatter{
        .parameter_type = .SIGNED_INT,
        .left_align = false,
        .prepend_positive = false,
        .prepend_space = false,
        .prepend_zeros = false,
        .grouping_separator = false,
        .width_supplied_as_argument = false,
        .width = 10,
        .precision = null
    };
    try testing.expectEqual(expected, actual);
}

test "string with one decimal mark with precision" {
    const input_string: []const u8 = "There are %.10d elements";
    var result = try FormatString.init(input_string, test_allocator);
    defer result.deinit();
    try testing.expectEqual(@as(usize, 3), result.format_string_parts.len);
    const actual = result.format_string_parts[1].FORMATTER;
    const expected = Formatter{
        .parameter_type = .SIGNED_INT,
        .left_align = false,
        .prepend_positive = false,
        .prepend_space = false,
        .prepend_zeros = false,
        .grouping_separator = false,
        .width_supplied_as_argument = false,
        .width = null,
        .precision = 10
    };
    try testing.expectEqual(expected, actual);
}

test "formatter with duplicated frag is an error" {
    const input_string: []const u8 = "There are %+0+d elements";
    _ = FormatString.init(input_string, test_allocator) catch {
        return;
    };
    try testing.expect(false);
}

test "invalid percent sign at end" {
    const input_string: []const u8 = "This string is wrong%";
    _ = FormatString.init(input_string, test_allocator) catch {
        return;
    };
    try testing.expect(false);
}

test "foo" {
    const input_string: []const u8 = "There are %10d elements";
    var result = try FormatString.init(input_string, test_allocator);
    defer result.deinit();
    try result.printf(&.{FormatArgument{.UNSIGNED_INT = 3}});
}

test "bar" {
    var input_string: []const u8 = "This is a plain string";
    var result = try FormatString.init(input_string, test_allocator);
    defer result.deinit();
    try result.printf(&.{});
}