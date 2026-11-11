# Teams meeting

The meeting Microsoft Teams shows at this moment, as LARP reads it while Teams access is allowed: its title, the people in it and who is speaking. While a recording is going on, who Teams marks as speaking is kept with the call being recorded, as a timeline of names, and the names of the people read are kept with it as names for its participants.

## States

### No meeting (initial)
Teams is not running, shows no meeting, or cannot be read.
- `teams.MEETING_JOINED` → In a meeting: only while Teams access is allowed; the title of the meeting is kept when it can be read. While a recording is going on, the call being recorded takes it as its meeting title if it has none yet.

### In a meeting
Teams shows a meeting. While Teams access is allowed and a recording is going on, the proposal, the popover and the live window show its title and the number of people in it when known.
- `teams.PARTICIPANTS_READ` → In a meeting: the names replace the people known; while a recording is going on, the names not already kept are added to the names for the participants of the call being recorded.
- `teams.SPEAKER_CHANGED` → In a meeting: the person speaking is the new one, or nobody; while a recording is going on, and not while it is paused, the change is added to the timeline of speakers of the call being recorded at the elapsed time.
- `teams.MEETING_LEFT` → No meeting: title, people and speaker are forgotten; what was kept with a call stays.
- `teams-access.ACCESS_LOST` → No meeting: title, people and speaker are forgotten; what was kept with a call stays.
