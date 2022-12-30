const std = @import("std");

const Allocator = std.mem.Allocator;
const test_allocator = std.testing.allocator;
const testing = std.testing;
const strings = @import("strings.zig");

pub const ParameterType = enum{
    UNSIGNED_CHAR,
    SIGNED_INT,
    UNSIGNED_INT,
    UNSIGNED_LOWERCASE_HEX,
    UNSIGNED_UPPERCASE_HEX,
    DOUBLE_SCIENTIFIC_LOWERCASE,
    DOUBLE_SCIENTIFIC_UPPERCASE,
    DOUBLE,
    STRING
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
    width: ?u8 = 0,
    precision: ?u8 = 0
};

const FormatTag = enum {
    STRING,
    FORMATTER
};

pub const FormatStringElement = union(FormatTag) {
    STRING: []const u8,
    FORMATTER: Formatter
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

                    // determine flags
                    var found_flags: [6]?bool = .{null, null, null, null, null, null};
                    var formatter_iterator: usize = part_end + 1;
                    var flag_index = strings.indexOf(flags, string[formatter_iterator]);
                    while (formatter_iterator < string.len and flag_index != null) {
                        if (found_flags[flag_index.?] != null) return error.DuplicateFlag;
                        found_flags[flag_index.?] = true;
                        // Guaranteed to be one of six flags, none else
                        formatter_iterator += 1;
                        flag_index = strings.indexOf(flags, string[formatter_iterator]);
                    }

                    if (formatter_iterator == string.len) return error.InvalidFormatter;
                    var width_supplied_as_argument = false;
                    var width: ?u8 = null;
                    var precision: ?u8 = null;
                    // determine width
                    if (string[formatter_iterator] == '*') {
                        width_supplied_as_argument = true;
                        formatter_iterator += 1;
                    } else if (string[formatter_iterator] >= '0' and string[formatter_iterator] <= '9') {
                        // TODO: extract number
                        width = 1;
                        formatter_iterator += 1;
                    }
                    // Retrieve precision
                    if (string[formatter_iterator] == '.') {
                        // TODO: determine precision
                        precision = 1;
                        formatter_iterator +=1;
                    }
                    var type_length: usize = undefined;
                    const formatter_type = get_formatter_type(string[formatter_iterator..], &type_length);
                    formatter_iterator += type_length;
                    var formatter_struct = Formatter{.parameter_type = formatter_type};
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

    fn min(a: usize, b: usize) usize {
        if (a < b) return a;
        return b;
    }

    fn get_formatter_type(string: []const u8, type_length: *usize) ParameterType {
        _ = string;
        type_length.* = 1;
        return ParameterType.UNSIGNED_CHAR;
    }

    pub fn count_formatters(self: *FormatString) u32 {
        var result: u32 = 0;
        for (self.format_string_parts) |elem| {
            switch (elem) {
                FormatStringElement.STRING => continue,
                FormatStringElement.FORMATTER => result += 1
            }
        }
        return result;
    }

    pub fn deinit(self: *FormatString) void {
        self.allocator.free(self.backing_string);
        self.allocator.free(self.format_string_parts);
    }
};

test "parse plain string" {
    const input_string: []const u8 = "This is a plain string";
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
    try testing.expectEqual(input_string.len, result.format_string_parts[0].STRING.len);
}

test "string with one literal percent sign" {
    const input_string: []const u8 = "This is a '%%' plain string";
    var result = try FormatString.init(input_string, test_allocator);
    defer result.deinit();
    var plain_strings: u32 = 0;
    var formatters: u32 = 0;
    try testing.expectEqual(@as(usize, 2), result.format_string_parts.len);
    for (result.format_string_parts) |elem| {
        switch (elem) {
            FormatStringElement.STRING => plain_strings += 1,
            FormatStringElement.FORMATTER => formatters += 1
        }
    }
    try testing.expectEqual(@as(usize,2), plain_strings);
    try testing.expectEqual(@as(usize,0), formatters);
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
    var plain_strings: u32 = 0;
    var formatters: u32 = 0;
    try testing.expectEqual(@as(usize, 1), result.format_string_parts.len);
    for (result.format_string_parts) |elem| {
        switch (elem) {
            FormatStringElement.STRING => plain_strings += 1,
            FormatStringElement.FORMATTER => formatters += 1
        }
    }
    try testing.expectEqual(@as(usize,2), plain_strings);
    try testing.expectEqual(@as(usize,1), formatters);
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