const std = @import("std");
const builtin = @import("builtin");
const Allocator = std.mem.Allocator;

pub fn escapeJsonString(input: []const u8, allocator: Allocator) ![]u8 {
    var result = try allocator.alloc(u8, input.len * 2);
    var index: usize = 0;
    for (input) |c| {
        switch (c) {
            '\"' => {
                result[index] = '\\';
                result[index + 1] = c;
                index += 2;
            },
            '\\' => {
                result[index] = '\\';
                result[index + 1] = c;
                index += 2;
            },
            '\n' => {
                result[index] = '\\';
                result[index + 1] = 'n';
                index += 2;
            },
            '\r' => {
                result[index] = '\\';
                result[index + 1] = 'r';
                index += 2;
            },
            '\t' => {
                result[index] = '\\';
                result[index + 1] = 't';
                index += 2;
            },
            else => {
                result[index] = c;
                index += 1;
            },
        }
    }
    return result[0..index]; // Return the escaped string
}
