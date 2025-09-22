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
        multiplication,

        pub fn bindingPower(self: TokenType) i32 {
            return switch (self) {
                .end_of_line => -1,
                .assignment => 1,
                .sum => 2,
                .multiplication => 3,
                else => 0,
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

    pub fn fmt(self: Token, writer: *std.Io.Writer) !void {
        switch (self.token_type) {
            .end_of_line => _ = try writer.write("$"),
            .identifier => _ = try writer.print("IDENTIFIER='{s}'", .{self.text.?}),
            .literal_number => _ = try writer.print("NUM={}", .{self.value}),
            .l_paren => _ = try writer.write("L_PAREN"),
            .r_paren => _ = try writer.write("R_PAREN"),
            .assignment => _ = try writer.write("ASSIGNMENT"),
            .sum => _ = try writer.write("SUM"),
            .multiplication => _ = try writer.write("MULT"),
        }
    }

    pub fn fmtArray(token_array: []const Token, writer: *std.Io.Writer) !void {
        var is_first: bool = true;
        _ = try writer.writeByte('[');
        for (token_array) |token| {
            if (is_first) is_first = false else _ = try writer.write(", ");
            try token.fmt(writer);
        }
        _ = try writer.writeByte(']');
    }
};

test "token formatting" {
    var buffer: [512]u8 = undefined;
    var fixed_writer = std.Io.Writer.fixed(&buffer);
    const tokens = [_]Token{
        try Token.initIdentifier("foo", std.testing.allocator),
        Token.initSpecial(.assignment),
        Token.initLiteral(42),
        Token.initSpecial(.end_of_line),
    };
    defer for (tokens) |token| token.deinit(std.testing.allocator);
    try Token.fmtArray(&tokens, &fixed_writer);
    try std.testing.expectEqualStrings(
        "[IDENTIFIER='foo', ASSIGNMENT, NUM=42, $]",
        fixed_writer.buffered(),
    );
}
