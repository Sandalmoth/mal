const std = @import("std");

const _ast = @import("ast.zig");
const MalType = _ast.MalType;

pub const Environment = struct {
    alloc: std.mem.Allocator,
    symbol_table: std.StringHashMap(MalType), // probably a useful abstraction for the future?

    outer: ?*Environment,

    pub fn init(alloc: std.mem.Allocator) !Environment {
        var env = Environment{
            .alloc = alloc,
            .symbol_table = std.StringHashMap(MalType).init(alloc),
            .outer = null,
        };

        // we could also use set, but whatever
        try env.symbol_table.put("+", MalType{ .intrinsic = .plus });
        try env.symbol_table.put("-", MalType{ .intrinsic = .minus });
        try env.symbol_table.put("*", MalType{ .intrinsic = .mul });
        try env.symbol_table.put("/", MalType{ .intrinsic = .div });

        return env;
    }

    pub fn deinit(env: *Environment) void {
        env.symbol_table.deinit();
    }

    pub fn set(env: *Environment, key: MalType, value: MalType) void {
        // add to symbol tabble
        switch (key) {
            .symbol => |symbol| {
                env.symbol_table.put(env.alloc.dupe(u8, symbol) catch unreachable, value) catch unreachable;
            },
            else => {
                @panic("only symbols can be symbols");
            },
        }
    }

    pub fn get(env: *Environment, key: MalType) !MalType {
        // get the value for a key in the environment

        switch (key) {
            .symbol => |symbol| {
                // well this doesn't work, the symbol table needs to hold maltypes
                // and then maltypes need to be able to be .intrinsic?
                if (env.find(symbol)) |e| {
                    return e.symbol_table.get(symbol).?;
                }
            },
            else => {
                return error.NotASymbol;
            },
        }

        std.debug.print("{}\n", .{key});
        return error.NotFound;
    }

    pub fn find(env: *Environment, key: []const u8) ?*Environment {
        // find the environment a key is in
        // by walking out recursively
        if (env.symbol_table.contains(key)) {
            return env;
        }

        if (env.outer) |parent| {
            return parent.find(key);
        }
        return null;
    }

    pub fn eval(env: *Environment, root: MalType, arena: std.mem.Allocator) anyerror!MalType {
        switch (root) {
            .list => |list| {
                if (list.items.len == 0) {
                    return root;
                }
                // apply section is here?
                if (list.items[0] == .symbol and std.mem.eql(u8, list.items[0].symbol, "def!")) {
                    // const val = try env.eval_ast(list.items[2], arena); // eval or eval_ast?
                    const val = try env.eval(list.items[2], arena); // eval or eval_ast?
                    env.set(list.items[1], val);
                    return val; // NOTE is this the expected behaviour?
                }
                // TODO let?
                // function!
                const new_list = try env.eval_ast(root, arena);
                // wow this turned awful fast huh
                if (new_list == MalType.list) {
                    switch (new_list.list.items[0]) {
                        .symbol => |symbol| {
                            if (env.symbol_table.get(symbol)) |val| {
                                switch (val) {
                                    .intrinsic => {},
                                    else => {
                                        return error.SymbolNotComputable;
                                    },
                                }
                                return error.wat;
                            } else {
                                return error.UnknownSymbol;
                            }
                        },
                        .intrinsic => |intrinsic| {
                            if (intrinsic == .plus) {
                                var acc: i64 = 0;
                                for (new_list.list.items[1..]) |item| {
                                    if (item == MalType.int) {
                                        acc += item.int;
                                    } else {
                                        return error.OperatorTyping;
                                    }
                                }
                                return MalType{ .int = acc };
                            } else if (intrinsic == .minus) {
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
                            } else if (intrinsic == .mul) {
                                var acc: i64 = 1;
                                for (new_list.list.items[1..]) |item| {
                                    if (item == MalType.int) {
                                        acc *= item.int;
                                    } else {
                                        return error.OperatorTyping;
                                    }
                                }
                                return MalType{ .int = acc };
                            } else if (intrinsic == .div) {
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
                                return error.UnimplementedIntrinsic;
                            }
                        },
                        else => {
                            std.debug.print("{}\n", .{new_list.list.items[0]});
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
                _ = symbol;
                // if (env.symbol_table.get(symbol)) |val| {
                const val = try env.get(root);
                return val;
                // if (val == .intrinsic) {
                // return root;
                // }
                // @panic("we cant get here right?");
                // }
                // return error.UnknownSymbol;
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
