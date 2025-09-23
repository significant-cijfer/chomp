const std = @import("std");

const cwd = std.fs.cwd;
const indexOfScalarPos = std.mem.indexOfScalarPos;
const Allocator = std.mem.Allocator;

const Memo = struct {
    wins: std.AutoHashMap(u64, bool),

    pub fn init(gpa: Allocator) Memo {
        return .{
            .wins = .init(gpa),
        };
    }

    pub fn deinit(self: *Memo) void {
        self.wins.deinit();
    }

    fn hash(_: *Memo, key: []bool) u64 {
        var hasher = std.hash.Wyhash.init(0);
        std.hash.autoHashStrat(&hasher, key, .Deep);
        return hasher.final();
    }

    fn remember(self: *Memo, field: Field, win: bool) !void {
        const h = self.hash(field.cells);
        try self.wins.put(h, win);
    }

    fn recall(self: *Memo, field: Field) ?bool {
        const h = self.hash(field.cells);
        return self.wins.get(h);
    }
};

const Field = struct {
    wdt: u32,
    hgt: u32,
    cells: []bool,

    pub fn init(gpa: Allocator, width: u32, height: u32) !Field {
        const cells = try gpa.alloc(bool, width*height);
        @memset(cells, false);

        return .{
            .wdt = width,
            .hgt = height,
            .cells = cells,
        };
    }

    pub fn deinit(self: Field, gpa: Allocator) void {
        gpa.free(self.cells);
    }

    pub fn print(self: Field) void {
        for (0..self.hgt) |h| {
            for (0..self.wdt) |w| {
                std.debug.print("{d} ", .{@intFromBool(self.cells[w+h*self.wdt])}); //NOTE, print as either 0/1
            }

            std.debug.print("\n", .{});
        }
    }

    pub fn clone(self: Field, gpa: Allocator) !Field {
        return .{
            .wdt = self.wdt,
            .hgt = self.hgt,
            .cells = try gpa.dupe(bool, self.cells),
        };
    }

    fn eat(self: Field, x: u32, y: u32) void {
        // oob check
        if (x >= self.wdt or y >= self.hgt) @panic("TODO, figure out how tf this happened");

        for (y..self.hgt) |h| {
            for (x..self.wdt) |w| {
                self.cells[w+h*self.wdt] = true;
            }
        }
    }

    fn eatIdx(self: Field, idx: u64) void {
        self.eat(@intCast(idx % self.wdt), @intCast(idx / self.wdt));
    }

    fn nextMove(self: Field, start: u64) ?u64 {
        return indexOfScalarPos(bool, self.cells, start, false);
    }

    pub fn analyze(gpa: Allocator, memo: *Memo, width: u32, height: u32) !Field {
        var wins = try Field.init(gpa, width, height);

        for (0..width*height) |idx| {
            var field = try Field.init(gpa, width, height);
            defer field.deinit(gpa);

            field.eatIdx(idx);

            const win = try field.guaranteedWin(gpa, memo, false);
            wins.cells[idx] = !win;
        }

        return wins;
    }

    fn guaranteedWin(self: *Field, gpa: Allocator, memo: *Memo, p1: bool) !bool {
        var start: u64 = 0;

        if (self.nextMove(0) == null) return true;
        if (memo.recall(self.*)) |w| return w;

        while (self.nextMove(start)) |pos| : (start = pos+1) {
            var field = try self.clone(gpa);
            defer field.deinit(gpa);

            field.eatIdx(pos);

            const w = try field.guaranteedWin(gpa, memo, !p1);
            try memo.remember(field, w);
            if (!w) return true;
        }

        return false;
    }
};

fn parseArgs(gpa: Allocator) ![2]u32 {
    var args = try std.process.argsWithAllocator(gpa);
    defer args.deinit();

    std.debug.assert(args.skip());
    const width = args.next() orelse return error.ArgsExhaustion;
    const height = args.next() orelse return error.ArgsExhaustion;

    return [2]u32{
        try std.fmt.parseInt(u32, width, 0),
        try std.fmt.parseInt(u32, height, 0),
    };
}

pub fn main() !void {
    var dbg = std.heap.DebugAllocator(.{}).init;
    const gpa = dbg.allocator();

    const width, const height = parseArgs(gpa) catch |err| switch (err) {
        error.ArgsExhaustion => @panic("Expected at least 2 arguments"),
        error.InvalidCharacter,
        error.Overflow => @panic("First two arguments must be parsable by std.fmt.parseInt(u32, buf, 0)"),
        else => return err,
    };

    var memo = Memo.init(gpa);
    defer memo.deinit();

    const wins = try Field.analyze(gpa, &memo, width, height);
    wins.print();
}
