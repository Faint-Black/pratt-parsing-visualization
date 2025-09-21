const std = @import("std");
const rl = @import("raylib");

pub fn main() !void {
    const screenWidth = 800;
    const screenHeight = 450;

    rl.setTraceLogLevel(.err);
    rl.initWindow(screenWidth, screenHeight, "Pratt Parsing");
    defer rl.closeWindow();
    rl.setTargetFPS(60);
    while (!rl.windowShouldClose()) {
        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(.white);
        rl.drawText("Congrats! You created your first window!", 190, 200, 20, .light_gray);
    }
}

test "test test" {
    try std.testing.expectEqual(1, 1);
}
