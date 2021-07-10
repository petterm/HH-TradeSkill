### TODO:
- Gotta fix enchantings ID prefix. enchant:nnn is bullshit.
  Cant seem to find a way to get the item from the crafting spell.
  I think Ill have to live with it. Can still see the crafters on them in AtlasLoot.

### Comm:
```
On login
> COMM_UPDATE GUILD - Send my DB to everyone

On updated recipes
> COMM_UPDATE GUILD - Only the updated data
    If efficient it could send all, or send all once then throttle for some time

Manually
> COMM_REQUEST_FULL - To a selected player
< COMM_UPDATE_FULL - Full db sent back
```

### Communication ideas
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


