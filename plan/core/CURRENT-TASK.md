look, i want to overhaul how we're updating visual positions for moving capsules so we don't choke the game when things get crowded, but without creating visual jank or jitter.

remember, in factorio multiplayer, the simulation is lockstep. if player 1 is looking at 40 capsules on nauvis, and player 2 is looking at 40 capsules on gleba, every connected computer has to process all 80 of them. the total workload is collective. 

here is what we CANNOT do:
1. we can't recalculate and update 100+ observed capsules every single frame—that murders UPS.
2. we can't do a lazy blanket gate where nothing happens for 5 frames and then all 100 capsules slam the CPU at once on the 6th frame. that causes an ugly sawtooth spike.
3. we CANNOT have capsules take turns moving on different frames! if capsule A moves on frame 1 while capsule B behind it freezes until frame 3, the line stretches and snaps like an accordion. in a factory game, things taking turns looks completely broken—it makes players think a pipe just jammed or lost pressure. visible capsules must move in lockstep unison.
4. we can't have the frame rate flip-flop violently every tick if the count flickers around a cutoff number. it needs to transition smoothly.

here is the actual architecture i want:

1. dynamic global roughness based on collective observed count: track the total number of capsules currently being observed across all players (visible in viewports + alt mode on). when the factory is quiet and all players collectively are only looking at a handful of capsules, run full 1-tick smooth movement (60 FPS). as the collective count climbs, adaptively step the cadence down (like 60 FPS -> 30 FPS -> 20 FPS). 

2. graceful, damped cadence transitions: the change in visual cadence must be gradual and reactive with hysteresis so it doesn't flicker between cadences on boundary fluctuations. use a smoothed average or a schmitt-trigger buffer (e.g. don't drop to 30 FPS until 30 capsules, and don't climb back to 60 FPS until it drops below 18). BUT if there is a massive sudden queue shift (like someone zooming way out over a 200-capsule train yard), immediately drop the cadence to prevent a freeze frame.

3. amortize the math ahead of the render tick: when running at a lower cadence, DO NOT wait for the render frame to do all the math! slice the closed-form interpolation math across the intervening quiet ticks leading up to the render frame. because position is closed-form math, we can easily calculate on tick 2 where a capsule will be on tick 6.

4. pre-allocated high-water buffer with amortized decay: store those pre-calculated future coordinates in a reusable pooled scratch buffer. follow the exact high-water mark and buffer decay pattern we already use across the mod (like in our binary heaps and BVH trees) so we get zero table allocations and zero Lua garbage collection thrash.

5. lockstep flush on the render frame: when the render tick arrives, all the heavy math is already finished. the render loop just executes a blazing-fast pass piping those pre-calculated coordinates straight into the render objects all at once in lockstep. no accordion effect, no staggered turns. relative spacing stays 100% rigid.

6. event-driven invalidation: if an obstacle changes, a gate closes, or a pipe is mined mid-flight, our spatial BVH and blocker tables already catch it in O(1) time. just flag that corridor/buffer slot as dirty and recompute it. invalidation is easy.

7. sleep when idle: if players look away, walk into the woods, or nothing is flying, none of this runs. zero math, zero buffering, zero profiler time.

wire this collective observation governor and pre-calculation buffer into our rendering pipeline, keep the math clean, and make sure our profiler line stays completely flat without any visual hitching.