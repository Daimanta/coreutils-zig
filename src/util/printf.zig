const std = @import("std");

const Allocator = std.mem.Allocator;
const test_allocator = std.testing.allocator;
const testing = std.testing;

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

pub const Formatter = struct {
    parameter_type: ParameterType,
    left_align: bool = false,
    prepend_positive: bool = false,
    prepend_space: bool = false,
    prepend_zeros: bool = false,
    grouping_separator: bool = false,
    width: u8 = 0,
    precision: u8 = 0
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

    pub fn init(string: []const u8, allocator: Allocator) !FormatString {
        var result = FormatString{
            .allocator = allocator,
            .format_string_parts = undefined
        };
        var count_percents: u32 = 0;
        for (string) |char| {
            if (char == '%') count_percents += 1;
        }
        var temp_array = try allocator.alloc(FormatStringElement, count_percents + 1);
        var temp_array_used_element: usize = 0;
        defer allocator.free(temp_array);
        if (temp_array.len == 1) {
            // Plain string, don't try to find formatting elements
            temp_array[0] = FormatStringElement{.STRING = try allocator.dupe(u8, string)};
            temp_array_used_element = 1;
        } else {
            var temp_buffer = try allocator.alloc(u8, string.len);
            defer allocator.free(temp_buffer);
            var buffer_start_write: usize = 0;
            var buffer_end_read: usize = 0;

            var part_start: usize = 0;
            var part_end: usize = 0;
            while (part_start < string.len) {
                while (part_end < string.len): (part_end += 1) {
                    if (string[part_end] != '%') continue;
                    // Percent as last character is invalid
                    if (part_end == string.len - 1) return error.IncorrectFormatString;
                    if (string[part_end + 1] == '%') {
                        // Literal percent sign
                        // Add string so far to buffer and skip to next character
                        std.mem.copy(u8, temp_buffer[buffer_start_write..], string[part_start..part_end+1]);
                        buffer_start_write += (part_end+1 - part_start);
                        buffer_end_read += (part_end+1 - part_start);
                        part_end += 2;
                        part_start = part_end;
                    } else {

                    }
                }
                if (part_end == string.len) {
                    if (buffer_end_read != 0) {
                        if (part_end - part_start != 0) {
                            std.mem.copy(u8, temp_buffer[buffer_start_write..], string[part_start..part_end]);
                            buffer_end_read += (part_end - part_start);
                        }
                        temp_array[temp_array_used_element] = FormatStringElement{.STRING = try allocator.dupe(u8, temp_buffer[0..buffer_end_read])};
                        temp_array_used_element += 1;
                        break;
                    }
                }
            }
        }

        result.format_string_parts = try allocator.dupe(FormatStringElement, temp_array[0..temp_array_used_element]);

        return result;
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
        for (self.format_string_parts) |part| {
            switch (part) {
                FormatStringElement.STRING => |value| self.allocator.free(value),
                FormatStringElement.FORMATTER => continue
            }
        }
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

test "string with two literal percent signs" {
    const input_string: []const u8 = "This is a '%%' plain '%%' string";
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
    try testing.expectEqual(input_string.len - 2, result.format_string_parts[0].STRING.len);
}

test "string with two literal percent signs" {
    const input_string: []const u8 = "This string is wrong%";
    _ = FormatString.init(input_string, test_allocator) catch {
        return;
    };
    try testing.expect(false);
}