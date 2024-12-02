/// Definitions for es translations
const builtin = @import("builtin");
const tldr_base = @import("tldr-base.zig");
const Replacement = tldr_base.Replacement;
const LangReplacement = tldr_base.LangReplacement;
const identityFn = tldr_base.identityFn;

/// These replacements are for sample execution
/// Firts list the more particular ones that can be replaced many times
/// Then show the replacements of complete arguments
/// To extract the most repeated expressions on sample execution commands we used:
/// cat pages/{openbsd,netbsd,sunos,common,linux,windows,android,freebsd,osx}/*.md | grep -oP '(?<=[{][{])[^}}]*'|sort | uniq -c |  sort -g -r | head -200 | less
const process_replacements = [_]Replacement{
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

const summary_replacements = [_]Replacement{
    Replacement{ .original = "> More information", .replacement = "> Más información" },
    Replacement{ .original = "> See also:", .replacement = "> Vea también:" },
    Replacement{ .original = "> This command is an alias of", .replacement = "> Este comando es un alias de" },
    Replacement{ .original = "> View documentation for the original command", .replacement = "> Vea la documentación para el comando original" },
};

const sr: []const Replacement = summary_replacements[0..];
const pr: []const Replacement = process_replacements[0..];

pub const l_es: LangReplacement = .{ .summary_replacement = sr, .process_replacement = pr, .fixPostTranslation = &conjugateToThird };
// To add a new translation the above line would be replaced by
// pub const l_xx: LangReplacement = .{ .summary_replacement = sr, .process_replacement = pr, .fixPostTranslation = &identityFn};

// Past this point, definitions to postprocess a translation
// In spanish we aim to make sure we follow the third person to describe command executions
// the translator usually offers imperative or indefinitive conjugations, and we wish to avoid them
// and transform the verb to singular third person.
// https://github.com/tldr-pages/tldr/blob/main/contributing-guides/style-guide.md#spanish-specific-rules

const std = @import("std");
const lmdb_helper = @import("lmdb_sup.zig");

const db_verbs_path = &@import("globals.zig").global_config.database_spanish_conjugation_fix;
const get_verb = lmdb_helper.getwordordefault;
const logErr = tldr_base.logErr;
const CombinedError = tldr_base.CombinedError;

/// Receives a sentence that can be converted to present singular third person if the first word is a verb
/// and is in indefinitive or imperative second singular person.
/// You are responsible for freeing the return value that is a transformation from the sentence.
pub fn conjugateToThird(allocator: std.mem.Allocator, sentence: []const u8) CombinedError![]const u8 {
    if (db_verbs_path.*.len == 0) {
        return try allocator.dupe(u8, sentence);
    }
    const index_separator = std.mem.indexOf(u8, sentence, " ") orelse {
        return allocator.dupe(u8, sentence);
    };
    const verb = sentence[0..index_separator];

    const normalize = try allocator.dupe(u8, verb);
    defer allocator.free(normalize);
    const wasUpper = std.ascii.isUpper(verb[0]);
    normalize[0] = std.ascii.toLower(normalize[0]);
    var conjugation: []u8 = undefined;
    if (get_verb(allocator, db_verbs_path.*, normalize)) |val| {
        conjugation = val;
    } else |err| {
        if (err == CombinedError.ENOENT or err == CombinedError.ESRCH) {
            var helper: []u8 = undefined;
            if (builtin.os.tag == .windows) {
                helper = try std.fmt.allocPrint(allocator, "Hint: Download {s}, decompress it and place it inside {s}", .{
                    "https://igor.tamarapatino.org/tldrtranslate/resources/es/data.mdb.gz", db_verbs_path.*,
                });
            } else {
                helper = try std.fmt.allocPrint(allocator, "\n{s}\n\n{s}\n\n{s}{s}\n{s}{s}", .{
                    "Hint: Run the following commands and try again:",
                    "mkdir tldr_translation.db && cd $_ && curl --remote-name https://igor.tamarapatino.org/tldrtranslate/resources/es/data.mdb.gz && gunzip data.mdb.gz && cd ..",
                    "If it fails, please download and decompress ",
                    "https://igor.tamarapatino.org/tldrtranslate/resources/es/data.mdb.gz",
                    "and place it in ",
                    db_verbs_path.*,
                });
            }
            logErr("Make sure you have access to the verb conjugation db.\n `{s}` was not found\n{s}\n", .{ db_verbs_path.*, helper });
        }
        return err;
    }
    if (wasUpper) {
        const result = try std.fmt.allocPrint(allocator, "{c}{s}{s}", .{ std.ascii.toUpper(conjugation[0]), conjugation[1..], sentence[index_separator..] });
        allocator.free(conjugation);
        return result;
    }
    const result = try std.fmt.allocPrint(allocator, "{s}{s}", .{ conjugation, sentence[index_separator..] });
    allocator.free(conjugation);
    return result;
}
