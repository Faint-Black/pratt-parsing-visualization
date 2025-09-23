const std = @import("std");
const builtin = @import("builtin");
const rl = @import("raylib");
const rg = @import("raygui");
const render = @import("render.zig");
const lex = @import("lexer.zig").lex;
const parse = @import("ast.zig");
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
    const bin_path = try std.fs.selfExeDirPathAlloc(gpa);
    const font_path = try std.mem.concat(gpa, u8, &.{ bin_path, "/../../data/LiberationMono-Bold.ttf" });
    const font = try rl.loadFont(@as([:0]u8, @ptrCast(font_path)));
    while (!rl.windowShouldClose()) : ({
        render.frame_counter += 1;
        render.screen_width = rl.getScreenWidth();
        render.screen_height = rl.getScreenHeight();
    }) {
        rl.beginDrawing();
        defer rl.endDrawing();
        rl.clearBackground(.white);

        render.renderParsedbox(font);
        const textbox_contents = render.updateTextBox();
        if (textbox_contents) |text| {
            try render.updateParsedText(text, gpa);
        }
    }
}

test "test index" {
    _ = @import("lexer.zig");
    _ = @import("token.zig");
    _ = @import("ast.zig");
}
