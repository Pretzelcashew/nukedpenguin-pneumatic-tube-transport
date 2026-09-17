fix reticle head obstruction so it doesnt jump backward based on the prospective flight path position, in other words, theres a bug where the obstacle (like a character walking away from the reticle as it moves toward the player), then the character turns back toward the reticle, and the reticle's collision for jumping back to the position of the obstacle is erroneously using the prospective flight path position rather than the spatiotemporal head position, so it looks like the head is jumping forward to the obstacle, cheating time.





<s>soft-remove the ability for reitcles that are orphaned, to be split candidates</S>




<s>fix the new projector reticle so orphaned reticles never turn cyan, or if they are cyan turn to the normal orange color. just a simple efficient assureance at the efficient check state, no brute forces. 

for reticles reaching their max distance, one final check at the reticle is needed to ensure we dont miss a projector right at the reticles edge, and also when a projector comes into existence we need to bvh hit test for a reticle that is in this max state so we dont miss a connection. it literally is an edge case.

picture shown of the edge case. if you have a better more efficient idea, im all ears. i just am concerned about this edge case treatment honestly, like if its going to end up in odd collision expansion. i have an idea though, when the reticle does reach its max distance, we could stretch that least bvh leaf slightly in one direction to pick up these hair instances? right? we jsut have to be sure this small stretch isnt going to impact any spatiotemporal calculations? if it does then we need a different approach.</s>