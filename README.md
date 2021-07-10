TODO:
- Gotta fix enchantings ID prefix. enchant:nnn is bullshit.
  Some things are spells and some are items (like oils)

On login
> COMM_UPDATE GUILD - Send my DB to everyone

On updated recipes
> COMM_UPDATE GUILD - Only the updated data
    If efficient it could send all, or send all once then throttle for some time

Manually
> COMM_REQUEST_FULL - To a selected player
< COMM_UPDATE_FULL - Full db sent back


Full broadcast
- Request GUILD
- Response update WHISPER
  - Only personal data 
  - Current character or all my characters?

- Request full WHISPER - Get all data from a selected person
- Respons full WHISPER

- Broadcast GUILD
  - Personal data sent to all
  - On login?

- Broadcast update
  - Only new recipe
  - When added


