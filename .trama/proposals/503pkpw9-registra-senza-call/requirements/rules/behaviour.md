---
description: Use when implementing call detection, transcript assembly, names and titles, search or export.
---
# Behaviour rules

## recorder
- Known call apps, by bundle identifier: Zoom (`us.zoom.xos`), Microsoft Teams (`com.microsoft.teams2`, `com.microsoft.teams`), FaceTime (`com.apple.FaceTime`), Slack (`com.tinyspeck.slackmacgap`), Discord (`com.hnc.Discord`), Webex (`Cisco-Systems.Spark`, `com.webex.meetingmanager`), and the browsers Safari (`com.apple.Safari`), Chrome (`com.google.Chrome`), Edge (`com.microsoft.edgemac`), Firefox (`org.mozilla.firefox`), Arc (`company.thebrowser.Browser`), Brave (`com.brave.Browser`).
- The list is defined in one place in the code so it can be extended.
- A call app that starts using the microphone while a proposal or a recording already exists does not create a second one.
- A recording tied to a call app ends when that app stops using the microphone, even if another known call app is still using it.

## call
- Live and file transcription produce the same kind of lines; a call's transcript is the lines of both tracks merged in order of start time.
- Live transcription starts only if the chosen language is ready when the recording starts; a language that becomes ready during a recording does not start it halfway.
- A call without a title is shown as "Call del <day> <month> <year>, <hh:mm>" when it is tied to a call app, and as "Registrazione del <day> <month> <year>, <hh:mm>" when it has no call app (started by hand), with the Italian month name, for example "Call del 27 ottobre 2026, 10:41" and "Registrazione del 28 ottobre 2026, 15:35".
- A participant without a name is shown as "Partecipante <number>"; "Me" is shown as "Io" and "Others" as "Altri".
- An empty title or empty name given by the user restores the default.
- Refinement sends, for every line of the call in order of start time: a line number, the original speaker as "Io" or "Partecipante <number>" (never a name given by the user), the start and end time and the original text. It never sends the audio, the title, the names given by the user, the dates or the call app.
- Refinement always starts from the original lines: a call refined before is sent with its original text and speakers, not with the refined ones.
- The assistant corrects any word recognised wrongly, in any language, for example English words inside Italian sentences; it never rephrases, summarises, translates or changes the style, and never merges, splits, adds or removes lines.
- The assistant may move a line from one participant to another participant of the same call; a "Me" line stays "Me" and no line becomes "Me".
- The answer is applied only when it has exactly one correction for every line sent, each with non-empty text and a speaker the line is allowed to have; otherwise nothing is applied and the refinement fails.
- A refinement that gets no complete answer within 10 minutes of starting fails.

## main-window
- Search matches the text typed, ignoring case and accents, against the title, the transcript text and the participant names; an empty search shows every call.
- Search and Markdown export use the text and speakers the call shows: refined, or original after a restore.
- Markdown export: an H1 with the call title, a line with date, time, duration and language, then one paragraph per line as `**<speaker>** [<mm:ss>]: <text>`; the default file name is the call title.

## settings
- The default transcription language at first launch is Italian.
- Transcript refinement is off by default.
- Launch at login is off by default.
