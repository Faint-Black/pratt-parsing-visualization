const std = @import("std");
const Token = @import("token.zig").Token;

pub const ParsingState = struct {
    tokens: []const Token,
    counter: usize,
    allocator: std.mem.Allocator,

    pub fn consume(self: *ParsingState) !Token {
        if (self.counter >= self.tokens.len) return error.OOB;
        const tmp = self.tokens[self.counter];
        self.counter += 1;
        return tmp;
    }

    pub fn peek(self: *ParsingState) !Token {
        if (self.counter >= self.tokens.len) return error.OOB;
        return self.tokens[self.counter];
    }

    pub fn advance(self: *ParsingState) void {
        self.counter += 1;
    }
};

pub const AstNode = struct {
    token: Token,
    children: []AstNode,

    pub const AstNodeType = enum {
        binary_operation,
        unary_operation,
        identifier,
        literal,
        special,

        pub fn fromTokenType(token_type: Token.TokenType) AstNodeType {
            return switch (token_type) {
                .end_of_line => .special,
                .identifier => .identifier,
                .literal_number => .literal,
                .l_paren => .special,
                .r_paren => .special,
                .assignment => .binary_operation,
                .sum => .binary_operation,
                .subtraction => .binary_operation,
                .multiplication => .binary_operation,
                .division => .binary_operation,
                .negation => .unary_operation,
                .boolean_and => .binary_operation,
                .boolean_or => .binary_operation,
            };
        }
    };

    /// automatically makes a copy of the input token
    pub fn init(token: Token, allocator: std.mem.Allocator) !AstNode {
        return AstNode{
            .token = try Token.copy(token, allocator),
            .children = try allocator.alloc(AstNode, 0),
        };
    }

    /// recursive deinit, call for root only
    pub fn deinit(self: AstNode, allocator: std.mem.Allocator) void {
        for (self.children) |child| child.deinit(allocator);
        self.token.deinit(allocator);
        allocator.free(self.children);
    }

    pub fn addChildToken(self: *AstNode, token: Token, allocator: std.mem.Allocator) !void {
        var new_children_array = try allocator.alloc(AstNode, self.children.len + 1);
        for (0..self.children.len) |i| new_children_array[i] = self.children[i];
        new_children_array[self.children.len] = try AstNode.init(token, allocator);
        allocator.free(self.children);
        self.children = new_children_array;
    }

    pub fn addChildNode(self: *AstNode, node: AstNode, allocator: std.mem.Allocator) !void {
        var new_children_array = try allocator.alloc(AstNode, self.children.len + 1);
        for (0..self.children.len) |i| new_children_array[i] = self.children[i];
        new_children_array[self.children.len] = node;
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

pub fn parseExpression(parse_state: *ParsingState, rbp: i32) anyerror!AstNode {
    var current_token = try parse_state.consume();
    var left_node = try nud(parse_state, current_token);
    errdefer left_node.deinit(parse_state.allocator);
    while (rbp < (try parse_state.peek()).token_type.leftBindingPower()) {
        current_token = try parse_state.consume();
        if (current_token.token_type.associativity() == 'L') {
            left_node = try led(parse_state, current_token, left_node);
        }
    }
    return left_node;
}

fn nud(parse_state: *ParsingState, current: Token) anyerror!AstNode {
    var result_node: AstNode = undefined;
    if (current.token_type == .l_paren) {
        result_node = try parseExpression(parse_state, 0);
        parse_state.advance(); // skip closing paren
        return result_node;
    }
    if (current.token_type == .negation) {
        const right = try parseExpression(parse_state, current.token_type.leftBindingPower());
        result_node = try AstNode.init(current, parse_state.allocator);
        try result_node.addChildNode(right, parse_state.allocator);
        return result_node;
    }
    result_node = try AstNode.init(current, parse_state.allocator);
    return result_node;
}

fn led(parse_state: *ParsingState, current: Token, left: AstNode) anyerror!AstNode {
    var result_node = try AstNode.init(current, parse_state.allocator);
    const right = try parseExpression(parse_state, current.token_type.leftBindingPower());
    try result_node.addChildNode(left, parse_state.allocator);
    try result_node.addChildNode(right, parse_state.allocator);
    return result_node;
}

// fn red(parse_state: *ParsingState, current: Token, left: Token) Token {}

test "AST printing" {
    var buffer: [512]u8 = undefined;
    var writer = std.Io.Writer.fixed(&buffer);
    const allocator = std.testing.allocator;

    var root_node = try AstNode.init(.initSpecial(.assignment), allocator);
    defer root_node.deinit(allocator);
    const foo_token = try Token.initIdentifier("foo", allocator);
    defer foo_token.deinit(allocator);
    try root_node.addChildToken(foo_token, allocator);
    try root_node.addChildToken(.initLiteral(42), allocator);
    try root_node.fmtLisp(&writer);
    try std.testing.expectEqualStrings("(= ('foo')(42))", writer.buffered());
}

test "parsing" {
    var buffer: [512]u8 = undefined;
    var writer = std.Io.Writer.fixed(&buffer);
    const allocator = std.testing.allocator;

    // foo = 1 + 2 * 3
    const tokens = [_]Token{
        try Token.initIdentifier("foo", allocator),
        Token.initSpecial(.assignment),
        Token.initLiteral(1),
        Token.initSpecial(.sum),
        Token.initLiteral(2),
        Token.initSpecial(.multiplication),
        Token.initLiteral(3),
        Token.initSpecial(.end_of_line),
    };
    defer for (tokens) |token| token.deinit(allocator);

    var state = ParsingState{ .allocator = allocator, .counter = 0, .tokens = &tokens };
    const ast = try parseExpression(&state, 0);
    defer ast.deinit(allocator);

    try ast.fmtLisp(&writer);
    try std.testing.expectEqualStrings("(= ('foo')(+ (1)(* (2)(3))))", writer.buffered());
}
