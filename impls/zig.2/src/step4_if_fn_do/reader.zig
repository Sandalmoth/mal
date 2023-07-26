const std = @import("std");

const _ast = @import("ast.zig");
const MalType = _ast.MalType;

pub const TokenType = enum {
    snail, // ~@
    l_paren,
    r_paren,
    l_curly,
    r_curly,
    l_brack,
    r_brack,
    quote,
    grave,
    tilde,
    hat,
    at,
    string,
    comment,
    symbol,
};
pub const Token = struct {
    type: TokenType,
    data: []const u8,
};

pub const Reader = struct {
    alloc: std.mem.Allocator,
    tokens: std.ArrayList(Token),
    cursor: usize,

    pub fn read(alloc: std.mem.Allocator, s: []const u8) !MalType {
        var rdr = Reader{
            .alloc = alloc,
            .tokens = std.ArrayList(Token).init(alloc),
            .cursor = 0,
        };
        errdefer rdr.free();

        try rdr.tokenize(s);

        // std.debug.print("parsing: \"{s}\"\n", .{s});
        // for (rdr.tokens.items) |token| {
        //     std.debug.print("{}   \t{s}\n", .{ token.type, token.data });
        // }

        return try rdr.readForm();
        // i don't think the below is right...
        // const token = rdr.peek();
        // if (rdr.tokens.items.len <= 1 or token.type == .l_paren) {
        //     return try rdr.readForm();
        // } else {
        //     // many statements at root are in a list by default
        //     try rdr.tokens.insert(0, Token{ .type = .l_paren, .data = "(" });
        //     try rdr.tokens.append(Token{ .type = .r_paren, .data = ")" });
        //     return try rdr.readForm();
        // }
    }

    pub fn free(rdr: *Reader) void {
        rdr.tokens.deinit();
        rdr.* = undefined;
    }

    pub fn next(rdr: *Reader) Token {
        rdr.cursor += 1;
        return rdr.tokens.items[rdr.cursor - 1];
    }

    pub fn peek(rdr: *Reader) Token {
        return rdr.tokens.items[rdr.cursor];
    }

    pub fn readForm(rdr: *Reader) anyerror!MalType {

        // somehow:
        // quote, quasiquote, unquote, splice_unquote and deref,
        // should produce a list of themselves and the thing after
        // while with_meta should produce a list
        // of itself and the two following things

        // mutual recursion breaks inferred error sets
        // so just assume we never have errors here...
        // std.debug.print("cursor at {}\n", .{rdr.cursor});
        const token = rdr.peek();
        // std.debug.print("peek {}\t{s}\n", .{ token.type, token.data });
        if (token.type == .l_paren) {
            rdr.cursor += 1; // ignore the parenthesis
            return try rdr.readList();
        } else if (token.type == .l_brack) {
            rdr.cursor += 1; // ignore the parenthesis
            return try rdr.readVector();
        } else if (token.type == .l_curly) {
            rdr.cursor += 1; // ignore the parenthesis
            return try rdr.readDict();
        } else if (token.type == .quote or token.type == .grave or token.type == .tilde or token.type == .snail or token.type == .at) {
            return try rdr.readTransientList(2);
        } else if (token.type == .hat) {
            return try rdr.readTransientList(3);
        } else {
            return rdr.readAtom();
        }
    }

    pub fn readList(rdr: *Reader) anyerror!MalType {
        var list = MalType{
            .list = std.ArrayList(MalType).init(rdr.alloc),
        };

        var matched = false;
        while (rdr.cursor < rdr.tokens.items.len) {
            const token = rdr.peek();
            // std.debug.print("list {}\t{s}\n", .{ token.type, token.data });
            if (token.type == .r_paren) {
                rdr.cursor += 1;
                matched = true;
                break;
            }
            list.list.append(try rdr.readForm()) catch unreachable;
        }

        if (!matched) {
            return error.UnmatchedParenthesis;
            // std.debug.panic("unmatched parenthesis\n", .{});
        }

        return list;
    }

    pub fn readVector(rdr: *Reader) anyerror!MalType {
        var vector = MalType{
            .vector = std.ArrayList(MalType).init(rdr.alloc),
        };

        var matched = false;
        while (rdr.cursor < rdr.tokens.items.len) {
            const token = rdr.peek();
            // std.debug.print("list {}\t{s}\n", .{ token.type, token.data });
            if (token.type == .r_brack) {
                rdr.cursor += 1;
                matched = true;
                break;
            }
            vector.vector.append(try rdr.readForm()) catch unreachable;
        }

        if (!matched) {
            return error.UnmatchedBracket;
            // std.debug.panic("unmatched parenthesis\n", .{});
        }

        return vector;
    }

    pub fn readDict(rdr: *Reader) anyerror!MalType {
        var dict = MalType{
            .dict = std.ArrayList(MalType).init(rdr.alloc),
        };

        var matched = false;
        while (rdr.cursor < rdr.tokens.items.len) {
            const token = rdr.peek();
            // std.debug.print("list {}\t{s}\n", .{ token.type, token.data });
            if (token.type == .r_curly) {
                rdr.cursor += 1;
                matched = true;
                break;
            }
            dict.dict.append(try rdr.readForm()) catch unreachable;
        }

        if (!matched) {
            return error.UnmatchedBracket;
            // std.debug.panic("unmatched parenthesis\n", .{});
        }

        return dict;
    }

    pub fn readTransientList(rdr: *Reader, n: usize) anyerror!MalType {
        // blocks the following n things into a list
        var list = MalType{
            .list = std.ArrayList(MalType).init(rdr.alloc),
        };

        list.list.append(rdr.readAtom()) catch unreachable;

        var i: usize = 1;
        while (i < n and rdr.cursor < rdr.tokens.items.len) : (i += 1) {
            list.list.append(try rdr.readForm()) catch unreachable;
        }

        if (i != n) {
            return error.MissingOperands;
            // std.debug.panic("unmatched parenthesis\n", .{});
        }

        // only for with-meta
        // and in that case, operands should be swapped
        if (n == 3) {
            const tmp = list.list.items[1];
            list.list.items[1] = list.list.items[2];
            list.list.items[2] = tmp;
        }

        return list;
    }

    pub fn readAtom(rdr: *Reader) MalType {
        const token = rdr.next();
        // std.debug.print("atom {}\t{s}\n", .{ token.type, token.data });
        switch (token.type) {
            .symbol => {
                if (std.mem.eql(u8, token.data, "true")) {
                    return MalType{ .true = {} };
                } else if (std.mem.eql(u8, token.data, "false")) {
                    return MalType{ .false = {} };
                } else if (std.mem.eql(u8, token.data, "nil")) {
                    return MalType{ .nil = {} };
                }

                const int = std.fmt.parseInt(i64, token.data, 0);
                if (int) |i| {
                    return MalType{ .int = i };
                } else |_| {}
            },
            .string => {
                return MalType{ .string = rdr.alloc.dupe(u8, token.data[1 .. token.data.len - 1]) catch unreachable };
            },
            .quote => {
                return MalType{ .quote = {} };
            },
            .grave => {
                return MalType{ .quasiquote = {} };
            },
            .tilde => {
                return MalType{ .unquote = {} };
            },
            .snail => {
                return MalType{ .splice_unquote = {} };
            },
            .at => {
                return MalType{ .deref = {} };
            },
            .hat => {
                return MalType{ .with_meta = {} };
            },
            else => {
                // NOTE this is probably not correct
                return MalType{ .symbol = rdr.alloc.dupe(u8, token.data) catch unreachable };
                // std.debug.print("ignoring unimplemented atom {} {s}", .{ token.type, token.data });
            },
        }

        return MalType{ .symbol = rdr.alloc.dupe(u8, token.data) catch unreachable };
        // std.debug.panic("invalid token {} {s}\n", .{ token.type, token.data });
    }

    fn tokenize(rdr: *Reader, s: []const u8) !void {
        var cur: usize = 0;

        while (cur < s.len) {
            if (s[cur] == ' ' or s[cur] == ',' or s[cur] == '\t' or s[cur] == '\n' or s[cur] == '\r') {
                // TODO check what chars should count as whitespace
                cur += 1;
            } else if (cur + 1 < s.len and s[cur] == '~' and s[cur + 1] == '@') {
                try rdr.tokens.append(Token{
                    .type = .snail,
                    .data = s[cur .. cur + 2],
                });
                cur += 2;
            } else if (s[cur] == '(') {
                try rdr.tokens.append(Token{
                    .type = .l_paren,
                    .data = s[cur .. cur + 1],
                });
                cur += 1;
            } else if (s[cur] == ')') {
                try rdr.tokens.append(Token{
                    .type = .r_paren,
                    .data = s[cur .. cur + 1],
                });
                cur += 1;
            } else if (s[cur] == '{') {
                try rdr.tokens.append(Token{
                    .type = .l_curly,
                    .data = s[cur .. cur + 1],
                });
                cur += 1;
            } else if (s[cur] == '}') {
                try rdr.tokens.append(Token{
                    .type = .r_curly,
                    .data = s[cur .. cur + 1],
                });
                cur += 1;
            } else if (s[cur] == '[') {
                try rdr.tokens.append(Token{
                    .type = .l_brack,
                    .data = s[cur .. cur + 1],
                });
                cur += 1;
            } else if (s[cur] == ']') {
                try rdr.tokens.append(Token{
                    .type = .r_brack,
                    .data = s[cur .. cur + 1],
                });
                cur += 1;
            } else if (s[cur] == '\'') {
                try rdr.tokens.append(Token{
                    .type = .quote,
                    .data = s[cur .. cur + 1],
                });
                cur += 1;
            } else if (s[cur] == '`') {
                try rdr.tokens.append(Token{
                    .type = .grave,
                    .data = s[cur .. cur + 1],
                });
                cur += 1;
            } else if (s[cur] == '~') {
                try rdr.tokens.append(Token{
                    .type = .tilde,
                    .data = s[cur .. cur + 1],
                });
                cur += 1;
            } else if (s[cur] == '^') {
                try rdr.tokens.append(Token{
                    .type = .hat,
                    .data = s[cur .. cur + 1],
                });
                cur += 1;
            } else if (s[cur] == '@') {
                try rdr.tokens.append(Token{
                    .type = .at,
                    .data = s[cur .. cur + 1],
                });
                cur += 1;
            } else if (s[cur] == '"') {
                // OMNOMNOM an entire string
                var len: usize = 1;
                var escape = false;
                var matched = false;
                while (cur + len < s.len) {
                    if (s[cur + len] == '"' and !escape) {
                        len += 1;
                        try rdr.tokens.append(Token{
                            .type = .string,
                            .data = s[cur .. cur + len],
                        });
                        matched = true;
                        break;
                    }
                    // NOTE escaped \ does can not escape "
                    escape = s[cur + len] == '\\' and !escape;
                    len += 1;
                }
                if (!matched) {
                    // std.debug.print("unmatched quote in {s}\n", .{s[cur .. cur + len]});
                    return error.UnmatchedQuote;
                }
                cur += len;
            } else if (s[cur] == ';') {
                try rdr.tokens.append(Token{
                    .type = .comment,
                    .data = s[cur..],
                });
                cur = s.len;
            } else {
                var len: usize = 1;
                while (cur + len < s.len) {
                    // TODO refactor
                    if (s[cur + len] == ' ' or s[cur + len] == ',' or s[cur + len] == '\t' or
                        s[cur + len] == '\n' or s[cur + len] == '\r' or s[cur + len] == '(' or
                        s[cur + len] == ')' or s[cur + len] == '[' or s[cur + len] == ']' or
                        s[cur + len] == '{' or s[cur + len] == '}' or s[cur + len] == '\'' or
                        s[cur + len] == '\"' or s[cur + len] == '`' or s[cur + len] == ';' or
                        s[cur + len] == '^')
                    {
                        try rdr.tokens.append(Token{
                            .type = .symbol,
                            .data = s[cur .. cur + len],
                        });
                        break;
                    }
                    len += 1;
                } else {
                    // we ran out of characters to parse
                    // which means what we have is a token
                    try rdr.tokens.append(Token{
                        .type = .symbol,
                        .data = s[cur .. cur + len],
                    });
                }

                cur += len;
                // std.debug.print("ignoring character {c}\n", .{s[cur]});
                // cur += 1;
            }
            // std.debug.print("{s}\n", .{s[cur..]});
        }
    }
};

test "Reader" {
    std.debug.print("\n", .{});
    const s = ")[' \t ( star ~@ 123.4 \"howdy \\\" everybody 92929 ())()\" yo( ; after this is comment ~@ \t123.45 (\"  \t ";
    var rdr = try Reader.read(std.testing.allocator, s);
    defer rdr.free();

    std.debug.print("{s}\n", .{s});
    for (rdr.tokens.items) |token| {
        std.debug.print("{}   \t{s}\n", .{ token.type, token.data });
    }
}

test "ReaderUnmatchedQuote" {
    const s = "yo \" howdy ";
    try std.testing.expectError(error.UnmatchedQuote, Reader.read(std.testing.allocator, s));
}
