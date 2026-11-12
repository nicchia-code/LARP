---
description: Use when changing what LARP reads from Microsoft Teams or the calendar, how meetings are matched to calls, or how names reach participants.
---
# Meeting information rules

## teams-meeting
- Only the main process of Microsoft Teams (`com.microsoft.teams2`) is read; the classic Teams is not.
- Teams is in a meeting while one of its windows holds the element whose web identifier is `call-duration-custom`; window titles and texts shown by Teams are never used to decide it, because they change with the language of Teams.
- The title of the meeting is the title of the window holding that element, without the ending " | Microsoft Teams"; a title left empty, or equal to the name of a section of Teams, counts as no title.
- The people are read from the list of participants of the meeting while Teams shows it; the person speaking is read from the mark Teams puts on whoever speaks, when Teams exposes it. A name is kept trimmed and without the additions Teams writes after it, such as "(Ospite)" or "(Guest)"; the user's own name, as Teams writes it for "you", is left out.
- Teams is read only while the Accessibility permission is granted, Teams runs, and Teams uses the microphone or a recording is going on; "Rileva le call" and the watched apps do not matter. When the reading stops being needed, the walk in progress is abandoned and nothing more is asked to Teams.
- Teams is read every 2 seconds, and sooner when Teams opens a window or changes the title of a window; never in the 3 seconds after Teams opened a window, and never sooner than 1 second after the end of the previous reading. Only one reading runs at a time.
- Until the window of the meeting is found, a reading visits every window of Teams; once it is found, readings visit only that window while Teams still has it, and every window again when it is gone. A reading visits at most 5,000 elements and lasts at most 1 second, and each request to Teams waits at most 0.25 seconds; a reading that reaches a limit stops with what it found so far.
- During a recording, the first title of the meeting read from Teams replaces a meeting title the call took from the calendar event in progress; a meeting title already taken from Teams is never replaced, and a title typed by the user is never touched.
- A reading that reaches a limit without finding the element of the meeting leaves the meeting as it was: it never counts as the meeting being left.
- A reading that reaches the limit of elements or of time doubles the pause before the next reading, starting from 2 seconds, up to 30 seconds; a reading that ends within both limits brings the pace back to every 2 seconds.
- When a reading finds no web identifier at all, LARP asks Teams to expose its interface to assistive apps and reads again; it asks at most once for each launch of Teams. After 3 readings in a row without any web identifier since that request, that launch of Teams is not read again until Teams quits and is launched again.
- The web identifiers `call-duration-custom`, `roster-participant` and `active-speaker` have not been verified on a real Teams; they are checked with the verification script and corrected by a later change.
- The timeline of speakers of a call holds one span per change, with the elapsed time of its start, the elapsed time of its end and the name, or no name when nobody is marked; spans shorter than 300 ms are dropped.

## calendar-access
- Calendars read: every calendar of the Mac's events.
- **Event in progress** when a recording starts: among the events that are not all-day and whose start is at or before that moment and whose end is after it, the one that started last; with none, no event.
- **Prossime**: the events of today that are not all-day, start later than now and hold, in their URL, location or notes, a link of a known call app: `teams.microsoft.com` or `teams.live.com` (Microsoft Teams), `zoom.us` (Zoom), `meet.google.com` (Google Meet), `webex.com` (Webex), `facetime.apple.com` (FaceTime); at most three, by start; read again when the popover opens.
- The invited people of an event are its attendees with a name, without the user; their number in the proposal counts the user too.
