# To-do

- [ ] improved/clearer scheduling
  - [ ] Convert RconClient to polling
  - [ ] Convert `Event` to be a Bot-related class that hooks into the Bots loop
  - [ ] Expose `Bot:step` to run a single scheduler step -- expose so others can
        integrate with their platform/own schedulers. Prevent external calls
        when using `Bot:run`.
  - [ ] Expose `Bot:connect` to connect to the server, EMPHASISE that this does
        _not_ start the loop. Prevent multiple calls.
  - [ ] Rework `Bot:run` to call both `Bot:step` and `Bot:connect`.
- [ ] platform independence
  - [ ] WebSocket impl for Lute and Zune
  - [ ] Switch to json.luau for pure luau json parsing
