const std = @import("std");
const Token = @import("token.zig").Token;

pub const AstNode = struct {
    token: Token,
    children: []AstNode,
};
