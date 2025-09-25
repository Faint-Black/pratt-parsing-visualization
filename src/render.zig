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

pub const RenderAST = struct {
    pub fn render(ast: parse.AstNode, font: rl.Font, allocator: std.mem.Allocator) !void {
        var measures = try AstNodeMeasures.init(ast, allocator);
        defer measures.deinit(allocator);
        const root_width = try measures.measureSubtreeWidth(font);
        const diff = @as(f32, @floatFromInt(screen_width)) - root_width;
        const centered_x = diff / 2;
        renderNodeRecursive(
            centered_x,
            (@as(f32, @floatFromInt(screen_height)) / 3.0),
            measures,
            font,
        );
    }

    fn renderNode(node: AstNodeMeasures, x: f32, y: f32, font: rl.Font) void {
        var alloc_buffer: [256]u8 = undefined;
        var write_buffer: [256]u8 = undefined;
        var writer = std.Io.Writer.fixed(&write_buffer);
        var fba = std.heap.FixedBufferAllocator.init(&alloc_buffer);
        const allocator = fba.allocator();

        node.ast_node.token.fmtSymbol(&writer) catch unreachable;
        const font_size: f32 = if (node.ast_node.token.token_type == .identifier) 18 else 32;
        const ast_text: [:0]const u8 = allocator.dupeZ(u8, writer.buffered()) catch "ERROR";
        defer allocator.free(ast_text);
        const text_dimensions = rl.measureTextEx(font, ast_text, font_size, 0);
        const padding = 15;
        const circle_radius = (text_dimensions.x / 2) + padding;
        const int_x: i32 = @intFromFloat(x);
        const int_y: i32 = @intFromFloat(y);
        rl.drawCircle(int_x, int_y, circle_radius, .black);
        rl.drawCircle(int_x, int_y, circle_radius - 2, tokenColor(node.ast_node.token.token_type));
        const text_pos = rl.Vector2{
            .x = x - text_dimensions.x / 2.0,
            .y = y - text_dimensions.y / 2.0,
        };
        rl.drawTextEx(font, ast_text, text_pos, font_size, 0, .black);
    }

    fn renderNodeRecursive(x: f32, y: f32, node: AstNodeMeasures, font: rl.Font) void {
        const render_x = x + (node.subtree_width / 2.0);
        const render_y = y;
        for (node.children, 0..) |child, i| {
            const child_x: f32 = x + attributeEvenly(node.subtree_width, node.children.len, i);
            const child_y: f32 = y + 75;
            rl.drawLineEx(
                .{ .x = render_x, .y = render_y },
                .{ .x = child_x + (child.subtree_width / 2.0), .y = child_y },
                3,
                .black,
            );
            renderNodeRecursive(child_x, child_y, child, font);
        }
        renderNode(node, render_x, render_y, font);
    }

    const AstNodeMeasures = struct {
        children: []AstNodeMeasures,
        ast_node: parse.AstNode,
        subtree_width: f32,

        fn init(ast: parse.AstNode, allocator: std.mem.Allocator) !AstNodeMeasures {
            var result: AstNodeMeasures = undefined;
            result.children = try allocator.alloc(AstNodeMeasures, ast.children.len);
            for (ast.children, 0..) |child, i| {
                result.children[i] = try AstNodeMeasures.init(child, allocator);
            }
            result.ast_node = ast;
            return result;
        }

        fn deinit(self: AstNodeMeasures, allocator: std.mem.Allocator) void {
            for (self.children) |child| child.deinit(allocator);
            allocator.free(self.children);
        }

        /// recursively measure the total subtree widths
        fn measureSubtreeWidth(self: *AstNodeMeasures, font: rl.Font) !f32 {
            if (self.children.len == 0) {
                self.subtree_width = try self.nodeWidth(font);
            } else {
                const spacing = 20;
                var accumulator: f32 = 0;
                for (self.children) |*child| accumulator += try child.measureSubtreeWidth(font);
                accumulator += spacing * @as(f32, @floatFromInt(self.children.len));
                self.subtree_width = @max(accumulator, try self.nodeWidth(font));
            }
            return self.subtree_width;
        }

        fn nodeWidth(self: AstNodeMeasures, font: rl.Font) !f32 {
            var alloc_buffer: [256]u8 = undefined;
            var write_buffer: [256]u8 = undefined;
            var writer = std.Io.Writer.fixed(&write_buffer);
            var fba = std.heap.FixedBufferAllocator.init(&alloc_buffer);
            const allocator = fba.allocator();
            try self.ast_node.token.fmtSymbol(&writer);
            const font_size: f32 = if (self.ast_node.token.token_type == .identifier) 18 else 32;
            const ast_text: [:0]const u8 = try allocator.dupeZ(u8, writer.buffered());
            const dimensions = rl.measureTextEx(font, ast_text, font_size, 0);
            const padding = 5;
            return dimensions.x + padding;
        }
    };
};

fn tokenColor(token_type: Token.TokenType) rl.Color {
    return switch (parse.AstNode.AstNodeType.fromTokenType(token_type)) {
        .unary_operation => .pink,
        .binary_operation => .purple,
        .identifier => .blue,
        .literal => .sky_blue,
        .special => .white,
    };
}

fn attributeEvenly(width: f32, count: usize, index: usize) f32 {
    std.debug.assert(count != 0);
    if (count == 1) return width / 2;
    const offset = width / @as(f32, @floatFromInt(count - 1));
    return offset * @as(f32, @floatFromInt(index));
}
