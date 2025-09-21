const std = @import("std");
const rl = @import("raylib");
const rg = @import("raygui");

pub fn main() !void {
    const screen_width = 800;
    const screen_height = 450;
    const frames_per_second = 60;
    var frame_counter: u64 = 0;

    const rect = rl.Rectangle{
        .x = 10,
        .y = 10,
        .width = 300,
        .height = 50,
    };
    var buffer: [64]u8 = undefined;
    std.mem.copyForwards(u8, &buffer, "hello\x00");

    rl.setTraceLogLevel(.err);
    rl.initWindow(screen_width, screen_height, "Pratt Parsing");
    defer rl.closeWindow();
    rl.setTargetFPS(frames_per_second);
    while (!rl.windowShouldClose()) : (frame_counter += 1) {
        rl.beginDrawing();
        defer rl.endDrawing();
        rl.clearBackground(.white);

        _ = rg.textBox(rect, @as([:0]u8, @ptrCast(&buffer)), buffer.len - 1, true);
        if (frame_counter % 60 == 0) {
            std.debug.print("{s}\n", .{@as([*:0]u8, @ptrCast(&buffer))});
        }
    }
}
