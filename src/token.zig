const std = @import("std");

pub const Token = struct {
    token_type: TokenType,
    text: ?[]u8,
    value: i32,

    pub const TokenType = enum {
        end_of_line,
        identifier,
        literal_number,
        l_paren,
        r_paren,
        assignment,
        sum,
        subtraction,
        multiplication,
        division,
        negation,
        boolean_and,
        boolean_or,

        /// {lbp, rbp}
        pub fn bindingPower(self: TokenType) struct { i32, i32 } {
            return switch (self) {
                .assignment => .{ 5, 4 },
                .sum, .subtraction => .{ 10, 10 },
                .boolean_and, .boolean_or => .{ 15, 15 },
                .multiplication, .division => .{ 20, 20 },
                .negation => .{ 0, 100 },
                else => .{ 0, 0 },
            };
        }

        /// lbp only
        pub fn leftBindingPower(self: TokenType) i32 {
            return self.bindingPower()[0];
        }

        /// rbp only
        pub fn rightBindingPower(self: TokenType) i32 {
            return self.bindingPower()[1];
        }

        /// 'L' for left leaning associativity (foo + bar, foo*, etc.)
        /// 'R' for right leaning associativity (++foo, !foo, *foo, &foo, etc.)
        pub fn associativity(self: TokenType) u8 {
            return switch (self) {
                else => 'L',
            };
        }
    };

    pub fn deinit(self: Token, allocator: std.mem.Allocator) void {
        if (self.text) |mem| allocator.free(mem);
    }

    pub fn initIdentifier(name: []const u8, allocator: std.mem.Allocator) !Token {
        return Token{
            .token_type = .identifier,
            .text = try allocator.dupe(u8, name),
            .value = 0,
        };
    }

    pub fn initLiteral(value: i32) Token {
        return Token{
            .token_type = .literal_number,
            .text = null,
            .value = value,
        };
    }

    pub fn initSpecial(token_type: TokenType) Token {
        return Token{
            .token_type = token_type,
            .text = null,
            .value = 0,
        };
    }

    pub fn eql(a: Token, b: Token) bool {
        if (a.token_type != b.token_type) return false;
        const both_types = a.token_type;
        if (both_types == .identifier) {
            if (a.text == null and b.text == null) return true;
            if (a.text != null and b.text == null) return false;
            if (a.text == null and b.text != null) return false;
            return (std.mem.eql(u8, a.text.?, b.text.?));
        }
        if (both_types == .literal_number) {
            return (a.value == b.value);
        }
        return true;
    }

    pub fn fmtText(self: Token, writer: *std.Io.Writer) !void {
        switch (self.token_type) {
            .end_of_line => _ = try writer.write("$"),
            .identifier => _ = try writer.print("IDENTIFIER='{s}'", .{self.text.?}),
            .literal_number => _ = try writer.print("NUM={}", .{self.value}),
            .l_paren => _ = try writer.write("L_PAREN"),
            .r_paren => _ = try writer.write("R_PAREN"),
            .assignment => _ = try writer.write("ASSIGNMENT"),
            .sum => _ = try writer.write("SUM"),
            .subtraction => _ = try writer.write("SUBTRACTION"),
            .multiplication => _ = try writer.write("MUL"),
            .division => _ = try writer.write("DIV"),
            .negation => _ = try writer.write("NEGATION"),
            .boolean_and => _ = try writer.write("BOOL_AND"),
            .boolean_or => _ = try writer.write("BOOL_OR"),
        }
    }

    pub fn fmtSymbol(self: Token, writer: *std.Io.Writer) !void {
        switch (self.token_type) {
            .end_of_line => try writer.writeByte('$'),
            .identifier => _ = try writer.print("'{s}'", .{self.text.?}),
            .literal_number => _ = try writer.print("{}", .{self.value}),
            .l_paren => try writer.writeByte('('),
            .r_paren => try writer.writeByte(')'),
            .assignment => try writer.writeByte('='),
            .sum => try writer.writeByte('+'),
            .subtraction => try writer.writeByte('-'),
            .multiplication => try writer.writeByte('*'),
            .division => try writer.writeByte('/'),
            .negation => try writer.writeByte('-'),
            .boolean_and => _ = try writer.write("&&"),
            .boolean_or => _ = try writer.write("||"),
        }
    }

    pub fn fmtArray(token_array: []const Token, writer: *std.Io.Writer) !void {
        var is_first: bool = true;
        _ = try writer.writeByte('[');
        for (token_array) |token| {
            if (is_first) is_first = false else _ = try writer.write(", ");
            try token.fmtText(writer);
        }
        _ = try writer.writeByte(']');
    }
};

test "token formatting" {
    var buffer: [512]u8 = undefined;
    var writer = std.Io.Writer.fixed(&buffer);
    const tokens = [_]Token{
        try Token.initIdentifier("foo", std.testing.allocator),
        Token.initSpecial(.assignment),
        Token.initLiteral(42),
        Token.initSpecial(.end_of_line),
    };
    defer for (tokens) |token| token.deinit(std.testing.allocator);
    try Token.fmtArray(&tokens, &writer);
    try std.testing.expectEqualStrings(
        "[IDENTIFIER='foo', ASSIGNMENT, NUM=42, $]",
        writer.buffered(),
    );
}

test "token comparing" {
    var buffer: [2048]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buffer);
    const allocator = fba.allocator();

    try std.testing.expect(Token.eql(
        Token.initSpecial(.sum),
        Token.initSpecial(.sum),
    ));
    try std.testing.expect(!Token.eql(
        Token.initSpecial(.subtraction),
        Token.initSpecial(.sum),
    ));
    try std.testing.expect(Token.eql(
        try Token.initIdentifier("foo", allocator),
        try Token.initIdentifier("foo", allocator),
    ));
    try std.testing.expect(!Token.eql(
        try Token.initIdentifier("foo", allocator),
        try Token.initIdentifier("bar", allocator),
    ));
    try std.testing.expect(Token.eql(
        Token.initLiteral(42),
        Token.initLiteral(42),
    ));
    try std.testing.expect(!Token.eql(
        Token.initLiteral(42),
        Token.initLiteral(1337),
    ));
}
