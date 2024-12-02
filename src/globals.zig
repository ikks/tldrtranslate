pub var global_config = GlobalConfiguration{};

pub const GlobalConfiguration = struct {
    translation_api: []const u8 = &.{},
    database_spanish_conjugation_fix: []const u8 = &.{},
    output_with_colors: bool = true,
};
