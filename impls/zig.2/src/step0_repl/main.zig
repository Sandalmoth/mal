const std = @import("std");

const MAL = struct {
    alloc: std.mem.Allocator,

    pub fn read(mal: *MAL, s: []u8) []u8 {
        _ = mal;
        return s;
    }

    pub fn eval(mal: *MAL, s: []u8) []u8 {
        _ = mal;
        return s;
    }

    pub fn print(mal: *MAL, s: []u8) []u8 {
        _ = mal;
        return s;
    }

    pub fn rep(mal: *MAL, s: []u8) []u8 {
        const s1 = mal.read(s);
        const s2 = mal.eval(s1);
        const s3 = mal.print(s2);
        return s3;
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();
    const stdin = std.io.getStdIn();
    const stdout = std.io.getStdOut();

    var input_buffer: [1024]u8 = undefined;

    var mal = MAL{ .alloc = alloc };

    // try stdout.writeAll("Hello, world!\n");
    // try stdout.writer().print("number: {d}, string: {s}\n", .{ 42, "fourty-two" });

    while (true) {
        try stdout.writer().print("user> ", .{});
        const input = try stdin.reader().readUntilDelimiter(&input_buffer, '\n');
        try stdout.writer().print("{s}\n", .{mal.rep(input)});
    }

    // std.debug.print("input: ", .{});
    // const input = try stdin.reader().readUntilDelimiterAlloc(allocator, '\n', 1024);
    // defer allocator.free(input);

    // std.debug.print("value: {s}\n", .{input});
}
