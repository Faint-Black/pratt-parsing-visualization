const std = @import("std");
const builtin = @import("builtin");
const rl = @import("raylib");
const rg = @import("raygui");
const render = @import("render.zig");
const lex = @import("lexer.zig").lex;
const parse = @import("ast.zig");
const Token = @import("token.zig").Token;

pub fn main() !void {
    var debug_allocator = std.heap.DebugAllocator(.{}).init;
    const gpa, const is_debug_alloc = switch (builtin.mode) {
        .Debug, .ReleaseSafe => .{ debug_allocator.allocator(), true },
        .ReleaseFast, .ReleaseSmall => .{ std.heap.smp_allocator, false },
    };
    defer {
        if (is_debug_alloc) _ = debug_allocator.deinit();
    }

    rl.setTraceLogLevel(.err);
    rl.initWindow(render.screen_width, render.screen_height, "Pratt Parsing");
    defer rl.closeWindow();
    rl.setWindowState(.{ .window_resizable = true });
    rl.setTargetFPS(render.frames_per_second);

    const bin_path = try std.fs.selfExeDirPathAlloc(gpa);
    defer gpa.free(bin_path);
    const font_path = try std.mem.concat(
        gpa,
        u8,
        &.{
            bin_path,
            "/../../data/",
            "LiberationMono-Bold.ttf",
        },
    );
    defer gpa.free(font_path);
    const font = try rl.loadFont(@as([:0]u8, @ptrCast(font_path)));

    var ast: parse.AstNode = try .init(.initSpecial(.end_of_line), gpa);
    defer ast.deinit(gpa);
    while (!rl.windowShouldClose()) : ({
        render.frame_counter += 1;
        render.screen_width = rl.getScreenWidth();
        render.screen_height = rl.getScreenHeight();
    }) {
        rl.beginDrawing();
        defer rl.endDrawing();
        rl.clearBackground(.white);
        render.renderParsedbox(font);
        try render.renderAST(
            ast,
            @divTrunc(render.screen_width, 2),
            @divTrunc(render.screen_height, 3),
            font,
            gpa,
        );
        const textbox_contents = render.updateTextBox();
        if (textbox_contents) |text| {
            if (lexAndParse(text, gpa) catch null) |new_ast| {
                ast.deinit(gpa);
                ast = new_ast;
            }
            try render.updateParsedText(ast);
        }
    }
}

pub fn lexAndParse(str: []const u8, allocator: std.mem.Allocator) !parse.AstNode {
    const tokens: []Token = try lex(str, allocator);
    defer allocator.free(tokens);
    defer for (tokens) |token| token.deinit(allocator);

    var parse_state = parse.ParsingState{
        .allocator = allocator,
        .counter = 0,
        .tokens = tokens,
    };
    const ast: parse.AstNode = try parse.parseExpression(&parse_state, 0);
    return ast;
}

test "test index" {
    _ = @import("lexer.zig");
    _ = @import("token.zig");
    _ = @import("ast.zig");
}
