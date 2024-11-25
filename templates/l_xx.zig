/// Definitions for es translations
const tldr_base = @import("tldr-base.zig");
const Replacement = tldr_base.Replacement;
const LangReplacement = tldr_base.LangReplacement;
const identityFn = tldr_base.identityFn;

/// These replacements are for sample execution, the lines that show the invocation
/// Of the command, those that start with ``` and end with ```
/// Firts list the more particular ones that can be replaced many times
/// Then show the replacements of complete arguments
/// To extract the most repeated expressions on sample execution commands we used:
/// cat pages/{openbsd,netbsd,sunos,common,linux,windows,android,freebsd,osx}/*.md | grep -oP '(?<=[{][{])[^}}]*'|sort | uniq -c |  sort -g -r | head -200 | less
const process_replacements = [_]Replacement{
    Replacement{ .original = "path/to/file_or_directory", .replacement = "" },
    Replacement{ .original = "path/to/target/directory", .replacement = "" },
    Replacement{ .original = "path/to/directory", .replacement = "" },
    Replacement{ .original = "path/to/file", .replacement = "" },
    Replacement{ .original = "path/to/binary", .replacement = "" },
    Replacement{ .original = "path/to/image", .replacement = "" },
    Replacement{ .original = "path/to/input_file", .replacement = "" },
    Replacement{ .original = "path/to/output_file", .replacement = "" },
    Replacement{ .original = "path/to/output", .replacement = "" },
    Replacement{ .original = "path/to/input", .replacement = "" },
    Replacement{ .original = "path/to/", .replacement = "" },
    Replacement{ .original = "project_name", .replacement = "" },
    Replacement{ .original = "branch_name", .replacement = "" },
    Replacement{ .original = "regular_expression", .replacement = "" },
    Replacement{ .original = "remote_host", .replacement = "" },
    Replacement{ .original = "search_pattern", .replacement = "" },
    Replacement{ .original = "remote_name", .replacement = "" },
    Replacement{ .original = "package_name", .replacement = "" },
    Replacement{ .original = "database_name", .replacement = "" },
    Replacement{ .original = "container_name", .replacement = "" },
    Replacement{ .original = "task_id", .replacement = "" },
    Replacement{ .original = "table_name", .replacement = "" },
    Replacement{ .original = "service_name", .replacement = "" },
    Replacement{ .original = "ip_address", .replacement = "" },
    Replacement{ .original = "profile_name", .replacement = "" },
    Replacement{ .original = "module_name", .replacement = "" },
    Replacement{ .original = "app_name", .replacement = "" },
    Replacement{ .original = "group_name", .replacement = "" },
    Replacement{ .original = "command_arguments", .replacement = "" },
    Replacement{ .original = "search_string", .replacement = "" },
    Replacement{ .original = "cluster_name", .replacement = "" },
    Replacement{ .original = "repository_name", .replacement = "" },
    Replacement{ .original = "process_name", .replacement = "" },
    Replacement{ .original = "package1", .replacement = "" },
    Replacement{ .original = "package2", .replacement = "" },
    Replacement{ .original = "image_name", .replacement = "" },
    Replacement{ .original = "argument1", .replacement = "" },
    Replacement{ .original = "argument2", .replacement = "" },
    Replacement{ .original = "repository_url", .replacement = "" },
    Replacement{ .original = "search_term", .replacement = "" },
    Replacement{ .original = "job_id", .replacement = "" },
    Replacement{ .original = "database_id", .replacement = "" },
    Replacement{ .original = "node_version", .replacement = "" },
    Replacement{ .original = "{{pattern}}", .replacement = "" },
    Replacement{ .original = "{{command}}", .replacement = "" },
    Replacement{ .original = "{{package}}", .replacement = "" },
    Replacement{ .original = "{{username}}", .replacement = "" },
    Replacement{ .original = "{{name}}", .replacement = "" },
    Replacement{ .original = "{{password}}", .replacement = "" },
    Replacement{ .original = "{{value}}", .replacement = "" },
    Replacement{ .original = "{{hostname}}", .replacement = "" },
    Replacement{ .original = "{{host}}", .replacement = "" },
    Replacement{ .original = "{{port}}", .replacement = "" },
    Replacement{ .original = "{{version}}", .replacement = "" },
    Replacement{ .original = "{{user}}", .replacement = "" },
    Replacement{ .original = "{{subcommand}}", .replacement = "" },
    Replacement{ .original = "{{string}}", .replacement = "" },
    Replacement{ .original = "{{message}}", .replacement = "" },
    Replacement{ .original = "{{width}}", .replacement = "" },
    Replacement{ .original = "{{filename}}", .replacement = "" },
    Replacement{ .original = "{{number}}", .replacement = "" },
    Replacement{ .original = "{{pattern}}", .replacement = "" },
    Replacement{ .original = "{{keyword}}", .replacement = "" },
    Replacement{ .original = "{{image}}", .replacement = "" },
    Replacement{ .original = "{{target}}", .replacement = "" },
    Replacement{ .original = "{{repository}}", .replacement = "" },
    Replacement{ .original = "{{interface}}", .replacement = "" },
    Replacement{ .original = "{{id}}", .replacement = "" },
    Replacement{ .original = "{{domain}}", .replacement = "" },
    Replacement{ .original = "{{text}}", .replacement = "" },
    Replacement{ .original = "{{query}}", .replacement = "" },
    Replacement{ .original = "{{program}}", .replacement = "" },
    Replacement{ .original = "{{count}}", .replacement = "" },
    Replacement{ .original = "{{seconds}}", .replacement = "" },
    Replacement{ .original = "{{file}}", .replacement = "" },
    Replacement{ .original = "{{container}}", .replacement = "" },
    Replacement{ .original = "{{region}}", .replacement = "" },
    Replacement{ .original = "{{path}}", .replacement = "" },
    Replacement{ .original = "{{title}}", .replacement = "" },
    Replacement{ .original = "{{prefix}}", .replacement = "" },
    Replacement{ .original = "{{owner}}", .replacement = "" },
    Replacement{ .original = "{{group}}", .replacement = "" },
    Replacement{ .original = "{{address}}", .replacement = "" },
};

const summary_replacements = [_]Replacement{
    Replacement{ .original = "> More information", .replacement = "> " },
    Replacement{ .original = "> See also:", .replacement = "> :" },
    Replacement{ .original = "> This command is an alias of", .replacement = "> " },
    Replacement{ .original = "> View documentation for the original command", .replacement = "> " },
};

const sr: []const Replacement = summary_replacements[0..];
const pr: []const Replacement = process_replacements[0..];

pub const l_xx: LangReplacement = .{ .summary_replacement = sr, .process_replacement = pr, .fixPostTranslation = &identityFn };
