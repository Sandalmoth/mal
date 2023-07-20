const std = @import("std");

const _ast = @import("ast.zig");
const MalType = _ast.MalType;

const SymbolType = enum {
    intrinsic,
};

// const Symbol = struct {
// type: SymbolType,
// };

pub const Environment = struct {
    alloc: std.mem.Allocator,
    symbol_table: std.StringHashMap(SymbolType), // probably a useful abstraction for the future?

    pub fn init(alloc: std.mem.Allocator) !Environment {
        var env = Environment{
            .alloc = alloc,
            .symbol_table = std.StringHashMap(SymbolType).init(alloc),
        };

        try env.symbol_table.put("+", .intrinsic);
        try env.symbol_table.put("-", .intrinsic);
        try env.symbol_table.put("*", .intrinsic);
        try env.symbol_table.put("/", .intrinsic);

        return env;
    }

    pub fn deinit(env: *Environment) void {
        env.symbol_table.deinit();
    }

    pub fn eval(env: *Environment, root: MalType, arena: std.mem.Allocator) anyerror!MalType {
        switch (root) {
            .list => |list| {
                if (list.items.len == 0) {
                    return root;
                }
                // function!
                const new_list = try env.eval_ast(root, arena);
                // wow this turned awful fast huh
                if (new_list == MalType.list) {
                    switch (new_list.list.items[0]) {
                        .symbol => |symbol| {
                            if (env.symbol_table.get(symbol)) |val| {
                                // std.debug.print("{}\n", .{val});
                                if (val == .intrinsic) {
                                    if (std.mem.eql(u8, symbol, "+")) {
                                        var acc: i64 = 0;
                                        for (new_list.list.items[1..]) |item| {
                                            if (item == MalType.int) {
                                                acc += item.int;
                                            } else {
                                                return error.OperatorTyping;
                                            }
                                        }
                                        return MalType{ .int = acc };
                                    } else if (std.mem.eql(u8, symbol, "-")) {
                                        var acc: i64 = undefined;
                                        for (new_list.list.items[1..], 0..) |item, i| {
                                            if (item == MalType.int) {
                                                if (i == 0) {
                                                    acc = item.int;
                                                } else {
                                                    acc -= item.int;
                                                }
                                            } else {
                                                return error.OperatorTyping;
                                            }
                                        }
                                        return MalType{ .int = acc };
                                    } else if (std.mem.eql(u8, symbol, "*")) {
                                        var acc: i64 = 1;
                                        for (new_list.list.items[1..]) |item| {
                                            if (item == MalType.int) {
                                                acc *= item.int;
                                            } else {
                                                return error.OperatorTyping;
                                            }
                                        }
                                        return MalType{ .int = acc };
                                    } else if (std.mem.eql(u8, symbol, "/")) {
                                        var acc: i64 = undefined;
                                        for (new_list.list.items[1..], 0..) |item, i| {
                                            if (item == MalType.int) {
                                                if (i == 0) {
                                                    acc = item.int;
                                                } else {
                                                    acc = @divTrunc(acc, item.int);
                                                }
                                            } else {
                                                std.debug.print("{}\n", .{item});
                                                return error.OperatorTyping;
                                            }
                                        }
                                        return MalType{ .int = acc };
                                    } else {
                                        return error.UnknownIntrinsicSymbol;
                                    }
                                } else {
                                    return error.NotIntrinsic;
                                }
                            } else {
                                return error.UnknownSymbol;
                            }
                        },
                        else => {
                            @panic("yeah...");
                        },
                    }
                    return root;
                } else {
                    @panic("wtf?");
                }
            },
            else => {
                return env.eval_ast(root, arena);
            },
        }
    }

    pub fn eval_ast(env: *Environment, root: MalType, arena: std.mem.Allocator) !MalType {
        switch (root) {
            .symbol => |symbol| {
                if (env.symbol_table.get(symbol)) |val| {
                    if (val == .intrinsic) {
                        return root;
                    }
                    @panic("no symbols implemented yet");
                }
                return error.UnknownSymbol;
            },
            .list => |list| {
                var new_list = MalType{
                    .list = std.ArrayList(MalType).init(arena),
                };
                for (list.items) |item| {
                    try new_list.list.append(try env.eval(item, arena));
                }
                return new_list;
            },
            .vector => |vector| {
                var new_vector = MalType{
                    .vector = std.ArrayList(MalType).init(arena),
                };
                for (vector.items) |item| {
                    try new_vector.vector.append(try env.eval(item, arena));
                }
                return new_vector;
            },
            .dict => |dict| {
                var new_dict = MalType{
                    .dict = std.ArrayList(MalType).init(arena),
                };
                var i: u32 = 0;
                for (dict.items) |item| {
                    // for a dict, only eval values, not keys
                    if (i % 2 == 1) {
                        try new_dict.dict.append(try env.eval(item, arena));
                    } else {
                        try new_dict.dict.append(item);
                    }
                    i += 1;
                }
                return new_dict;
            },
            else => {
                return root;
            },
        }

        return root;
    }
};
