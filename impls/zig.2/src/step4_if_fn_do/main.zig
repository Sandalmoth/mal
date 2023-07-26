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
    arena: std.mem.Allocator,
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

        const ast1 = try mal.read(s, mal.arena);
        const ast2 = try mal.eval(ast1, mal.arena);
        try mal.print(ast2);
        try mal.out.writer().print("\n", .{});
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();
    var arena = std.heap.ArenaAllocator.init(alloc); // fuckit, let's just leak memory
    defer arena.deinit();
    const stdin = std.io.getStdIn();
    const stdout = std.io.getStdOut();

    var input_buffer: [1024]u8 = undefined;

    var mal = MAL{
        .alloc = alloc,
        .arena = arena.allocator(),
        .out = stdout,
        .env = try Environment.init(alloc, stdout),
    };

    try mal.env.symbol_table.put("+", MalType{ .intrinsic = .plus });
    try mal.env.symbol_table.put("-", MalType{ .intrinsic = .minus });
    try mal.env.symbol_table.put("*", MalType{ .intrinsic = .mul });
    try mal.env.symbol_table.put("/", MalType{ .intrinsic = .div });
    // should these be intrinsics or special forms?
    try mal.env.symbol_table.put("prn", MalType{ .intrinsic = .prn });
    try mal.env.symbol_table.put("list", MalType{ .intrinsic = .list });
    try mal.env.symbol_table.put("list?", MalType{ .intrinsic = .islist });
    try mal.env.symbol_table.put("empty?", MalType{ .intrinsic = .isempty });
    try mal.env.symbol_table.put("count", MalType{ .intrinsic = .count });
    try mal.env.symbol_table.put("=", MalType{ .intrinsic = .eql });
    try mal.env.symbol_table.put("<", MalType{ .intrinsic = .lt });
    try mal.env.symbol_table.put("<=", MalType{ .intrinsic = .leq });
    try mal.env.symbol_table.put(">", MalType{ .intrinsic = .gt });
    try mal.env.symbol_table.put(">=", MalType{ .intrinsic = .geq });

    // try stdout.writeAll("Hello, world!\n");
    // try stdout.writer().print("number: {d}, string: {s}\n", .{ 42, "fourty-two" });

    while (true) {
        try stdout.writer().print("user> ", .{});
        const input = try stdin.reader().readUntilDelimiter(&input_buffer, '\n');
        mal.rep(input) catch |err| {
            std.debug.print("{}\n", .{err});
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
