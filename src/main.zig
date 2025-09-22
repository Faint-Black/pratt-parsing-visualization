const std = @import("std");
const rl = @import("raylib");
const rg = @import("raygui");
const render = @import("render.zig");

pub fn main() !void {
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
        if (textbox_contents) |text| std.debug.print("{s}\n", .{text});
    }
}
