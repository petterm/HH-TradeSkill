### TODO:

- Add player skills from opening proffession link for that player
  - Only if player is in guild
- Improve player list in tooltip
  - Put online players first
  - ~~Add limit to total shown, maybe with "+N" after~~
    - Added.
    - Is 8 too high?
  - ~~Sort by name?~~
  - Anything with guild-alt-main stuff?
- ~~Add login version broadcast~~
  - ~~Print notice of newer versions available~~
- Gotta fix enchantings ID prefix. enchant:nnn is bullshit.
  Cant seem to find a way to get the item from the crafting spell.
  I think Ill have to live with it. Can still see the crafters on them in AtlasLoot.
- ~~Depending on broadcast updates below might want to split db per character instead~~


### Communication ideas

Updates to current version

- When player comes online
  - Respond to their broadcast with localDB

Inventory summary

- Add a SharedDBSummary
  - characterName: lastUpdated timestamp
- Broadcast summary to guild
  - Players check their data
    - If broadcast has new data, request it
    - If local data is newer, send it (or announce it)

Online leader

- Somehow decide on a player online with addon to be the 'leader'
  - When new player comes online, leader full-syncs with them, both ways
  - When leader goes offline, hand over leadership to someone else

