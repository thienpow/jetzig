const std = @import("std");
const args = @import("args");
const util = @import("../util.zig");

/// Command line options for the `update` command.
pub const Options = struct {
    pub const meta = .{
        .usage_summary = "[password]",
        .full_text =
        \\Generates a password
        \\Example:
        \\
        \\  jetzig update
        \\  jetzig update web
        ,
        .option_docs = .{
            .path = "Set the output path relative to the current directory (default: current directory)",
        },
    };
};

/// Run the `jetzig database` command.
pub fn run(
    parent_allocator: std.mem.Allocator,
    options: Options,
    writer: anytype,
    T: type,
    main_options: T,
) !void {
    _ = options;
    var arena = std.heap.ArenaAllocator.init(parent_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const Action = enum { user_create };
    const map = std.StaticStringMap(Action).initComptime(.{
        .{ "user:create", .user_create },
    });

    const action = if (main_options.positionals.len > 0)
        map.get(main_options.positionals[0])
    else
        null;
    const sub_args: []const []const u8 = if (main_options.positionals.len > 1)
        main_options.positionals[1..]
    else
        &.{};

    return if (main_options.options.help and action == null) blk: {
        try args.printHelp(Options, "jetzig database", writer);
        break :blk {};
    } else if (action == null) blk: {
        const available_help = try std.mem.join(allocator, "|", map.keys());
        std.debug.print("Missing sub-command. Expected: [{s}]\n", .{available_help});
        break :blk error.JetzigCommandError;
    } else if (action) |capture|
        switch (capture) {
            .user_create => blk: {
                if (sub_args.len < 1) {
                    std.debug.print("Missing argument. Expected an email/username parameter.\n", .{});
                    break :blk error.JetzigCommandError;
                } else {
                    var argv = std.ArrayList([]const u8).init(allocator);
                    try argv.append("zig");
                    try argv.append("build");
                    try argv.append(util.environmentBuildOption(main_options.options.environment));
                    try argv.append(try std.mem.concat(allocator, u8, &.{ "-Dauth_username=", sub_args[0] }));
                    if (sub_args.len > 1) {
                        try argv.append(try std.mem.concat(allocator, u8, &.{ "-Dauth_password=", sub_args[1] }));
                    }
                    try argv.append("jetzig:auth:user:create");
                    try util.execCommand(allocator, argv.items);
                }
            },
        };
}
