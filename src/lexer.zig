const std = @import("std");
const Token = @import("token.zig").Token;

pub fn lex(text: []const u8, allocator: std.mem.Allocator) ![]Token {
    var buffer: [512]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buffer);
    const fixed_allocator = fba.allocator();

    var token_vector: std.ArrayList(Token) = .empty;
    defer token_vector.deinit(allocator);
    var char_vector: std.ArrayList(u8) = .empty;
    defer char_vector.deinit(fixed_allocator);

    var expression_ended: bool = false;
    var line_ended: bool = false;
    var null_terminator: bool = false;
    var whitespace: bool = false;
    for (text) |c| {
        if (null_terminator) break;
        expression_ended = (c == ';');
        line_ended = (c == '\n');
        null_terminator = (c == 0);
        whitespace = (c == ' ' or expression_ended or line_ended or null_terminator);
        if (whitespace == false) try char_vector.append(fixed_allocator, c);
        if (whitespace == true and char_vector.items.len > 0) {
            const str = try char_vector.toOwnedSlice(fixed_allocator);
            if (std.mem.eql(u8, str, "=")) {
                try token_vector.append(allocator, Token.initSpecial(.assignment));
            } else if (std.mem.eql(u8, str, "+")) {
                try token_vector.append(allocator, Token.initSpecial(.sum));
            } else if (std.mem.eql(u8, str, "*")) {
                try token_vector.append(allocator, Token.initSpecial(.multiplication));
            } else {
                try token_vector.append(allocator, try Token.initIdentifier(str, allocator));
            }
        }
        if (expression_ended) try token_vector.append(allocator, Token.initSpecial(.end_of_line));
    }

    return token_vector.toOwnedSlice(allocator);
}
