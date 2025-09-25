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

    fn hash(_: *Memo, key: []u32) u64 {
        var hasher = std.hash.Wyhash.init(0);
        std.hash.autoHashStrat(&hasher, key, .Deep);
        return hasher.final();
    }

    fn remember(self: *Memo, field: Field, win: bool) !void {
        const h = self.hash(field.alive);
        try self.wins.put(h, win);
    }

    fn recall(self: *Memo, field: Field) ?bool {
        const h = self.hash(field.alive);
        return self.wins.get(h);
    }
};

const Field = struct {
    wdt: u32,
    hgt: u32,
    alive: []u32, // calculated from top to bottom, how many cells still on the field

    pub fn init(gpa: Allocator, width: u32, height: u32) !Field {
        const alive = try gpa.alloc(u32, width);
        @memset(alive, height);

        return .{
            .wdt = width,
            .hgt = height,
            .alive = alive,
        };
    }

    pub fn deinit(self: Field, gpa: Allocator) void {
        gpa.free(self.alive);
    }

    pub fn print(self: Field) void {
        for (0..self.hgt) |h| {
            for (0..self.wdt) |w| {
                const alive = self.alive[w];
                std.debug.print("{d} ", .{@intFromBool(h < alive)}); //NOTE, print as either 0/1
            }

            std.debug.print("\n", .{});
        }
    }

    pub fn clone(self: Field, gpa: Allocator) !Field {
        return .{
            .wdt = self.wdt,
            .hgt = self.hgt,
            .alive = try gpa.dupe(u32, self.alive),
        };
    }

    fn eat(self: Field, x: u32, y: u32) void {
        if (x >= self.wdt or y >= self.hgt) @panic("TODO, figure out how tf this happened"); // oob check

        for (x..self.wdt) |w| {
            if (self.alive[w] > y)
                self.alive[w] = y;
        }
    }

    fn eatIdx(self: Field, idx: u64) void {
        self.eat(@intCast(idx % self.wdt), @intCast(idx / self.wdt));
    }

    fn nextMove(self: Field, start: u64) !?u64 {
        for (start..self.wdt*self.hgt) |pos| {
            const x = pos % self.wdt;
            const y = pos / self.wdt;

            if (self.alive[x] > y) return pos;
        }

        return null;
    }

    pub fn analyze(gpa: Allocator, memo: *Memo, width: u32, height: u32) ![]bool {
        const wins = try gpa.alloc(bool, width*height);

        for (0..width*height) |idx| {
            std.debug.print("{d} cells remaining\n", .{width*height-idx});

            var timer = try std.time.Timer.start();
            var field = try Field.init(gpa, width, height);
            defer field.deinit(gpa);

            field.eatIdx(idx);

            const win = try field.guaranteedWin(gpa, memo);
            wins[idx] = !win;

            const lap = timer.lap();
            std.debug.print("took {}ns, {}ms, {}s\n\n", .{lap, lap/1000000, lap/1000000000});
        }

        return wins;
    }

    fn guaranteedWin(self: *Field, gpa: Allocator, memo: *Memo) !bool {
        var start: u64 = 0;

        if (try self.nextMove(0) == null) return true;
        if (memo.recall(self.*)) |w| return w;

        while (try self.nextMove(start)) |pos| : (start = pos+1) {
            var field = try self.clone(gpa);
            defer field.deinit(gpa);

            field.eatIdx(pos);

            const w = try field.guaranteedWin(gpa, memo);
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
    //var dbg = std.heap.DebugAllocator(.{}).init;
    //const gpa = dbg.allocator();
    const gpa = std.heap.smp_allocator;

    const width, const height = parseArgs(gpa) catch |err| switch (err) {
        error.ArgsExhaustion => @panic("Expected at least 2 arguments"),
        error.InvalidCharacter,
        error.Overflow => @panic("First two arguments must be parsable by std.fmt.parseInt(u32, buf, 0)"),
        else => return err,
    };

    var memo = Memo.init(gpa);
    defer memo.deinit();

    const wins = try Field.analyze(gpa, &memo, width, height);
    defer gpa.free(wins);

    for (0..height) |h| {
        for (0..width) |w| {
            std.debug.print("{} ", .{@intFromBool(wins[w+h*width])});
        }

        std.debug.print("\n", .{});
    }
}
