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

pub fn updateParsedText(str: []const u8, allocator: std.mem.Allocator) !void {
    var writer = std.Io.Writer.fixed(&parsedbox_internal_buffer);
    const tokens: []Token = try lex(str, allocator);
    defer allocator.free(tokens);
    var parse_state = parse.ParsingState{
        .allocator = allocator,
        .counter = 0,
        .tokens = tokens,
    };
    const ast: parse.AstNode = parse.parseExpression(&parse_state, 0) catch try parse.AstNode.init(Token.initSpecial(.end_of_line), allocator);
    defer ast.deinit(allocator);
    try ast.fmtLisp(&writer);
    try writer.writeByte(0);
    parsedbox_text = @ptrCast(writer.buffered());
}
