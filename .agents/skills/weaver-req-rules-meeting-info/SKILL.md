---
name: weaver-req-rules-meeting-info
description: "Use when changing what LARP reads from Microsoft Teams or the calendar, how meetings are matched to calls, or how names reach participants."
---

# Business rules

## teams-meeting

- Only the main process of Microsoft Teams (`com.microsoft.teams2`) is read; the classic Teams is not.
- Teams is in a meeting while one of its windows holds the element whose web identifier is `call-duration-custom`; window titles and texts shown by Teams are never used to decide it, because they change with the language of Teams.
- The title of the meeting is the title of the window holding that element, without the ending " | Microsoft Teams"; a title left empty, or equal to the name of a section of Teams, counts as no title.
- The people are read from the list of participants of the meeting while Teams shows it; the person speaking is read from the mark Teams puts on whoever speaks, when Teams exposes it. A name is kept trimmed and without the additions Teams writes after it, such as "(Ospite)" or "(Guest)"; the user's own name, as Teams writes it for "you", is left out.
- Teams is read every 2 seconds and at every change Teams announces, at most once every 250 ms; when a reading finds no element at all, LARP asks Teams to expose its interface to assistive apps, then reads again.
- The timeline of speakers of a call holds one span per change, with the elapsed time of its start, the elapsed time of its end and the name, or no name when nobody is marked; spans shorter than 300 ms are dropped.

## calendar-access

- Calendars read: every calendar of the Mac's events.
- **Event in progress** when a recording starts: among the events that are not all-day and whose start is at or before that moment and whose end is after it, the one that started last; with none, no event.
- **Prossime**: the events of today that are not all-day, start later than now and hold, in their URL, location or notes, a link of a known call app: `teams.microsoft.com` or `teams.live.com` (Microsoft Teams), `zoom.us` (Zoom), `meet.google.com` (Google Meet), `webex.com` (Webex), `facetime.apple.com` (FaceTime); at most three, by start; read again when the popover opens.
- The invited people of an event are its attendees with a name, without the user; their number in the proposal counts the user too.
