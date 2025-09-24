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

    var string_building_mode: bool = false;
    var number_building_mode: bool = false;

    var expression_end: bool = false;
    var whitespace: bool = false;

    var c: u8 = undefined;
    var next: u8 = undefined;
    var i: usize = 0;
    while (i < text.len) : (i += 1) {
        c = text[i];
        if (c == 0) break;
        next = peekNextChar(text, i);
        whitespace = isWhitespace(c);

        switch (c) {
            ';' => expression_end = true,
            '=' => try token_vector.append(allocator, .initSpecial(.assignment)),
            '(' => try token_vector.append(allocator, .initSpecial(.l_paren)),
            ')' => try token_vector.append(allocator, .initSpecial(.r_paren)),
            '+' => try token_vector.append(allocator, .initSpecial(.sum)),
            '*' => try token_vector.append(allocator, .initSpecial(.multiplication)),
            '/' => try token_vector.append(allocator, .initSpecial(.division)),
            '-' => if (isWhitespace(next)) {
                try token_vector.append(allocator, .initSpecial(.subtraction));
            } else {
                try token_vector.append(allocator, .initSpecial(.negation));
            },
            else => {},
        }

        // buffer flush requested
        if (whitespace and (char_vector.items.len > 0)) {
            if (number_building_mode) {
                const str = try char_vector.toOwnedSlice(fixed_allocator);
                const value_token = lexNumberString(str) orelse return error.BadInteger;
                try token_vector.append(allocator, value_token);
                number_building_mode = false;
            }
            if (string_building_mode) {
                const str = try char_vector.toOwnedSlice(fixed_allocator);
                if (lexKeywordString(str)) |keyword_token| {
                    try token_vector.append(allocator, keyword_token);
                } else {
                    try token_vector.append(allocator, try Token.initIdentifier(str, allocator));
                }
                string_building_mode = false;
            }
        }

        if (isNumberChar(c)) {
            number_building_mode = true;
        }
        if (isNormalChar(c)) {
            string_building_mode = true;
        }
        if (number_building_mode or string_building_mode) {
            try char_vector.append(fixed_allocator, c);
        }

        if (expression_end) try token_vector.append(allocator, Token.initSpecial(.end_of_line));
    }

    return token_vector.toOwnedSlice(allocator);
}

/// where 'i' is the index of the current character in use
/// returns a newline character on fail, simulating an EOF
fn peekNextChar(str: []const u8, i: usize) u8 {
    if ((i + 1) >= str.len) return '\n' else return str[i + 1];
}

/// identifies start of possible identifier name
fn isNormalChar(c: u8) bool {
    if (std.ascii.isAlphabetic(c)) return true;
    if (c == '_') return true;
    return false;
}

/// identifies start of possible number literal, cannot have minuses
fn isNumberChar(c: u8) bool {
    return (std.ascii.isDigit(c));
}

/// identifies word-breaking characters
fn isWhitespace(c: u8) bool {
    return switch (c) {
        ' ', ';', '\n', 0 => true,
        else => false,
    };
}

/// perfect compile-time hash switching
fn lexKeywordString(str: []const u8) ?Token {
    return switch (h(str)) {
        h("(") => Token.initSpecial(.l_paren),
        h(")") => Token.initSpecial(.r_paren),
        h("=") => Token.initSpecial(.assignment),
        h("+") => Token.initSpecial(.sum),
        h("*") => Token.initSpecial(.multiplication),
        else => null,
    };
}

/// only accepts normal, base 10 integers. They may be negative
fn lexNumberString(str: []const u8) ?Token {
    const value: i32 = std.fmt.parseInt(i32, str, 10) catch return null;
    std.debug.assert(value > 0);
    return Token.initLiteral(value);
}

test "lexing" {
    const allocator = std.testing.allocator;

    const input = "foo = -42 - -1337;";
    const expected_tokens = [_]Token{
        try Token.initIdentifier("foo", allocator),
        Token.initSpecial(.assignment),
        Token.initSpecial(.negation),
        Token.initLiteral(42),
        Token.initSpecial(.subtraction),
        Token.initSpecial(.negation),
        Token.initLiteral(1337),
        Token.initSpecial(.end_of_line),
    };
    defer for (expected_tokens) |token| token.deinit(allocator);
    const expected_text = "[IDENTIFIER='foo', ASSIGNMENT, NEGATION, NUM=42, SUBTRACTION, NEGATION, NUM=1337, $]";

    const lexed = try lex(input, allocator);
    defer allocator.free(lexed);
    defer for (lexed) |token| token.deinit(allocator);
    var buffer: [512]u8 = undefined;
    var writer = std.Io.Writer.fixed(&buffer);
    try Token.fmtArray(lexed, &writer);
    try std.testing.expectEqualStrings(expected_text, writer.buffered());
    for (expected_tokens, lexed) |expected, got| {
        try std.testing.expect(Token.eql(expected, got));
    }
}
