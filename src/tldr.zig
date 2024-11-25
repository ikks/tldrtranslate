const std = @import("std");
const tldr_base = @import("tldr-base.zig");
const lang_es = @import("lang_es.zig");
const escapeJsonString = @import("extern.zig").escapeJsonString;

const testing = std.testing;
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const Child = std.process.Child;
const logErr = tldr_base.logErr;
const fs = std.fs;
const http = std.http;

const Replacement = tldr_base.Replacement;
const ReplaceAndSize = tldr_base.ReplaceAndSize;
const LangReplacement = tldr_base.LangReplacement;
const identityFn = tldr_base.identityFn;
const PostProcess = tldr_base.PostProcess;
const original_language = tldr_base.original_language;
const replaceMany = tldr_base.replaceMany;

const translation_api = &tldr_base.global_config.translation_api;

pub const ArgosApiError = error{LangNotFound};

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
        logErr("Make sure the path includes the tldr root, target and pagename: pages/common/tar.md", .{});
        return;
    };
    const filename_language = try std.fmt.allocPrint(allocator, "{s}.{s}{s}", .{ filename[0 .. ipages + 5], language, filename[ipages + 5 ..] });
    defer allocator.free(filename_language);
    const file_out = fs.cwd().createFile(filename_language, .{}) catch |err| {
        logErr("Make sure the target path exists {s}\n{}", .{ filename_language, err });
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
    var sentence: []u8 = undefined;
    sentence = try translateLineApi(allocator, source_string[2..], language);
    defer allocator.free(sentence);

    const post_processed_line = postFn(allocator, sentence) catch |err| {
        return err;
    };
    defer allocator.free(post_processed_line);

    const last_char_idx = post_processed_line.len - 1;
    if (post_processed_line[last_char_idx] == '\n') {
        try writer.print("{s}{s}", .{ source_string[0..2], post_processed_line });
    } else {
        try writer.print("{s}{s}\n", .{ source_string[0..2], post_processed_line });
    }
}

fn translateLineApi(allocator: Allocator, source_string: []const u8, language: []const u8) ![]u8 {
    var client = http.Client{ .allocator = allocator };
    defer client.deinit();
    const uri = try std.Uri.parse(translation_api.*);
    const escaped_for_json = try escapeJsonString(source_string, allocator);
    defer allocator.free(escaped_for_json);
    const payload = try std.fmt.allocPrint(allocator, "{{\"text\": \"{s}\", \"from_lang\": \"{s}\", \"to_lang\": \"{s}\"}}", .{ escaped_for_json, original_language, language[0..2] });
    defer allocator.free(payload);

    var buf: [1024]u8 = undefined;
    var req = client.open(.POST, uri, .{ .server_header_buffer = &buf }) catch |err| {
        if (err == std.posix.ConnectError.ConnectionRefused) {
            logErr("Make sure you have an API Argos Translate Running in {s}.\n Follow instructions from {s} to install and make it run in another window. It takes a few seconds to be available.", .{ translation_api.*, "https://github.com/Jaro-c/Argos-API" });
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
        logErr("Make sure you have language `{s}` installed, if your API has it installed, check the next.\n Status:{d}\nPayload:{s}\nResponse:{s}", .{ language, req.response.status, payload, body });
        return ArgosApiError.LangNotFound;
    }

    const Translated_text = struct { translated_text: []u8 };
    const parsed = try std.json.parseFromSlice(Translated_text, allocator, body, .{});
    defer parsed.deinit();

    const json_res = parsed.value;

    return allocator.dupe(u8, json_res.translated_text);
}
