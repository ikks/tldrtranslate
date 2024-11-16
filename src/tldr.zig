const std = @import("std");
// const lmdb = @import("lmdb-zig");

const testing = std.testing;
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const Child = std.process.Child;

const dbverbspath = "/home/igor/playground/python/updatecompjugadb/tldr.db";
const cmdtranslation = "/home/igor/bin/argos-translate";
const cmdthirdperson = "/home/igor/bin/tercerapersona";

pub const ReplaceAndSize = struct {
    replacements: usize,
    size: usize,
};

pub const Replacement = struct {
    original: []const u8,
    replacement: []const u8,
};

pub fn replacemany(original: []const u8, replacements: []const Replacement, output: []u8) ReplaceAndSize {
    var found: usize = 0;
    var total: usize = 0;
    var len = original.len;
    var buffer2: [2000]u8 = undefined;

    @memcpy(buffer2[0..original.len], original);
    for (replacements) |replacepair| {
        found = std.mem.replace(u8, buffer2[0..len], replacepair.original, replacepair.replacement, output);
        if (found == 0) {
            continue;
        }
        total += found;
        if (replacepair.replacement.len > replacepair.original.len) {
            len = len + found * (replacepair.replacement.len - replacepair.original.len);
        } else {
            len = len - found * (replacepair.original.len - replacepair.replacement.len);
        }
        @memcpy(buffer2[0..len], output[0..len]);
    }
    return ReplaceAndSize{ .replacements = total, .size = len };
}

// export fn conjugate_to_third(allocator: std.mem.Allocator, line: []const u8) CombinedError![]const u8 {
//     const index_separator = std.mem.indexOf(u8, line, " ") orelse {
//         return allocator.dupe(u8, line);
//     };
//     const verb = try decode_iso_8859_1(allocator, line[0..index_separator]);
//     defer allocator.free(verb);
//     var buffer: [80]u8 = undefined; // Buffer to hold ASCII bytes
//     @memcpy(buffer[0..verb.len], verb);

//     const env = try lmdb.Env.init(dbverbspath, .{});
//     defer env.deinit();

//     const tx = try env.begin(.{});
//     errdefer tx.deinit();
//     const db = try tx.open(null, .{});
//     defer db.close(env);
//     const normalize = try allocator.dupe(u8, verb);
//     defer allocator.free(normalize);
//     const wasUpper = std.ascii.isUpper(verb[0]);
//     normalize[0] = std.ascii.toLower(normalize[0]);
//     const conjugation = tx.get(db, normalize) catch verb;
//     if (wasUpper) {
//         const result = try std.fmt.allocPrint(allocator, "{c}{s}{s}", .{ std.ascii.toUpper(conjugation[0]), conjugation[1..], line[index_separator..] });
//         return result;
//     }
//     const result = try std.fmt.allocPrint(allocator, "{s}{s}", .{ conjugation, line[index_separator..] });
//     return result;
// }

fn translatelinecmd(allocator: std.mem.Allocator, line: []u8, original_language: []u8, language: []u8) ![]u8 {
    const argv = [_][]const u8{ cmdtranslation, "--from", original_language, "--to", language, line };
    var child = Child.init(&argv, allocator);
    child.stdout_behavior = .Pipe;
    child.stderr_behavior = .Pipe;

    var stdout_ = ArrayList(u8).init(allocator);
    var stderr_ = ArrayList(u8).init(allocator);

    defer stdout_.deinit();
    defer stderr_.deinit();
    try child.spawn();
    try child.collectOutput(&stdout_, &stderr_, 8192);
    const exit_code = child.wait();
    try std.testing.expectEqual(exit_code, std.process.Child.Term{ .Exited = 0 });

    return allocator.dupe(u8, stdout_.items);
}

fn thirdperson(line: []u8, allocator: std.mem.Allocator) ![]u8 {
    const index_separator = std.mem.indexOf(u8, line, " ") orelse {
        return allocator.dupe(u8, line);
    };
    const word = line[0..index_separator];

    const argv = [_][]const u8{ cmdthirdperson, word };

    if (word[word.len - 1] == 'e') {
        // In case the verb was not inflected
        word[word.len - 1] = 'a';
        const result = try std.fmt.allocPrint(allocator, "{s}{s}", .{ word[0..index_separator], line[index_separator..] });
        return result;
    }
    if (word[word.len - 1] != 'r') {
        // In case the verb was not inflected
        const result = try std.fmt.allocPrint(allocator, "{s}", .{line[0..]});
        return result;
    }

    var child = Child.init(&argv, allocator);
    child.stdout_behavior = .Pipe;
    child.stderr_behavior = .Pipe;

    var stdout_ = ArrayList(u8).init(allocator);
    var stderr_ = ArrayList(u8).init(allocator);

    defer stdout_.deinit();
    defer stderr_.deinit();
    try child.spawn();
    try child.collectOutput(&stdout_, &stderr_, 1024);
    const exit_code = child.wait();
    try std.testing.expectEqual(exit_code, std.process.Child.Term{ .Exited = 0 });
    const idx_last = stdout_.items.len - 1;
    stdout_.items[0] = std.ascii.toUpper(stdout_.items[0]);
    const result = try std.fmt.allocPrint(allocator, "{s}{s}", .{ stdout_.items[0..idx_last], line[index_separator..] });
    return result;
}

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
