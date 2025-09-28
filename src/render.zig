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
    rl.drawRectangle(0, 110, screen_width, 2, .light_gray);
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

pub fn tokenColor(token_type: Token.TokenType) rl.Color {
    return switch (parse.AstNode.AstNodeType.fromTokenType(token_type)) {
        .prefix_operation => .pink,
        .infix_operation => .purple,
        .postfix_operation => .magenta,
        .identifier => .blue,
        .literal => .sky_blue,
        .special => .white,
    };
}
