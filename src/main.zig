const std = @import("std");
const builtin = @import("builtin");
const rl = @import("raylib");
const rg = @import("raygui");
const render = @import("render.zig");
const lex = @import("lexer.zig").lex;
const parse = @import("ast.zig");
const Token = @import("token.zig").Token;
const MeasureTree = @import("measure.zig").MeasuredAstNode;

pub fn main() !void {
    var debug_allocator = std.heap.DebugAllocator(.{}).init;
    const gpa, const is_debug_alloc = switch (builtin.mode) {
        .Debug, .ReleaseSafe => .{ debug_allocator.allocator(), true },
        .ReleaseFast, .ReleaseSmall => .{ std.heap.smp_allocator, false },
    };
    defer {
        if (is_debug_alloc) _ = debug_allocator.deinit();
    }

    var buffer: [2048]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buffer);
    const fixed_allocator = fba.allocator();

    rl.setTraceLogLevel(.err);
    rl.initWindow(render.screen_width, render.screen_height, "Pratt Parsing");
    defer rl.closeWindow();
    rl.setWindowState(.{ .window_resizable = true });
    rl.setTargetFPS(render.frames_per_second);

    const bin_path = try std.fs.selfExeDirPathAlloc(fixed_allocator);
    defer fixed_allocator.free(bin_path);
    const font_path = try std.mem.concatWithSentinel(fixed_allocator, u8, &.{
        bin_path,
        "/../../data/LiberationMono-Bold.ttf",
    }, 0);
    defer fixed_allocator.free(font_path);
    const font = try rl.loadFont(font_path);

    var ast: parse.AstNode = try .init(.initSpecial(.end_of_statement), gpa);
    defer ast.deinit(gpa);
    while (!rl.windowShouldClose()) : ({
        render.frame_counter += 1;
        render.screen_width = rl.getScreenWidth();
        render.screen_height = rl.getScreenHeight();
    }) {
        rl.beginDrawing();
        defer rl.endDrawing();
        rl.clearBackground(.ray_white);

        render.renderParsedbox(font);
        if (render.updateTextBox()) |text| {
            const new_ast = lexAndParse(text, gpa) catch try parse.AstNode.init(.initSpecial(.end_of_statement), gpa);
            ast.deinit(gpa);
            ast = new_ast;
            try render.updateParsedText(ast);
        }

        try MeasureTree.render(ast, font, 20, 150, gpa);
    }
}

pub fn lexAndParse(str: []const u8, allocator: std.mem.Allocator) !parse.AstNode {
    const tokens: []Token = try lex(str, allocator);
    defer allocator.free(tokens);
    defer for (tokens) |token| token.deinit(allocator);
    var parse_state = parse.ParsingState.init(tokens, allocator);
    const ast: parse.AstNode = try parse.parseExpression(&parse_state, 0);
    return ast;
}

test "test index" {
    _ = @import("lexer.zig");
    _ = @import("token.zig");
    _ = @import("ast.zig");
}
