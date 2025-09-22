const std = @import("std");
const Token = @import("token.zig").Token;
const h = std.hash.Fnv1a_32.hash;

/// returns an array of tokens from lexed text
pub fn lex(text: []const u8, allocator: std.mem.Allocator) ![]Token {
    var buffer: [512]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buffer);
    const fixed_allocator = fba.allocator();

    var token_vector: std.ArrayList(Token) = .empty;
    defer token_vector.deinit(allocator);
    var char_vector: std.ArrayList(u8) = .empty;
    defer char_vector.deinit(fixed_allocator);

    var expression_end: bool = false;
    var line_end: bool = false;
    var null_terminator: bool = false;
    var whitespace: bool = false;
    for (text) |c| {
        if (null_terminator) break;
        expression_end = (c == ';');
        line_end = (c == '\n');
        null_terminator = (c == 0);
        whitespace = (expression_end or line_end or null_terminator or c == ' ');
        if (whitespace == false) try char_vector.append(fixed_allocator, c);
        if (whitespace == true and char_vector.items.len > 0) {
            const str = try char_vector.toOwnedSlice(fixed_allocator);
            if (lexKeywordString(str)) |keyword_token| {
                try token_vector.append(allocator, keyword_token);
            } else if (lexNumberString(str)) |number_token| {
                try token_vector.append(allocator, number_token);
            } else {
                try token_vector.append(allocator, try Token.initIdentifier(str, allocator));
            }
        }
        if (expression_end) try token_vector.append(allocator, Token.initSpecial(.end_of_line));
    }

    return token_vector.toOwnedSlice(allocator);
}

/// perfect compile-time hash switching
fn lexKeywordString(str: []const u8) ?Token {
    return switch (h(str)) {
        h("=") => Token.initSpecial(.assignment),
        h("+") => Token.initSpecial(.sum),
        h("*") => Token.initSpecial(.multiplication),
        else => null,
    };
}

/// only accepts normal, base 10 integers. They may be negative
fn lexNumberString(str: []const u8) ?Token {
    const value = std.fmt.parseInt(i32, str, 10) catch return null;
    return Token.initLiteral(value);
}
