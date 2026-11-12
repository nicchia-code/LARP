# Teams meeting

The meeting Microsoft Teams shows at this moment, as LARP reads it while Teams access is allowed and the reading is needed: only while Teams uses the microphone or a recording is going on, whether or not call detection is on and Teams is watched. It reads its title, the people in it and who is speaking. While a recording is going on, who Teams marks as speaking is kept with the call being recorded, as a timeline of names, and the names of the people read are kept with it as names for its participants. The reading is kept light so that Teams is never slowed down: few readings, limited to the window of the meeting once it is found, and slower when Teams answers slowly; a Teams that exposes nothing to LARP is left alone until it is launched again.

## States

### No meeting (initial)
Teams is not running, shows no meeting, cannot be read, or is not read because it does not use the microphone and no recording is going on.
- `teams.MEETING_JOINED` → In a meeting: only while Teams access is allowed and Teams is being read, that is while Teams uses the microphone or a recording is going on; the title of the meeting is kept when it can be read. While a recording is going on, the call being recorded takes it as its meeting title if it has none yet, or if the one it has came from the calendar event in progress: the first title read from Teams during the recording replaces the title of the calendar; a title typed by the user is never touched.

### In a meeting
Teams shows a meeting. While Teams access is allowed and a recording is going on, the proposal, the popover and the live window show its title and the number of people in it when known.
- `teams.PARTICIPANTS_READ` → In a meeting: the names replace the people known; while a recording is going on, the names not already kept are added to the names for the participants of the call being recorded.
- `teams.SPEAKER_CHANGED` → In a meeting: the person speaking is the new one, or nobody; while a recording is going on, and not while it is paused, the change is added to the timeline of speakers of the call being recorded at the elapsed time.
- `teams.MEETING_LEFT` → No meeting: title, people and speaker are forgotten; what was kept with a call stays.
- `teams-access.ACCESS_LOST` → No meeting: title, people and speaker are forgotten; what was kept with a call stays.
- `macos.CALL_APP_MIC_STOPPED` → No meeting: only when Microsoft Teams stops using the microphone and no recording is going on; the reading of Teams stops, title, people and speaker are forgotten; what was kept with a call stays.
- `recorder.RECORDING_STOPPED` → No meeting: only while Microsoft Teams does not use the microphone; the reading of Teams stops, title, people and speaker are forgotten; what was kept with the call stays.
