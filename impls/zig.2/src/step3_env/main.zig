const std = @import("std");
const _reader = @import("reader.zig");
const Reader = _reader.Reader;

const _printer = @import("printer.zig");

const _ast = @import("ast.zig");
const MalType = _ast.MalType;

const _env = @import("env.zig");
const Environment = _env.Environment;

const MAL = struct {
    alloc: std.mem.Allocator,
    out: std.fs.File,
    env: Environment,

    pub fn read(mal: *MAL, s: []u8, arena: std.mem.Allocator) !MalType {
        _ = mal;
        return try Reader.read(arena, s);
    }

    pub fn eval(mal: *MAL, ast: MalType, arena: std.mem.Allocator) !MalType {
        return try mal.env.eval(ast, arena);
    }

    pub fn print(mal: *MAL, ast: MalType) !void {
        try _printer.print(mal.out, ast);
    }

    pub fn rep(mal: *MAL, s: []u8) !void {
        // using a memory arena is very handy here
        // since then cleaning up a mess of an ast full of
        // strings and array list is just a single call
        var arena = std.heap.ArenaAllocator.init(mal.alloc);
        defer arena.deinit();

        const ast1 = try mal.read(s, arena.allocator());
        const ast2 = try mal.eval(ast1, arena.allocator());
        try mal.print(ast2);
        try mal.out.writer().print("\n", .{});
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();
    const stdin = std.io.getStdIn();
    const stdout = std.io.getStdOut();

    var input_buffer: [1024]u8 = undefined;

    var mal = MAL{
        .alloc = alloc,
        .out = stdout,
        .env = try Environment.init(alloc),
    };
    defer mal.env.deinit();

    // try stdout.writeAll("Hello, world!\n");
    // try stdout.writer().print("number: {d}, string: {s}\n", .{ 42, "fourty-two" });

    while (true) {
        try stdout.writer().print("user> ", .{});
        const input = try stdin.reader().readUntilDelimiter(&input_buffer, '\n');
        mal.rep(input) catch |err| {
            // std.debug.print("{}\n", .{err});
            // probably print different errors depending on error here
            if (err == error.NotFound) {
                try stdout.writer().print("not found\n", .{});
            } else {
                try stdout.writer().print("unbalanced\n", .{});
            }
        };
    }

    // std.debug.print("input: ", .{});
    // const input = try stdin.reader().readUntilDelimiterAlloc(allocator, '\n', 1024);
    // defer allocator.free(input);

    // std.debug.print("value: {s}\n", .{input});
}
