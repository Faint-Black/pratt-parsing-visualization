const std = @import("std");
const builtin = @import("builtin");
const rl = @import("raylib");
const rg = @import("raygui");
const render = @import("render.zig");
const lex = @import("lexer.zig").lex;
const Token = @import("token.zig").Token;

pub fn main() !void {
    var debug_allocator = std.heap.DebugAllocator(.{}).init;
    const gpa, const is_debug_alloc = switch (builtin.mode) {
        .Debug, .ReleaseSafe => .{ debug_allocator.allocator(), true },
        .ReleaseFast, .ReleaseSmall => .{ std.heap.smp_allocator, false },
    };
    defer {
        if (is_debug_alloc) _ = debug_allocator.deinit();
    }

    rl.setTraceLogLevel(.err);
    rl.initWindow(render.screen_width, render.screen_height, "Pratt Parsing");
    defer rl.closeWindow();
    rl.setWindowState(.{ .window_resizable = true });
    rl.setTargetFPS(render.frames_per_second);

    while (!rl.windowShouldClose()) : ({
        render.frame_counter += 1;
        render.screen_width = rl.getScreenWidth();
        render.screen_height = rl.getScreenHeight();
    }) {
        rl.beginDrawing();
        defer rl.endDrawing();
        rl.clearBackground(.white);

        const textbox_contents = render.updateTextBox();
        if (textbox_contents) |text| {
            var buffer: [2048]u8 = undefined;
            var writer = std.Io.Writer.fixed(&buffer);
            std.debug.print("input text = {s}\n", .{text});
            const tokens = try lex(text, gpa);
            defer gpa.free(tokens);
            defer for (tokens) |tok| tok.deinit(gpa);
            try Token.fmtArray(tokens, &writer);
            std.debug.print("output tokens = {s}\n", .{writer.buffered()});
        }
    }
}

test "tests index" {
    _ = @import("lexer.zig");
    _ = @import("token.zig");
}
