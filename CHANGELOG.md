# Changelog

## 0.7.1 - Side tabs that fit

- **Fixed**: in the guild's recipe window, every profession with shared recipes gets its side tab. Before, only the first 8 were shown.
- The side tabs keep the game's size while they fit, and shrink together to fit the window's height when there are more.

## 0.7.0 - The guild's recipes

- **Recipes & Orders tab** on the guild window: every profession as a button.
  - A profession that some guildmate has shared recipes of opens the recipe window on all of them together.
  - The others are disabled, and their tooltip says why.
- **The guild's recipes** in the recipe window: every recipe of a profession that any guildmate knows, each listed once and showing who knows it. Side tabs switch between the guild's professions.
- **Like the game's window**, the filters and the search are cleared when you switch to another profession.
- Crafting orders are still to come; the **Request an order** button stays disabled until then.

## 0.6.0 - A recipe window like the game's

- **Recipe window redesigned** to look like the game's own profession window. It has the same frame and art and the skill bar. The recipe panel shows the item each recipe makes, its description and its reagents with how many you carry. Side tabs switch between the member's professions.
- **Saved data is labelled**: the window says the recipes are saved data, how old they are and where they came from.
- **Your own professions** open in the game's own profession window when you click them in the roster. Guildmates' professions open their saved recipes.
- **Filter menu**:
  - **Have Materials** shows the recipes whose reagents you carry in your bags.
  - **Slots** filters by where the item is worn, with **Created Items** for everything else.
  - A button clears the filters.
- **Search** also finds recipes by the item they make and by their reagents.
- Reagent counts update as your bags change.
- **Coming soon**: crafting orders between guildmates, in a later version. For now, a **Recipes & Orders** tab on the guild window and a **Request an order** button in the recipe window are shown but disabled.
- **Fixed**: recipes are listed under the game's own profession categories. Before, they were grouped by item type unless a profession window was open.

## 0.5.0 - First release

- **Professions column** in the guild Roster: one icon per profession for each member, with the skill level on hover. Click an icon to open that member's recipes.
- **Recipe window**: browse a member's recipes by category, search them, and see the reagents, what each recipe makes and who else in the guild knows it. It works while the member is offline.
- **Automatic sharing** through hidden addon messages, plus a sync at login, so you also see guildmates you never meet online.
- **All your characters**: your alts get their recipes without opening every profession window.
- **Translated into every client language**: English, German, Spanish, French, Italian, Korean, Portuguese, Russian and Chinese.
