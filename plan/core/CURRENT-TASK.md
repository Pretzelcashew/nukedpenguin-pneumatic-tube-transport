Target Task: Projector Refactor Task 3 — Obstacle Clearance & Corridor Regrowth
Pacing: Break this into phases: patch 1 file at a time and wait for me to say "next".
Current Working Baseline:
Clean commit fix(projector): suppress forward reticle snap and reschedule probe arrival on obstacle interception.
Backward truncation on direct/rear obstacles is verified working.
Forward obstacles smoothly update flight horizon without snapping.
Immediate Goal for This Chat:
When an obstruction clears (mined/removed, gate opened, or character moves), wake up the blocked reticle so it resumes probing forward from its collision face to its original intended reach (max_reach), drawing the remaining trail dots cleanly without resetting or flickering the existing upstream trail.
Please output Query 1 for aggregator_patcher.py.