const std = @import("std");

const tldr = @import("tldr.zig");

const Replacement = tldr.Replacement;
const ReplaceAndSize = tldr.ReplaceAndSize;
const replacemany = tldr.replacemany;
const escapeJsonString = tldr.escapeJsonString;
const conjugate_to_third = tldr.conjugate_to_third;
const ArgosApiError = tldr.ArgosApiError;

const Allocator = std.mem.Allocator;
const fs = std.fs;
const print = std.debug.print;
const logerr = std.log.err;
const ArrayList = std.ArrayList;
const http = std.http;

const translation_api = "http://localhost:8000/translate";
const dbverbspath = "/home/igor/playground/python/updatecompjugadb/tldr.db";

// Separate in file per language? or configuration to make it easier for other languages?
// Improve memory management, reuse the allocator in the invocation of what?

fn managelang(allocator: Allocator) ![]u8 {
    var language: []u8 = undefined;
    language = std.process.getEnvVarOwned(allocator, "TLDR_LANG") catch |err| {
        if (err == std.process.GetEnvVarOwnedError.EnvironmentVariableNotFound) {
            const other_value = try std.process.getEnvVarOwned(allocator, "LANG");
            defer allocator.free(other_value);
            if (!std.mem.eql(u8, other_value[0..2], "en")) {
                if (std.mem.eql(u8, other_value[0..2], "pt") or std.mem.eql(u8, other_value[0..2], "zh")) {
                    std.mem.copyForwards(u8, language, other_value[0..4]);
                } else {
                    std.mem.copyForwards(u8, language, other_value[0..2]);
                }
                return language;
            } else {
                language = try allocator.dupe(u8, "es");
                return language;
            }
        } else {
            return err;
        }
    };

    return language;
}

pub fn main() !u8 {
    var language: []u8 = undefined;
    const original_language = "en";
    // Get allocator
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);
    language = try managelang(allocator);
    defer allocator.free(language);

    if (args.len != 2) {
        logerr("Make sure the path includes the tldr root, target and pagename: pages/common/tar.md", .{});
        return 1;
    }

    processfile(allocator, args[1], original_language, language) catch |err| {
        if (err == std.posix.OpenError.FileNotFound) {
            logerr("Make sure the path includes the tldr root, target and pagename: pages/common/tar.md\nCulprit was {s}", .{args[1]});
            return err; // Return to signify the end
        } else if (err == std.posix.ConnectError.ConnectionRefused) {
            logerr("Make sure you have an API Argos Translate Running in {s}", .{translation_api});
            return err;
        } else {
            return err; // Propagate any other errors up the call stack
        }
    };

    return 0;
}

fn processfile(
    allocator: Allocator,
    filename: []const u8,
    original_language: []const u8,
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
                try process_description(allocator, line.items, original_language, language, file_out.writer());
            },
            '>' => {
                try process_summary(allocator, line.items, original_language, language, file_out.writer());
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

fn process_summary(allocator: Allocator, source_string: []const u8, original_language: []const u8, language: []const u8, writer: std.fs.File.Writer) !void {
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
        try process_description(allocator, source_string, original_language, language, writer);
    }
}

fn process_execution(source_string: []const u8, writer: std.fs.File.Writer) !void {
    const t1 = [_]Replacement{
        Replacement{ .original = "path/to/file_or_directory", .replacement = "ruta/al/archivo_o_directorio" },
        Replacement{ .original = "path/to/target/directory", .replacement = "ruta/al/directorio/destino" },
        Replacement{ .original = "path/to/directory", .replacement = "ruta/al/directorio" },
        Replacement{ .original = "path/to/file", .replacement = "ruta/al/archivo" },
        Replacement{ .original = "path/to/binary", .replacement = "ruta/al/binario" },
        Replacement{ .original = "path/to/image", .replacement = "ruta/a/la/imagen" },
        Replacement{ .original = "path/to/input_file", .replacement = "ruta/al/archivo_de_entrada" },
        Replacement{ .original = "path/to/output_file", .replacement = "ruta/al/archivo_resultado" },
        Replacement{ .original = "path/to/output", .replacement = "ruta/al/resultado" },
        Replacement{ .original = "path/to/input", .replacement = "ruta/a/la/entrada" },
        Replacement{ .original = "path/to/", .replacement = "ruta/a/" },
        Replacement{ .original = "project_name", .replacement = "nombre_del_proyecto" },
        Replacement{ .original = "branch_name", .replacement = "nombre_de_la_rama" },
        Replacement{ .original = "regular_expression", .replacement = "expresión_regular" },
        Replacement{ .original = "remote_host", .replacement = "equipo_remoto" },
        Replacement{ .original = "search_pattern", .replacement = "patrón_de_búsqueda" },
        Replacement{ .original = "remote_name", .replacement = "nombre_remoto" },
        Replacement{ .original = "package_name", .replacement = "nombre_del_paquete" },
        Replacement{ .original = "database_name", .replacement = "nombre_base_de_datos" },
        Replacement{ .original = "container_name", .replacement = "nombre_del_contenedor" },
        Replacement{ .original = "task_id", .replacement = "número_de_tarea" },
        Replacement{ .original = "table_name", .replacement = "nombre_de_la_tabla" },
        Replacement{ .original = "service_name", .replacement = "nombre_del_servicio" },
        Replacement{ .original = "ip_address", .replacement = "dirección_ip" },
        Replacement{ .original = "profile_name", .replacement = "nombre_del_perfil" },
        Replacement{ .original = "module_name", .replacement = "nombre_del_módulo" },
        Replacement{ .original = "app_name", .replacement = "nombre_de_la_aplicación" },
        Replacement{ .original = "group_name", .replacement = "nombre_del_grupo" },
        Replacement{ .original = "command_arguments", .replacement = "argumentos_del_comando" },
        Replacement{ .original = "search_string", .replacement = "cadena_de_búsqueda" },
        Replacement{ .original = "cluster_name", .replacement = "nombre_del_grupo" },
        Replacement{ .original = "repository_name", .replacement = "nombre_del_repositorio" },
        Replacement{ .original = "process_name", .replacement = "nombre_del_proceso" },
        Replacement{ .original = "package1", .replacement = "paquete1" },
        Replacement{ .original = "package2", .replacement = "paquete2" },
        Replacement{ .original = "image_name", .replacement = "nombre_de_la_imagen" },
        Replacement{ .original = "argument1", .replacement = "primer_argumento" },
        Replacement{ .original = "argument2", .replacement = "segundo_argumento" },
        Replacement{ .original = "repository_url", .replacement = "ruta_al_repositorio" },
        Replacement{ .original = "search_term", .replacement = "término_de_búsqueda" },
        Replacement{ .original = "job_id", .replacement = "id_del_trabajo" },
        Replacement{ .original = "database_id", .replacement = "id_base_de_datos" },
        Replacement{ .original = "node_version", .replacement = "versión_de_node" },
        Replacement{ .original = "{{pattern}}", .replacement = "{{patrón}}" },
        Replacement{ .original = "{{command}}", .replacement = "{{comando}}" },
        Replacement{ .original = "{{package}}", .replacement = "{{paquete}}" },
        Replacement{ .original = "{{username}}", .replacement = "{{usuario}}" },
        Replacement{ .original = "{{name}}", .replacement = "{{nombre}}" },
        Replacement{ .original = "{{password}}", .replacement = "{{contraseña}}" },
        Replacement{ .original = "{{value}}", .replacement = "{{valor}}" },
        Replacement{ .original = "{{hostname}}", .replacement = "{{nombre_del_equipo}}" },
        Replacement{ .original = "{{host}}", .replacement = "{{equipo}}" },
        Replacement{ .original = "{{port}}", .replacement = "{{puerto}}" },
        Replacement{ .original = "{{version}}", .replacement = "{{versión}}" },
        Replacement{ .original = "{{user}}", .replacement = "{{usuario}}" },
        Replacement{ .original = "{{subcommand}}", .replacement = "{{subcomando}}" },
        Replacement{ .original = "{{string}}", .replacement = "{{cadena}}" },
        Replacement{ .original = "{{message}}", .replacement = "{{mensaje}}" },
        Replacement{ .original = "{{width}}", .replacement = "{{ancho}}" },
        Replacement{ .original = "{{filename}}", .replacement = "{{archivo}}" },
        Replacement{ .original = "{{number}}", .replacement = "{{número}}" },
        Replacement{ .original = "{{pattern}}", .replacement = "{{patrón}}" },
        Replacement{ .original = "{{keyword}}", .replacement = "{{palabra_clave}}" },
        Replacement{ .original = "{{image}}", .replacement = "{{imagen}}" },
        Replacement{ .original = "{{target}}", .replacement = "{{objetivo}}" },
        Replacement{ .original = "{{repository}}", .replacement = "{{repositorio}}" },
        Replacement{ .original = "{{interface}}", .replacement = "{{interfaz}}" },
        Replacement{ .original = "{{id}}", .replacement = "{{identificador}}" },
        Replacement{ .original = "{{domain}}", .replacement = "{{dominio}}" },
        Replacement{ .original = "{{text}}", .replacement = "{{texto}}" },
        Replacement{ .original = "{{query}}", .replacement = "{{consulta}}" },
        Replacement{ .original = "{{program}}", .replacement = "{{programa}}" },
        Replacement{ .original = "{{count}}", .replacement = "{{cantidad}}" },
        Replacement{ .original = "{{seconds}}", .replacement = "{{segundos}}" },
        Replacement{ .original = "{{file}}", .replacement = "{{archivo}}" },
        Replacement{ .original = "{{container}}", .replacement = "{{contenedor}}" },
        Replacement{ .original = "{{region}}", .replacement = "{{región}}" },
        Replacement{ .original = "{{path}}", .replacement = "{{ruta}}" },
        Replacement{ .original = "{{title}}", .replacement = "{{título}}" },
        Replacement{ .original = "{{prefix}}", .replacement = "{{prefijo}}" },
        Replacement{ .original = "{{owner}}", .replacement = "{{propietario}}" },
        Replacement{ .original = "{{group}}", .replacement = "{{grupo}}" },
        Replacement{ .original = "{{address}}", .replacement = "{{dirección}}" },
    };
    var buffer: [1024]u8 = undefined;
    const result = replacemany(source_string, &t1, buffer[0..]);
    try writer.print("{s}", .{buffer[0..result.size]});
    if (buffer[result.size - 1] != '\n') {
        _ = try writer.write("\n");
    }
}

fn process_description(allocator: Allocator, source_string: []const u8, original_language: []const u8, language: []const u8, writer: std.fs.File.Writer) !void {
    var slice: []u8 = undefined;
    slice = try translateline(allocator, source_string[2..], original_language, language);
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

const translateline = translatelineapi;

fn translatelineapi(allocator: Allocator, source_string: []const u8, original_language: []const u8, language: []const u8) ![]u8 {
    var client = http.Client{ .allocator = allocator };
    defer client.deinit();

    const uri = try std.Uri.parse(translation_api);
    const escaped_for_json = try escapeJsonString(source_string, allocator);
    defer allocator.free(escaped_for_json);
    const payload = try std.fmt.allocPrint(allocator, "{{\"text\": \"{s}\", \"from_lang\": \"{s}\", \"to_lang\": \"{s}\"}}", .{ escaped_for_json, original_language, language[0..2] });
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

    var rdr = req.reader();
    const body = try rdr.readAllAlloc(allocator, 1024 * 1024 * 4);
    defer allocator.free(body);

    if (req.response.status != .ok) {
        logerr("The API is not prepared for what you asked for. Status:{d}\nPayload:{s}\nResponse:{s}", .{ req.response.status, payload, body });
        return ArgosApiError.LangNotFound;
    }

    const Translated_text = struct { translated_text: []u8 };
    const parsed = try std.json.parseFromSlice(Translated_text, allocator, body, .{});
    defer parsed.deinit();

    const json_res = parsed.value;

    return allocator.dupe(u8, json_res.translated_text);
}
