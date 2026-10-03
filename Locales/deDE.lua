-- Deutsch.
local _, ns = ...

ns.RegisterLocale("deDE", function(L)
    -- "Aktualisiert: %s her" below: "3 Tage her", "wenige Sekunden her".
    L["a moment"] = "wenige Sekunden"

    -- Chat
    L["/grecipes - your own professions"] = "/grecipes - deine eigenen Berufe"
    L["/grecipes <name> - the professions of a guild member"] = "/grecipes <Name> - die Berufe eines Gildenmitglieds"
    L["/grecipes status - what the addon knows and is doing"] = "/grecipes status - was das Addon weiß und gerade tut"
    L["/grecipes sync - ask the guild for missing data now"] = "/grecipes sync - fehlende Daten jetzt bei der Gilde anfragen"
    L["/grecipes probe - test report for the addon's author"] = "/grecipes probe - Testbericht für den Autor des Addons"
    L["/grecipes language [code|auto] - language of the addon's texts"] = "/grecipes language [Code|auto] - Sprache der Texte des Addons"
    L["/grecipes debug - show the sync log in the chat"] = "/grecipes debug - das Synchronisierungsprotokoll im Chat anzeigen"
    L["/grecipes reset - forget the data of your current guild"] = "/grecipes reset - die Daten deiner aktuellen Gilde vergessen"
    L["version %s. Saved data loaded by the client: %s."] = "Version %s. Gespeicherte Daten vom Client geladen: %s."
    L["you are not in a guild (or the guild has not loaded yet)."] = "du bist in keiner Gilde (oder die Gilde ist noch nicht geladen)."
    L["guild %s: data on %d |4member:members;, %d of them with recipes."] = "Gilde %s: Daten zu %d |4Mitglied:Mitgliedern;, davon %d mit Rezepten."
    L["no recipes"] = "keine Rezepte"
    L["recipes not read yet: open the profession once"] = "Rezepte noch nicht gelesen: öffne den Beruf einmal"
    L["%d |4recipe:recipes;"] = "%d |4Rezept:Rezepte;"
    L["sync: %s"] = "Synchronisierung: %s"
    L["sync log on."] = "Synchronisierungsprotokoll an."
    L["sync log off."] = "Synchronisierungsprotokoll aus."
    L["languages: %s, or auto for the client's."] = "Sprachen: %s, oder auto für die des Clients."
    L["language set to %s. Type /reload to update every window."] = "Sprache auf %s gesetzt. Gib /reload ein, um alle Fenster zu aktualisieren."
    L["this forgets what you know about your current guild. Type /grecipes reset confirm to do it."] = "damit vergisst du alles, was du über deine aktuelle Gilde weißt. Gib /grecipes reset confirm ein, um es zu tun."
    L["data of your current guild forgotten."] = "Daten deiner aktuellen Gilde vergessen."
    L["open these profession windows once so your recipes can be shared with the guild: %s."] = "öffne diese Berufsfenster einmal, damit deine Rezepte mit der Gilde geteilt werden können: %s."
    L["running the probe; the report opens in a few seconds."] = "Test läuft; der Bericht öffnet sich in wenigen Sekunden."

    -- Sync
    L["a guild member uses a newer version of Guild Professions & Recipes that this one cannot talk to. Please update."] = "ein Gildenmitglied nutzt eine neuere Version von Guild Professions & Recipes, mit der diese nicht kommunizieren kann. Bitte aktualisiere das Addon."
    L["a newer version of Guild Professions & Recipes (%s) is in use in your guild."] = "in deiner Gilde wird eine neuere Version von Guild Professions & Recipes (%s) verwendet."
    L["sync finished: %d |4record:records; received from %s."] = "Synchronisierung abgeschlossen: %d |4Eintrag:Einträge; von %s erhalten."
    L["a sync is already running."] = "es läuft bereits eine Synchronisierung."
    L["nobody online has data you are missing."] = "niemand, der online ist, hat Daten, die dir fehlen."
    L["asking the guild for missing data..."] = "frage die Gilde nach fehlenden Daten..."
    L["waiting for offers"] = "warte auf Angebote"
    L["receiving from %s (%d |4record:records; so far)"] = "empfange von %s (bisher %d |4Eintrag:Einträge;)"
    L["sending to %d |4member:members;"] = "sende an %d |4Mitglied:Mitglieder;"
    L["%d |4message:messages; queued (%d |4part:parts;)"] = "%d |4Nachricht:Nachrichten; in der Warteschlange (%d |4Teil:Teile;)"
    L["paused: addon messages are blocked here"] = "pausiert: Addon-Nachrichten sind hier gesperrt"
    L["idle"] = "inaktiv"

    -- Roster
    L["Professions"] = "Berufe"
    L["Shared by Guild Professions & Recipes. Point at an icon for the skill, click it for the recipes."] = "Geteilt von Guild Professions & Recipes. Zeige auf ein Symbol, um die Fertigkeit zu sehen, und klicke darauf für die Rezepte."
    L["This member does not share recipes (Guild Professions & Recipes is not installed)."] = "Dieses Mitglied teilt keine Rezepte (Guild Professions & Recipes ist nicht installiert)."
    L["Skill %d/%d"] = "Fertigkeit %d/%d"
    L["Click to see the recipes."] = "Klicken, um die Rezepte zu sehen."
    L["Recipes not shared yet: this member has to open the profession once."] = "Rezepte noch nicht geteilt: Dieses Mitglied muss den Beruf einmal öffnen."
    L["Updated %s ago"] = "Aktualisiert: %s her"

    -- Profession window
    L["Recipe #%d"] = "Rezept #%d"
    L["Other"] = "Sonstiges"
    L["and %d more"] = "und %d weitere"
    L["Creates %d-%d"] = "Erzeugt %d-%d"
    L["Creates %d"] = "Erzeugt %d"
    L["Also known by: %s"] = "Ebenfalls bekannt bei: %s"
    L["Nobody else in the guild is known to have this recipe."] = "Von niemandem sonst in der Gilde ist bekannt, dass er dieses Rezept hat."
    L["your own data"] = "deine eigenen Daten"
    L["from the member"] = "vom Mitglied selbst"
    L["passed on by the guild"] = "von der Gilde weitergegeben"
    L["%d of %d |4recipe:recipes;"] = "%d von %d |4Rezept:Rezepten;"
    L["View live"] = "Live ansehen"
    L["Opens the game's own profession window for this member. Only while they are online."] = "Öffnet das Berufsfenster des Spiels für dieses Mitglied. Nur solange es online ist."
    L["Select a recipe."] = "Wähle ein Rezept aus."
    L["Reagents:"] = "Reagenzien:"
    L["The game gives no reagents for this recipe here; point at the icon for its details."] = "Das Spiel nennt hier keine Reagenzien für dieses Rezept; zeige auf das Symbol für die Details."
    L["no data on %s yet."] = "noch keine Daten zu %s."
    L["none of your recipes have been read yet: open each profession window once."] = "noch keines deiner Rezepte wurde gelesen: öffne jedes Berufsfenster einmal."
    L["%s has not shared any recipes yet."] = "%s hat noch keine Rezepte geteilt."

    -- Probe
    L["Press Ctrl+A, then Ctrl+C, and paste the text to the addon's author."] = "Drücke Strg+A, dann Strg+C, und schicke den Text an den Autor des Addons."
end)
