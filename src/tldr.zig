const std = @import("std");
const tldr_base = @import("tldr-base.zig");
const lang_es = @import("lang_es.zig");

const testing = std.testing;
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const Child = std.process.Child;
const logerr = std.log.err;
const fs = std.fs;
const http = std.http;

const Replacement = tldr_base.Replacement;
const ReplaceAndSize = tldr_base.ReplaceAndSize;
const LangReplacement = tldr_base.LangReplacement;
const identityFn = tldr_base.identityFn;
const PostProcess = tldr_base.PostProcess;
const conjugateToThird = lang_es.conjugateToThird;
const original_language = tldr_base.original_language;

const cmdtranslation = "/home/igor/bin/argos-translate";
pub const translation_api = "http://localhost:8000/translate";

pub const ArgosApiError = error{LangNotFound};

pub fn replaceMany(original: []const u8, replacements: []const Replacement, output: []u8) ReplaceAndSize {
    var found: usize = 0;
    var total: usize = 0;
    var len = original.len;
    var buffer2: [2000]u8 = undefined;

    if (replacements.len == 0) {
        std.mem.copyForwards(u8, output, original);
        return ReplaceAndSize{ .replacements = 0, .size = original.len };
    }
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

fn translateLineCmd(allocator: std.mem.Allocator, line: []u8, language: []u8) ![]u8 {
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

/// Translates a TLDR file to the specified language using the replacements for the language
/// Writes the result to the language specified directory.
pub fn processFile(
    allocator: Allocator,
    filename: []const u8,
    replacements: LangReplacement,
    language: []const u8,
) !void {
    const file = try fs.cwd().openFile(filename, .{});
    defer file.close();

    const ipages = std.mem.indexOf(u8, filename, "pages") orelse {
        logerr("Make sure the path includes the tldr root, target and pagename: pages/common/tar.md", .{});
        return;
    };
    const filename_language = try std.fmt.allocPrint(allocator, "{s}.{s}{s}", .{ filename[0 .. ipages + 5], language, filename[ipages + 5 ..] });
    defer allocator.free(filename_language);
    const file_out = fs.cwd().createFile(filename_language, .{}) catch |err| {
        logerr("Make sure the target path exists {s}\n{}", .{ filename_language, err });
        return;
    };
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
                try processDescription(allocator, line.items, language, replacements.fixPostTranslation, file_out.writer());
            },
            '>' => {
                try processSummary(allocator, line.items, replacements.summary_replacement, language, replacements.fixPostTranslation, file_out.writer());
            },
            '`' => {
                try processExecution(line.items, replacements.process_replacement, file_out.writer());
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

fn processSummary(allocator: Allocator, source_string: []const u8, summary_replacements: []const Replacement, language: []const u8, postFn: PostProcess, writer: std.fs.File.Writer) !void {
    var buffer: [1024]u8 = undefined;
    const result: ReplaceAndSize = replaceMany(source_string[0..], summary_replacements, buffer[0..]);
    if (result.replacements > 0) {
        try writer.print("{s}", .{buffer[0..result.size]});
        if (buffer[result.size - 1] != '\n') {
            _ = try writer.write("\n");
        }
    } else {
        try translateLine(allocator, source_string, language, postFn, writer);
    }
}

fn processExecution(source_string: []const u8, replacements: []const Replacement, writer: std.fs.File.Writer) !void {
    var buffer: [1024]u8 = undefined;
    const result = replaceMany(source_string, replacements, buffer[0..]);
    try writer.print("{s}", .{buffer[0..result.size]});
    if (buffer[result.size - 1] != '\n') {
        _ = try writer.write("\n");
    }
}

const processDescription = translateLine;

fn translateLine(allocator: Allocator, source_string: []const u8, language: []const u8, postFn: PostProcess, writer: std.fs.File.Writer) !void {
    var slice: []u8 = undefined;
    slice = try translateLineBack(allocator, source_string[2..], language);
    defer allocator.free(slice);

    const fix_conjugation = postFn(allocator, slice) catch |err| {
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

const translateLineBack = translateLineApi;

fn translateLineApi(allocator: Allocator, source_string: []const u8, language: []const u8) ![]u8 {
    var client = http.Client{ .allocator = allocator };
    defer client.deinit();

    const uri = try std.Uri.parse(translation_api);
    const escaped_for_json = try escapeJsonString(source_string, allocator);
    defer allocator.free(escaped_for_json);
    const payload = try std.fmt.allocPrint(allocator, "{{\"text\": \"{s}\", \"from_lang\": \"{s}\", \"to_lang\": \"{s}\"}}", .{ escaped_for_json, original_language, language[0..2] });
    defer allocator.free(payload);

    var buf: [1024]u8 = undefined;
    var req = client.open(.POST, uri, .{ .server_header_buffer = &buf }) catch |err| {
        if (err == std.posix.ConnectError.ConnectionRefused) {
            logerr("Make sure you have an API Argos Translate Running in {s}\n check {s} and make it run in port 8000", .{ translation_api, "https://github.com/Jaro-c/Argos-API" });
        }
        return err;
    };
    defer req.deinit();

    req.transfer_encoding = .{ .content_length = payload.len };
    try req.send();
    var wtr = req.writer();
    try wtr.writeAll(payload);
    try req.finish();
    try req.wait();

    var rdr = req.reader();
    const body = try rdr.readAllAlloc(allocator, 1024 * 1024 * 4);
    defer allocator.free(body);

    if (req.response.status != .ok) {
        logerr("Make sure you have language `{s}` installed, if your API has it installed, check the next.\n Status:{d}\nPayload:{s}\nResponse:{s}", .{ language, req.response.status, payload, body });
        return ArgosApiError.LangNotFound;
    }

    const Translated_text = struct { translated_text: []u8 };
    const parsed = try std.json.parseFromSlice(Translated_text, allocator, body, .{});
    defer parsed.deinit();

    const json_res = parsed.value;

    return allocator.dupe(u8, json_res.translated_text);
}
