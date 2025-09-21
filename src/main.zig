const std = @import("std");
const rl = @import("raylib");
const rg = @import("raygui");

pub fn main() !void {
    const screen_width = 800;
    const screen_height = 450;
    const frames_per_second = 60;
    var frame_counter: u64 = 0;

    const textbox_pos = rl.Vector2{
        .x = 10,
        .y = 10,
    };
    const textbox_rect = rl.Rectangle{
        .x = textbox_pos.x,
        .y = textbox_pos.y,
        .width = screen_width - textbox_pos.x * 2,
        .height = 50,
    };
    var buffer: [256]u8 = undefined;
    var sentinel_pos: usize = undefined;
    std.mem.copyForwards(u8, &buffer, "Type here\x00");

    rl.setTraceLogLevel(.err);
    rl.initWindow(screen_width, screen_height, "Pratt Parsing");
    defer rl.closeWindow();
    rl.setTargetFPS(frames_per_second);
    while (!rl.windowShouldClose()) : (frame_counter += 1) {
        rl.beginDrawing();
        defer rl.endDrawing();
        rl.clearBackground(.white);

        _ = rg.textBox(textbox_rect, @as([:0]u8, @ptrCast(&buffer)), buffer.len - 1, true);
        sentinel_pos = std.mem.indexOfSentinel(u8, 0, @as([:0]u8, @ptrCast(&buffer)));

        if (frame_counter % 60 == 0) {
            std.debug.print("{s}\n", .{buffer[0..sentinel_pos]});
        }
    }
}
