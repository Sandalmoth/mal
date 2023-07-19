const std = @import("std");

pub const MalTypeType = enum {
    list,
    symbol,
    int,
    // float,
    string,
    nil,
    true,
    false,
};
pub const MalType = union(MalTypeType) {
    list: std.ArrayList(MalType),
    symbol: []u8,
    int: i64,
    // float: f64,
    string: []u8,
    nil: void,
    true: void,
    false: void,
};
