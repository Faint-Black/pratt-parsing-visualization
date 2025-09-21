const std = @import("std");
const rl = @import("raylib");
const rg = @import("raygui");
const render = @import("render.zig");

pub fn main() !void {
    var buffer: [256]u8 = undefined;
    std.mem.copyForwards(u8, &buffer, "Type here\x00");
    var read_text: []const u8 = undefined;

    rl.setTraceLogLevel(.err);
    rl.initWindow(render.screen_width, render.screen_height, "Pratt Parsing");
    defer rl.closeWindow();
    rl.setTargetFPS(render.frames_per_second);
    while (!rl.windowShouldClose()) : (render.frame_counter += 1) {
        rl.beginDrawing();
        defer rl.endDrawing();
        rl.clearBackground(.white);
        read_text = render.updateTextBox(@ptrCast(&buffer), buffer.len - 1);
        if (render.frame_counter % render.frames_per_second == 0) {
            std.debug.print("{s}\n", .{read_text});
        }
    }
}
