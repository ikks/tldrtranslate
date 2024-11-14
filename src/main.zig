const std = @import("std");
const lmdb = @import("lmdb-zig");

const Allocator = std.mem.Allocator;
const fs = std.fs;
const print = std.debug.print;
const logerr = std.log.err;
const Child = std.process.Child;
const ArrayList = std.ArrayList;
const http = std.http;

const Replacement = struct {
    original: []const u8,
    replacement: []const u8,
};

const CombinedError = lmdb.Mdb_Err || error{ OutOfMemory, AllocationFailed };

const language = "es";
const translation_api = "http://localhost:8000/translate";
const original_language = "en";
const cmdtranslation = "/home/igor/bin/argos-translate";
const cmdthirdperson = "/home/igor/bin/tercerapersona";
const dbverbspath = "/home/igor/playground/python/updatecompjugadb/tldr.db";

// Use ENV VARIABLES to get WORKING DIR and LANGUAGE
// Improve memory management, reuse the allocator in the invocation

pub fn main() !u8 {
    // Get allocator
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // Parse args into string array (error union needs 'try')
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len != 2) {
        logerr("Make sure the path includes the tldr root, target and pagename: pages/common/tar.md", .{});
        return 1;
    }

    processfile(args[1], allocator) catch |err| {
        if (err == std.posix.OpenError.FileNotFound) {
            logerr("Make sure the path includes the tldr root, target and pagename: pages/common/tar.md", .{});
            return err; // Return to signify the end
        } else if (err == std.posix.ConnectError.ConnectionRefused) {
            logerr("Make sure you have an API Argos Translate Running in {s}", .{translation_api});
            return err;
        } else if (err == lmdb.Mdb_Err.no_such_file_or_dir) {
            logerr("Make sure you have access to the verb conjugation db {s}", .{translation_api});
        } else {
            return err; // Propagate any other errors up the call stack
        }
    };

    return 0;
}

fn processfile(filename: []u8, allocator: Allocator) !void {
    const file = try fs.cwd().openFile(filename, .{});
    defer file.close();

    const ipages = std.mem.indexOf(u8, filename, "pages") orelse {
        logerr("Make sure the path includes the tldr root, target and pagename: pages/common/tar.md", .{});
        return;
    };
    const filename_language = try std.fmt.allocPrint(allocator, "{s}.{s}{s}", .{ filename[0 .. ipages + 5], language, filename[ipages + 5 ..] });
    defer allocator.free(filename_language);
    const file_out = try fs.cwd().createFile(filename_language, .{});
    defer file_out.close();

    var buf_reader = std.io.bufferedReader(file.reader());
    const reader = buf_reader.reader();

    var line = ArrayList(u8).init(allocator);
    defer line.deinit();

    const writer = line.writer();
    var line_no: usize = 0;
    while (reader.streamUntilDelimiter(writer, '\n', null)) {
        // Clear the line so we can reuse it.
        defer line.clearRetainingCapacity();
        line_no += 1;
        if (line.items.len < 3) {
            try file_out.writer().print("{s}\n", .{line.items});
            continue;
        }
        switch (line.items[0]) {
            '-' => {
                try process_description(line.items, allocator, file_out.writer());
            },
            '>' => {
                try process_summary(line.items, allocator, file_out.writer());
            },
            '`' => {
                try process_execution(line.items, file_out.writer());
            },
            else => {
                try file_out.writer().print("{s}\n", .{line.items});
            },
        }
    } else |err| switch (err) {
        error.EndOfStream => { // end of file
            if (line.items.len > 0) {
                line_no += 1;
            }
        },
        else => return err, // Propagate error
    }
}

fn process_summary(source_string: []const u8, allocator: Allocator, writer: std.fs.File.Writer) !void {
    const t1 = [_]Replacement{
        Replacement{ .original = "> More information", .replacement = "> Más información" },
        Replacement{ .original = "> See also:", .replacement = "> Vea también:" },
        Replacement{ .original = "> This command is an alias of", .replacement = "> Este comando es un alias de" },
        Replacement{ .original = "> View documentation for the original command", .replacement = "> Vea la documentación para el comando original" },
    };
    var buffer: [1024]u8 = undefined;
    const result: ReplaceAndSize = replacemany(source_string[0..], &t1, buffer[0..]);
    if (result.replacements > 0) {
        try writer.print("{s}", .{buffer[0..result.size]});
        if (buffer[result.size - 1] != '\n') {
            _ = try writer.write("\n");
        }
    } else {
        try process_description(source_string, allocator, writer);
    }
}

fn process_execution(source_string: []const u8, writer: std.fs.File.Writer) !void {
    const t1 = [_]Replacement{
        Replacement{ .original = "path/to/directory", .replacement = "ruta/al/directorio" },
        Replacement{ .original = "path/to/file", .replacement = "ruta/al/archivo" },
        Replacement{ .original = "path/to/file_or_directory", .replacement = "ruta/al/archivo_o_directorio" },
        Replacement{ .original = "path/to/", .replacement = "ruta/a/" },
    };
    var buffer: [1024]u8 = undefined;
    const result = replacemany(source_string, &t1, buffer[0..]);
    try writer.print("{s}", .{buffer[0..result.size]});
    if (buffer[result.size - 1] != '\n') {
        _ = try writer.write("\n");
    }
}

fn process_description(source_string: []const u8, allocator: Allocator, writer: std.fs.File.Writer) !void {
    var slice: []u8 = undefined;
    slice = try translateline((source_string[2..]), allocator);
    defer allocator.free(slice);

    const fix_conjugation = conjugate_to_third(allocator, slice) catch |err| {
        return err;
    };
    defer allocator.free(fix_conjugation);

    const last_char_idx = fix_conjugation.len - 1;
    if (fix_conjugation[last_char_idx] == '\n') {
        try writer.print("{s}{s}", .{ source_string[0..2], fix_conjugation });
    } else {
        try writer.print("{s}{s}\n", .{ source_string[0..2], fix_conjugation });
    }
}

fn translatelinecmd(line: []u8, allocator: std.mem.Allocator) ![]u8 {
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

fn encode_iso_8859_1(allocator: Allocator, input: []const u8) ![]u8 {
    var output = allocator.alloc(u8, input.len) catch return error.AllocationFailed;
    for (input, 0..) |char, index| {
        output[index] = char; // Directly copy since ASCII characters are the same in ISO 8859-1
    }
    return output;
}

fn decode_iso_8859_1(allocator: Allocator, input: []const u8) ![]u8 {
    var output = allocator.alloc(u8, input.len) catch return error.AllocationFailed;
    for (input, 0..) |byte, index| {
        output[index] = byte; // Directly copy bytes to output string
    }
    return output;
}

test "iso_8859_1" {
    const allocator = std.testing.allocator_instance.allocator();
    const initial = "Moñón";
    const encode = try encode_iso_8859_1(allocator, initial);
    defer allocator.free(encode);
    const decode = try decode_iso_8859_1(allocator, initial);
    defer allocator.free(decode);
    std.debug.print("{s}:{d}. {s}:{d}. {s}:{d}", .{ initial, initial.len, encode, encode.len, decode, decode.len });
}

fn conjugate_to_third(allocator: std.mem.Allocator, line: []const u8) CombinedError![]const u8 {
    const index_separator = std.mem.indexOf(u8, line, " ") orelse {
        return allocator.dupe(u8, line);
    };
    const verb = try decode_iso_8859_1(allocator, line[0..index_separator]);
    defer allocator.free(verb);
    var buffer: [80]u8 = undefined; // Buffer to hold ASCII bytes
    @memcpy(buffer[0..verb.len], verb);

    // Print the ASCII encoded values
    for (buffer[0..verb.len]) |byte| {
        std.debug.print("({}){c}", .{ byte, byte });
    }
    const env = try lmdb.Env.init(dbverbspath, .{});
    defer env.deinit();

    const tx = try env.begin(.{});
    errdefer tx.deinit();
    const db = try tx.open(null, .{});
    defer db.close(env);
    const normalize = try allocator.dupe(u8, verb);
    defer allocator.free(normalize);
    const wasUpper = std.ascii.isUpper(verb[0]);
    normalize[0] = std.ascii.toLower(normalize[0]);
    std.debug.print("{s} {c} {d}\n", .{ verb, verb[1], verb[1] });
    const conjugation = tx.get(db, normalize) catch verb;
    if (wasUpper) {
        const result = try std.fmt.allocPrint(allocator, "{c}{s}{s}", .{ std.ascii.toUpper(conjugation[0]), conjugation[1..], line[index_separator..] });
        return result;
    }
    const result = try std.fmt.allocPrint(allocator, "{s}{s}", .{ conjugation, line[index_separator..] });
    return result;
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

const translateline = translatelineapi;

fn translatelineapi(source_string: []const u8, allocator: Allocator) ![]u8 {
    var client = http.Client{ .allocator = allocator };
    defer client.deinit();

    const uri = try std.Uri.parse(translation_api);
    const escaped_for_json = try escapeJsonString(source_string, allocator);
    defer allocator.free(escaped_for_json);
    const payload = try std.fmt.allocPrint(allocator, "{{\"text\": \"{s}\", \"from_lang\": \"{s}\", \"to_lang\": \"{s}\"}}", .{ escaped_for_json, original_language, language });
    defer allocator.free(payload);

    var buf: [1024]u8 = undefined;
    var req = try client.open(.POST, uri, .{ .server_header_buffer = &buf });
    defer req.deinit();

    req.transfer_encoding = .{ .content_length = payload.len };
    try req.send();
    var wtr = req.writer();
    try wtr.writeAll(payload);
    try req.finish();
    try req.wait();

    try std.testing.expectEqual(req.response.status, .ok);

    var rdr = req.reader();
    const body = try rdr.readAllAlloc(allocator, 1024 * 1024 * 4);
    defer allocator.free(body);
    const Translated_text = struct { translated_text: []u8 };
    const parsed = try std.json.parseFromSlice(Translated_text, allocator, body, .{});
    defer parsed.deinit();

    const json_res = parsed.value;

    return allocator.dupe(u8, json_res.translated_text);
}

const ReplaceAndSize = struct {
    replacements: usize,
    size: usize,
};

fn replacemany(original: []const u8, replacements: []const Replacement, output: []u8) ReplaceAndSize {
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
        len = len + found * (replacepair.replacement.len - replacepair.original.len);
        @memcpy(buffer2[0..len], output[0..len]);
    }
    return ReplaceAndSize{ .replacements = total, .size = len };
}

test replacemany {
    var buffer: [1024]u8 = undefined;
    const t1 = [_]Replacement{
        Replacement{ .original = "> More Information", .replacement = "> Más información" },
        Replacement{ .original = "> See also:", .replacement = "> Vea también:" },
        Replacement{ .original = "path/to/file", .replacement = "ruta/al/archivo" },
    };
    const result_ch = replacemany("> More Information", &t1, buffer[0..]);
    try std.testing.expectEqualStrings(buffer[0..result_ch.size], "> Más información");
    const result_sh = replacemany("> See also:", &t1, buffer[0..]);
    try std.testing.expectEqualStrings(buffer[0..result_sh.size], "> Vea también:");
    const result_ml = replacemany("path/to/file1 path/to/file2", &t1, buffer[0..]);
    try std.testing.expectEqualStrings(buffer[0..result_ml.size], "ruta/al/archivo1 ruta/al/archivo2");
    const result = replacemany("No camvea", &t1, buffer[0..]);
    try std.testing.expectEqualStrings(buffer[0..result.size], "No camvea");
}

fn escapeJsonString(input: []const u8, allocator: Allocator) ![]u8 {
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
