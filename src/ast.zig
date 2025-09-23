const std = @import("std");
const Token = @import("token.zig").Token;

pub const AstNode = struct {
    token: Token,
    children: []AstNode,

    pub fn init(token: Token, allocator: std.mem.Allocator) !AstNode {
        return AstNode{
            .token = token,
            .children = try allocator.alloc(AstNode, 0),
        };
    }

    /// recursive deinit, call for root only
    pub fn deinit(self: AstNode, allocator: std.mem.Allocator) void {
        for (self.children) |child| child.deinit(allocator);
        self.token.deinit(allocator);
        allocator.free(self.children);
    }

    pub fn addChild(self: *AstNode, token: Token, allocator: std.mem.Allocator) !void {
        var new_children_array = try allocator.alloc(AstNode, self.children.len + 1);
        for (0..self.children.len) |i| new_children_array[i] = self.children[i];
        new_children_array[self.children.len] = try AstNode.init(token, allocator);
        allocator.free(self.children);
        self.children = new_children_array;
    }

    pub fn fmtTree(self: AstNode, writer: *std.Io.Writer, depth: usize) !void {
        for (0..depth) |_| try writer.writeByte('|');
        _ = try writer.write("- ");
        try self.token.fmtSymbol(writer);
        try writer.writeByte('\n');
        for (self.children) |child| try child.fmt(writer, depth + 1);
    }

    pub fn fmtLisp(self: AstNode, writer: *std.Io.Writer) !void {
        try writer.writeByte('(');
        try self.token.fmtSymbol(writer);
        if (self.children.len > 0) try writer.writeByte(' ');
        for (self.children) |child| try child.fmtLisp(writer);
        try writer.writeByte(')');
    }
};

// pub fn parse(tokens: []Token) !AstNode {
//     var index: usize = 0;
// }

// fn consume(tokens: []Token, index: *usize) Token {
//     const tmp = tokens[index.*];
//     index.* += 1;
//     return tmp;
// }

// fn peek(tokens: []Token, index: *const usize) Token {
//     return tokens[index.*];
// }

// fn nud(tokens: []Token, index: *usize) AstNode {}

// fn led(tokens: []Token, index: *usize) AstNode {}

// fn red(tokens: []Token, index: *usize) AstNode {}

test "AST printing" {
    var buffer: [512]u8 = undefined;
    var writer = std.Io.Writer.fixed(&buffer);
    const allocator = std.testing.allocator;

    var root_node = try AstNode.init(.initSpecial(.assignment), allocator);
    defer root_node.deinit(allocator);
    try root_node.addChild(try .initIdentifier("foo", allocator), allocator);
    try root_node.addChild(.initLiteral(42), allocator);
    try root_node.fmtLisp(&writer);
    try std.testing.expectEqualStrings("(= ('foo')(42))", writer.buffered());
}
