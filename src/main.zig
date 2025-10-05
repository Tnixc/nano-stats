const std = @import("std");

// Define our C interface to the Swift code
extern fn nano_stats_run() void;

pub fn main() !void {
    // Run the SwiftUI application
    nano_stats_run();
}
