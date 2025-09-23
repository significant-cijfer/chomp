const std = @import("std");

const cwd = std.fs.cwd;
const indexOfScalarPos = std.mem.indexOfScalarPos;
const Allocator = std.mem.Allocator;

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

    // max range of a u32 * u32 is u64
    // have to think abt this range again lol TvT
    // 2^(2^64) ermmmm
    fn variants(self: Field) u64 {
        return std.math.pow(u64, 2, self.wdt*self.hgt);
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

    //Stappeplan,
    //  ga over alle varianten
    //  voor elke, zet elke mogelijke zet in
    //      voor elke, herhaal
    //  hou bij hoevaak elke zet gezet word, en wie won
    pub fn analyze(gpa: Allocator, width: u32, height: u32) !Scoreboard {
        var field = try Field.init(gpa, width, height);
        var board = try Scoreboard.init(gpa, width, height);
        defer field.deinit(gpa);

        try field.analyzeMoves(&board, gpa);
        return board;
    }

    fn analyzeMoves(self: *Field, board: *Scoreboard, gpa: Allocator) !void {
        var start: u64 = 0;

        while (self.nextMove(start)) |pos| : (start = pos+1) {
            var field = try self.clone(gpa);
            defer field.deinit(gpa);

            board.addMoveIdx(pos);
            field.eatIdx(pos);
            //field.print();

            try field.analyzeMoves(board, gpa);
        }
    }
};

const Scoreboard = struct {
    wdt: u32,
    hgt: u32,
    scores: []u64,

    pub fn init(gpa: Allocator, width: u32, height: u32) !Scoreboard {
        const scores = try gpa.alloc(u64, width*height);
        @memset(scores, 0);

        return .{
            .wdt = width,
            .hgt = height,
            .scores = scores,
        };
    }

    pub fn deinit(self: Scoreboard, gpa: Allocator) void {
        gpa.free(self.scores);
    }

    pub fn print(self: Scoreboard) void {
        std.debug.print("Board: {}x{}:\n", .{self.wdt, self.hgt});
        for (self.scores, 0..) |score, idx|
            std.debug.print("x: {}, y: {} => {}\n", .{idx % self.wdt, idx / self.wdt, score});
    }

    pub fn colorize(self: Scoreboard) !void {
        const max: f128 = @floatFromInt(std.mem.max(u64, self.scores));
        var buffer: [1024]u8 = undefined;

        const file = try cwd().createFile("out.ppm", .{});
        defer file.close();

        var writer = file.writer(&buffer); //kut buffer
        const fout = &writer.interface;

        try fout.print("P2 {d} {d} 255\n", .{self.wdt, self.hgt});
        for (self.scores) |score| {
            const s: f128 = @floatFromInt(score);
            const b: u8 = @intFromFloat(s/max*255);
            try fout.print("{d} ", .{b});
        }

        try fout.flush();
    }

    fn addMove(self: *Scoreboard, x: u32, y: u32) void {
        self.scores[x+y*self.wdt] += 1;
    }

    fn addMoveIdx(self: *Scoreboard, idx: u64) void {
        self.addMove(@intCast(idx % self.wdt), @intCast(idx / self.wdt));
    }
};

pub fn main() !void {
    var dbg = std.heap.DebugAllocator(.{}).init;
    const gpa = dbg.allocator();

    const width = 4;
    const height = 4;

    var field = try Field.init(gpa, width, height);
    defer field.deinit(gpa);

    field.print();
    std.debug.print("Field info:\n", .{});
    std.debug.print("Field.variants: {}\n", .{field.variants()});

    const board = try Field.analyze(gpa, width, height);
    defer board.deinit(gpa);

    board.print();
    try board.colorize();
}
