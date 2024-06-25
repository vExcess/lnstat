const std = @import("std");

pub fn main() !void {
    var generalPurposeAllocator = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = generalPurposeAllocator.deinit();
    const allocator = generalPurposeAllocator.allocator();

    // find path to executable
    const exe_path = try std.fs.selfExePathAlloc(allocator);
    defer allocator.free(exe_path);
    const opt_exe_dir = std.fs.path.dirname(exe_path);

    if (opt_exe_dir) |dir| {
        // get args passed to zig
        const zigArgs = try std.process.argsAlloc(allocator);
        defer std.process.argsFree(allocator, zigArgs);

        // locate js file
        const jsFilePath = try std.mem.join(allocator, "", &.{dir, "/lnstat.js"});

        // create ["node", jsFilePath, ...zigArgs.slice(1)]
        var argsList = try std.ArrayList([]const u8).initCapacity(allocator, 8);
        defer {
            for (argsList.items) |arg| allocator.free(arg);
            argsList.deinit();
        }
        try argsList.append("node");
        try argsList.append(jsFilePath);
        try argsList.appendSlice(zigArgs[1..]);
        const argsSlice = try argsList.toOwnedSlice();

        // run js program via node
        var child = std.ChildProcess.init(argsSlice, allocator);
        try child.spawn();
        _ = try child.wait();
    } else {
        std.debug.print("Failed to locate lnstat.js", .{});
    }
}