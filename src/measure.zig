const std = @import("std");
const rl = @import("raylib");
const AstNode = @import("ast.zig").AstNode;
const Token = @import("token.zig").Token;
const renderer = @import("render.zig");

const node_padding = 15;
const h_spacing = 40;
const v_spacing = 70;
const string_font_size = 24;
const symbol_font_size = 32;

pub const MeasuredAstNode = struct {
    children: []MeasuredAstNode,
    ast_node: AstNode,
    subtree_width: f32,
    x_pos: f32,
    y_pos: f32,
    x_render_pos: f32,
    y_render_pos: f32,
    font: rl.Font,

    pub fn render(ast: AstNode, font: rl.Font, x: f32, y: f32, allocator: std.mem.Allocator) !void {
        var measure_tree = try MeasuredAstNode.init(ast, font, allocator);
        defer measure_tree.deinit(allocator);
        _ = try measure_tree.measureSubtreeWidth();
        measure_tree.measurePositions(x, y);
        measure_tree.renderRecursive();
    }

    pub fn renderRecursive(self: MeasuredAstNode) void {
        const x_int: i32 = @intFromFloat(self.x_render_pos);
        const y_int: i32 = @intFromFloat(self.y_render_pos);
        for (self.children) |child| {
            const line_start = rl.Vector2{ .x = self.x_render_pos, .y = self.y_render_pos };
            const line_end = rl.Vector2{ .x = child.x_render_pos, .y = child.y_render_pos };
            rl.drawLineEx(line_start, line_end, 3, .black);
            child.renderRecursive();
        }
        const show_subtree_measurements = false;
        if (show_subtree_measurements) {
            const real_x_int: i32 = @intFromFloat(self.x_pos);
            const real_y_int: i32 = @intFromFloat(self.y_pos);
            const w_int: i32 = @intFromFloat(self.subtree_width);
            rl.drawCircle(x_int, y_int, 5, .red);
            rl.drawRectangle(real_x_int, real_y_int, w_int, 3, .blue);
        }
        self.renderNode();
    }

    fn renderNode(self: MeasuredAstNode) void {
        var alloc_buffer: [256]u8 = undefined;
        var write_buffer: [256]u8 = undefined;
        var writer = std.Io.Writer.fixed(&write_buffer);
        var fba = std.heap.FixedBufferAllocator.init(&alloc_buffer);
        const allocator = fba.allocator();

        self.ast_node.token.fmtSymbol(&writer) catch unreachable;
        const ast_text: [:0]const u8 = allocator.dupeZ(u8, writer.buffered()) catch "ERROR";
        defer allocator.free(ast_text);

        const text_dimensions = rl.measureTextEx(self.font, ast_text, self.getFontSize(), 0);
        const x_float: f32 = self.x_render_pos;
        const y_float: f32 = self.y_render_pos;
        const x_int: i32 = @intFromFloat(x_float);
        const y_int: i32 = @intFromFloat(y_float);
        const outline = 2;
        const color = renderer.tokenColor(self.ast_node.token.token_type);
        const text_pos = rl.Vector2{
            .x = x_float - (text_dimensions.x / 2.0),
            .y = y_float - (text_dimensions.y / 2.0),
        };

        if ((self.ast_node.token.token_type == .identifier) or
            (self.ast_node.token.token_type == .literal_number))
        {
            const rect_w: i32 = @intFromFloat(text_dimensions.x + node_padding);
            const rect_h: i32 = @intFromFloat(text_dimensions.y + node_padding);
            const rect_x: i32 = x_int - @divTrunc(rect_w, 2);
            const rect_y: i32 = y_int - @divTrunc(rect_h, 2);
            rl.drawRectangle(rect_x, rect_y, rect_w, rect_h, .black);
            rl.drawRectangle(rect_x + outline, rect_y + outline, rect_w - outline * 2, rect_h - outline * 2, color);
        } else {
            const circle_radius = (text_dimensions.x / 2) + node_padding;
            rl.drawCircle(x_int, y_int, circle_radius, .black);
            rl.drawCircle(x_int, y_int, circle_radius - outline, color);
        }
        rl.drawTextEx(self.font, ast_text, text_pos, self.getFontSize(), 0, .black);
    }

    pub fn init(ast: AstNode, font: rl.Font, allocator: std.mem.Allocator) !MeasuredAstNode {
        var result: MeasuredAstNode = undefined;
        result.children = try allocator.alloc(MeasuredAstNode, ast.children.len);
        for (ast.children, 0..) |child, i| {
            result.children[i] = try MeasuredAstNode.init(child, font, allocator);
        }
        result.ast_node = ast;
        result.font = font;
        return result;
    }

    pub fn deinit(self: MeasuredAstNode, allocator: std.mem.Allocator) void {
        for (self.children) |child| child.deinit(allocator);
        allocator.free(self.children);
    }

    pub fn measureSubtreeWidth(self: *MeasuredAstNode) !f32 {
        if (self.children.len == 0) {
            self.subtree_width = try self.nodeWidth();
        } else {
            var accumulator: f32 = 0;
            for (self.children) |*child| {
                accumulator += try child.measureSubtreeWidth();
            }
            accumulator += (h_spacing * @as(f32, @floatFromInt(self.children.len - 1)));
            self.subtree_width = @max(accumulator, try self.nodeWidth());
        }
        return self.subtree_width;
    }

    pub fn measurePositions(self: *MeasuredAstNode, x0: f32, y0: f32) void {
        self.x_pos = x0;
        self.y_pos = y0;
        self.x_render_pos = x0 + (self.subtree_width / 2.0);
        self.y_render_pos = y0;
        var child_x: f32 = x0;
        const child_y: f32 = y0 + v_spacing;
        for (self.children) |*child| {
            child.measurePositions(child_x, child_y);
            child_x += child.subtree_width;
            child_x += h_spacing;
        }
    }

    pub fn nodeWidth(self: MeasuredAstNode) !f32 {
        var alloc_buffer: [256]u8 = undefined;
        var write_buffer: [256]u8 = undefined;
        var writer = std.Io.Writer.fixed(&write_buffer);
        var fba = std.heap.FixedBufferAllocator.init(&alloc_buffer);
        const allocator = fba.allocator();
        try self.ast_node.token.fmtSymbol(&writer);
        const ast_text: [:0]const u8 = try allocator.dupeZ(u8, writer.buffered());
        const dimensions = rl.measureTextEx(self.font, ast_text, self.getFontSize(), 0);
        return dimensions.x + node_padding;
    }

    pub fn getFontSize(self: MeasuredAstNode) f32 {
        return if (self.ast_node.token.token_type == .identifier) string_font_size else symbol_font_size;
    }
};
