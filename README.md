# hubot-acquia-log

A hubot script that does the things

See [`src/acquia-log.coffee`](src/acquia-log.coffee) for full documentation.

## Installation

In hubot project repo, run:

`npm install hubot-acquia-log --save`

Then add **hubot-acquia-log** to your `external-scripts.json`:

```json
["hubot-acquia-log"]
```

## Notes

Needless to say, streaming logs into your chat room may introduce a lot of noise.
The script emits a `acquiaLogMessageLine` event which others scripts can hook
into - here you could filter the messages you want to display in your chat room.
