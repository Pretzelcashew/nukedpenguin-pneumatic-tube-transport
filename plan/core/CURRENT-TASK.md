task 2 of projector refactor (task 3 is completed)

we already handle the reticle obstruction, but the goal to make it not look so extremely abrupt is to make a new orphaned reticle head with a formed tail down stream
i was advised to not try to adopt the existing dots and reticle head for the newly severed orphan. i think we could do that, and just make an entirely new reticle but formed with an anti reticle at the tip of its tail. 
we will need to do a simple bvh bound leaf scan to find how much of the newly formed  orphan reticle tail shoudl be cut off, and place the anti reticle there, the anti reticle does this job anyway.


this will be attempt 2 on this task, the other gemini instance failed.