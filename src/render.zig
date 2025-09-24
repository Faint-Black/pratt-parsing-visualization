const std = @import("std");
const rl = @import("raylib");
const rg = @import("raygui");
const lex = @import("lexer.zig").lex;
const parse = @import("ast.zig");
const Token = @import("token.zig").Token;

pub var screen_width: i32 = 400;
pub var screen_height: i32 = 450;
pub const frames_per_second = 60;
pub var frame_counter: u64 = 0;

/// buffer[0] -> previous state
/// buffer[1] -> new state
var textbox_internal_buffers: [2][512]u8 = std.mem.zeroes([2][512]u8);

var parsedbox_internal_buffer: [512]u8 = std.mem.zeroes([512]u8);
var parsedbox_text: [:0]const u8 = &.{};

pub fn renderParsedbox(font: rl.Font) void {
    if (parsedbox_text.len == 0) return;
    rl.drawTextEx(
        font,
        parsedbox_text,
        rl.Vector2{ .x = 10.0, .y = 80.0 },
        20,
        0,
        .black,
    );
}

/// renders and returns a readable slice of the textbox contents
/// returns null if the textbox contents have not changed
pub fn updateTextBox() ?[]const u8 {
    const raw_pointer_0: [:0]u8 = @ptrCast(&textbox_internal_buffers[0]);
    const raw_pointer_1: [:0]u8 = @ptrCast(&textbox_internal_buffers[1]);
    const textbox_pos_x = 10;
    const textbox_pos_y = 10;
    const textbox_rect = rl.Rectangle{
        .x = textbox_pos_x,
        .y = textbox_pos_y,
        .width = @floatFromInt(screen_width - textbox_pos_x * 2),
        .height = 50,
    };
    @memcpy(textbox_internal_buffers[0][0..], textbox_internal_buffers[1][0..]);
    _ = rg.textBox(textbox_rect, raw_pointer_1, textbox_internal_buffers[0].len - 1, true);
    const sentinel_pos_0 = std.mem.indexOfSentinel(u8, 0, raw_pointer_0);
    const sentinel_pos_1 = std.mem.indexOfSentinel(u8, 0, raw_pointer_1);
    if (std.mem.eql(
        u8,
        textbox_internal_buffers[0][0..sentinel_pos_0],
        textbox_internal_buffers[1][0..sentinel_pos_1],
    )) {
        return null;
    } else {
        return textbox_internal_buffers[1][0..sentinel_pos_1];
    }
}

pub fn updateParsedText(ast: parse.AstNode) !void {
    var writer = std.Io.Writer.fixed(&parsedbox_internal_buffer);
    try ast.fmtLisp(&writer);
    try writer.writeByte(0);
    parsedbox_text = @ptrCast(writer.buffered());
}

pub fn renderAST(
    ast: parse.AstNode,
    x: i32,
    y: i32,
    font: rl.Font,
    allocator: std.mem.Allocator,
) !void {
    var buffer: [64]u8 = std.mem.zeroes([64]u8);
    var writer = std.Io.Writer.fixed(&buffer);
    try ast.token.fmtSymbol(&writer);
    var font_size: f32 = undefined;
    if (ast.token.token_type == .identifier) {
        font_size = 16;
    } else {
        font_size = 32;
    }
    const font_spacing = 0;
    const ast_text: [:0]u8 = try allocator.dupeZ(u8, writer.buffered());
    defer allocator.free(ast_text);
    const text_dimensions = rl.measureTextEx(font, ast_text, font_size, font_spacing);
    for (0..ast.children.len) |i| {
        const height_separation = 70;
        const width_separation = 100;
        var separation: i32 = undefined;
        if (ast.children.len == 1) {
            separation = 0;
        } else {
            separation = @divFloor(
                width_separation,
                @as(i32, @intCast(ast.children.len - 1)),
            );
        }
        var x_final: i32 = undefined;
        if (separation == 0) {
            x_final = x;
        } else {
            x_final = (x + separation * @as(i32, @intCast(i))) - (width_separation / 2);
        }
        const line_start_pos = rl.Vector2{
            .x = @floatFromInt(x),
            .y = @floatFromInt(y),
        };
        const line_end_pos = rl.Vector2{
            .x = @floatFromInt(x_final),
            .y = @floatFromInt(y + height_separation),
        };
        rl.drawLineEx(line_start_pos, line_end_pos, 3.0, .black);
        try renderAST(ast.children[i], x_final, y + height_separation, font, allocator);
    }
    rl.drawCircle(x, y, 30, .black);
    rl.drawCircle(x, y, 28, tokenColor(ast.token.token_type));
    const text_pos = rl.Vector2{
        .x = @as(f32, @floatFromInt(x)) - text_dimensions.x / 2.0,
        .y = @as(f32, @floatFromInt(y)) - text_dimensions.y / 2.0,
    };
    rl.drawTextEx(font, ast_text, text_pos, font_size, font_spacing, .black);
}

fn tokenColor(token_type: Token.TokenType) rl.Color {
    return switch (parse.AstNode.AstNodeType.fromTokenType(token_type)) {
        .unary_operation => .orange,
        .binary_operation => .purple,
        .identifier => .blue,
        .literal => .sky_blue,
        .special => .white,
    };
}
