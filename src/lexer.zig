const std = @import("std");
const Token = @import("token.zig").Token;
const h = std.hash.Fnv1a_32.hash;

/// returns an array of tokens from lexed text
pub fn lex(text: []const u8, allocator: std.mem.Allocator) ![]Token {
    var buffer: [512]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buffer);
    const fixed_allocator = fba.allocator();

    var char_vector: std.ArrayList(u8) = .empty;
    defer char_vector.deinit(fixed_allocator);
    var token_vector: std.ArrayList(Token) = .empty;
    defer token_vector.deinit(allocator);
    errdefer for (token_vector.items) |token| token.deinit(allocator);

    var string_building_mode: bool = false;
    var number_building_mode: bool = false;
    var request_buffer_flush: bool = false;

    var c: u8 = undefined;
    var next_c: u8 = undefined;
    var i: usize = 0;
    while (i < text.len) : (i += 1) {
        c = text[i];
        if (c == 0) break;
        next_c = peekNextChar(text, i);

        if (number_building_mode and !isNumberChar(c)) request_buffer_flush = true;
        if (string_building_mode and !isNormalChar(c)) request_buffer_flush = true;

        if (request_buffer_flush and (char_vector.items.len > 0)) {
            request_buffer_flush = false;
            if (number_building_mode) {
                number_building_mode = false;
                const str = try char_vector.toOwnedSlice(fixed_allocator);
                const value_token = try lexNumberString(str);
                try token_vector.append(allocator, value_token);
            } else if (string_building_mode) {
                string_building_mode = false;
                const str = try char_vector.toOwnedSlice(fixed_allocator);
                if (lexKeywordString(str)) |keyword_token| {
                    try token_vector.append(allocator, keyword_token);
                } else {
                    try token_vector.append(allocator, try .initIdentifier(str, allocator));
                }
            }
        }

        if (isNumberChar(c)) number_building_mode = true;
        if (isNormalChar(c)) string_building_mode = true;
        if (number_building_mode or string_building_mode) {
            try char_vector.append(fixed_allocator, c);
        }

        switch (c) {
            ';' => try token_vector.append(allocator, .initSpecial(.end_of_line)),
            '=' => try token_vector.append(allocator, .initSpecial(.assignment)),
            '(' => try token_vector.append(allocator, .initSpecial(.l_paren)),
            ')' => try token_vector.append(allocator, .initSpecial(.r_paren)),
            '+' => try token_vector.append(allocator, .initSpecial(.sum)),
            '*' => try token_vector.append(allocator, .initSpecial(.multiplication)),
            '/' => try token_vector.append(allocator, .initSpecial(.division)),
            '-' => {
                if (isWhitespace(next_c)) {
                    try token_vector.append(allocator, .initSpecial(.subtraction));
                } else {
                    try token_vector.append(allocator, .initSpecial(.negation));
                }
            },
            else => {},
        }
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
        h("and") => Token.initSpecial(.boolean_and),
        h("or") => Token.initSpecial(.boolean_or),
        else => null,
    };
}

/// only accepts normal, base 10 integers. They may NOT be negative
fn lexNumberString(str: []const u8) !Token {
    const value: i32 = try std.fmt.parseInt(i32, str, 10);
    if (value < 0) return error.BadInteger;
    return Token.initLiteral(value);
}

test "lexing" {
    var buffer: [512]u8 = undefined;
    var writer = std.Io.Writer.fixed(&buffer);
    const allocator = std.testing.allocator;

    const input = "foo = -(42 - -1337);";
    const expected_text = "[IDENTIFIER='foo', ASSIGNMENT, NEGATION, L_PAREN, NUM=42, SUBTRACTION, NEGATION, NUM=1337, R_PAREN, $]";
    const expected_tokens = [_]Token{
        try Token.initIdentifier("foo", allocator),
        Token.initSpecial(.assignment),
        Token.initSpecial(.negation),
        Token.initSpecial(.l_paren),
        Token.initLiteral(42),
        Token.initSpecial(.subtraction),
        Token.initSpecial(.negation),
        Token.initLiteral(1337),
        Token.initSpecial(.r_paren),
        Token.initSpecial(.end_of_line),
    };
    defer for (expected_tokens) |token| token.deinit(allocator);

    const lexed = try lex(input, allocator);
    defer allocator.free(lexed);
    defer for (lexed) |token| token.deinit(allocator);

    // text format testing
    try Token.fmtArray(lexed, &writer);
    try std.testing.expectEqualStrings(expected_text, writer.buffered());
    // token eql testing
    for (expected_tokens, lexed) |expected, got| {
        try std.testing.expect(Token.eql(expected, got));
    }
}
