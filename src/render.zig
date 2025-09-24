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

const bufsize = 2048;
var textbox_input_buffer: [bufsize]u8 = std.mem.zeroes([bufsize]u8);
var old_textbox_content: [bufsize]u8 = std.mem.zeroes([bufsize]u8);
var new_textbox_content: [bufsize]u8 = std.mem.zeroes([bufsize]u8);
var parsedbox_text_buffer: [bufsize]u8 = std.mem.zeroes([bufsize]u8);
var parsed_text_slice: [:0]const u8 = &.{};

pub fn renderParsedbox(font: rl.Font) void {
    if (parsed_text_slice.len == 0) return;
    const pos = rl.Vector2{ .x = 10.0, .y = 80.0 };
    const font_size = 20;
    const font_spacing = 0;
    rl.drawTextEx(font, parsed_text_slice, pos, font_size, font_spacing, .black);
}

/// renders and returns a readable slice of the textbox contents
/// returns null if the textbox contents have not changed
pub fn updateTextBox() ?[]const u8 {
    const character_limit = 256;
    const textbox_pos_x = 10;
    const textbox_pos_y = 10;
    const textbox_rect = rl.Rectangle{
        .x = textbox_pos_x,
        .y = textbox_pos_y,
        .width = @floatFromInt(screen_width - textbox_pos_x * 2),
        .height = 50,
    };
    @memcpy(&old_textbox_content, &new_textbox_content);
    @memset(&new_textbox_content, 0);
    const ptr = @as([:0]u8, @ptrCast(&textbox_input_buffer));
    _ = rg.textBox(textbox_rect, ptr, character_limit, true);
    const sentinel_pos = std.mem.indexOfSentinel(u8, 0, ptr);
    std.mem.copyForwards(u8, &new_textbox_content, textbox_input_buffer[0..sentinel_pos]);
    if (std.mem.eql(u8, &old_textbox_content, &new_textbox_content)) {
        return null;
    } else {
        return new_textbox_content[0..sentinel_pos];
    }
}

pub fn updateParsedText(ast: parse.AstNode) !void {
    var writer = std.Io.Writer.fixed(&parsedbox_text_buffer);
    try ast.fmtLisp(&writer);
    try writer.writeByte(0);
    const writer_slice = writer.buffered();
    const sentinel_pos = std.mem.indexOfSentinel(u8, 0, @ptrCast(writer_slice.ptr));
    parsed_text_slice = parsedbox_text_buffer[0..sentinel_pos :0];
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
    var font_size: f32 = undefined;
    if (ast.token.token_type == .identifier) {
        font_size = 18;
    } else {
        font_size = 32;
    }
    const font_spacing = 0;
    const ast_text: [:0]u8 = try allocator.dupeZ(u8, writer.buffered());
    defer allocator.free(ast_text);
    const text_dimensions = rl.measureTextEx(font, ast_text, font_size, font_spacing);
    const padding = 15;
    const circle_radius = (text_dimensions.x / 2) + padding;
    rl.drawCircle(x, y, circle_radius, .black);
    rl.drawCircle(x, y, circle_radius - 2, tokenColor(ast.token.token_type));
    const text_pos = rl.Vector2{
        .x = @as(f32, @floatFromInt(x)) - text_dimensions.x / 2.0,
        .y = @as(f32, @floatFromInt(y)) - text_dimensions.y / 2.0,
    };
    rl.drawTextEx(font, ast_text, text_pos, font_size, font_spacing, .black);
}

fn tokenColor(token_type: Token.TokenType) rl.Color {
    return switch (parse.AstNode.AstNodeType.fromTokenType(token_type)) {
        .unary_operation => .pink,
        .binary_operation => .purple,
        .identifier => .blue,
        .literal => .sky_blue,
        .special => .white,
    };
}
