-- Italiano.
local _, ns = ...

ns.RegisterLocale("itIT", function(L)
    L["a moment"] = "un momento"

    -- Chat
    L["/grecipes - your own professions"] = "/grecipes - le tue professioni"
    L["/grecipes <name> - the professions of a guild member"] = "/grecipes <nome> - le professioni di un membro della gilda"
    L["/grecipes status - what the addon knows and is doing"] = "/grecipes status - cosa sa l'add-on e cosa sta facendo"
    L["/grecipes sync - ask the guild for missing data now"] = "/grecipes sync - chiedi ora alla gilda i dati mancanti"
    L["/grecipes probe - test report for the addon's author"] = "/grecipes probe - rapporto di prova per l'autore dell'add-on"
    L["/grecipes language [code|auto] - language of the addon's texts"] = "/grecipes language [codice|auto] - lingua dei testi dell'add-on"
    L["/grecipes debug - show the sync log in the chat"] = "/grecipes debug - mostra il registro di sincronizzazione nella chat"
    L["/grecipes reset - forget the data of your current guild"] = "/grecipes reset - dimentica i dati della tua gilda attuale"
    L["version %s. Saved data loaded by the client: %s."] = "versione %s. Dati salvati caricati dal client: %s."
    L["you are not in a guild (or the guild has not loaded yet)."] = "non sei in una gilda (o la gilda non è ancora stata caricata)."
    L["guild %s: data on %d |4member:members;, %d of them with recipes."] = "gilda %s: dati su %d |4membro:membri;, di cui %d con ricette."
    L["no recipes"] = "nessuna ricetta"
    L["recipes not read yet: open the profession once"] = "ricette non ancora lette: apri la professione una volta"
    L["%d |4recipe:recipes;"] = "%d |4ricetta:ricette;"
    L["sync: %s"] = "sincronizzazione: %s"
    L["sync log on."] = "registro di sincronizzazione attivato."
    L["sync log off."] = "registro di sincronizzazione disattivato."
    L["languages: %s, or auto for the client's."] = "lingue: %s, oppure auto per quella del client."
    L["language set to %s. Type /reload to update every window."] = "lingua impostata su %s. Scrivi /reload per aggiornare tutte le finestre."
    L["this forgets what you know about your current guild. Type /grecipes reset confirm to do it."] = "questo cancella ciò che sai della tua gilda attuale. Scrivi /grecipes reset confirm per farlo."
    L["data of your current guild forgotten."] = "dati della tua gilda attuale cancellati."
    L["open these profession windows once so your recipes can be shared with the guild: %s."] = "apri una volta queste finestre di professione perché le tue ricette possano essere condivise con la gilda: %s."
    L["running the probe; the report opens in a few seconds."] = "prova in corso; il rapporto si aprirà tra pochi secondi."

    -- Sync
    L["a guild member uses a newer version of Guild Professions & Recipes that this one cannot talk to. Please update."] = "un membro della gilda usa una versione più recente di Guild Professions & Recipes con cui questa non può comunicare. Aggiorna l'add-on."
    L["a newer version of Guild Professions & Recipes (%s) is in use in your guild."] = "nella tua gilda è in uso una versione più recente di Guild Professions & Recipes (%s)."
    L["sync finished: %d |4record:records; received from %s."] = "sincronizzazione completata: %d |4voce ricevuta:voci ricevute; da %s."
    L["a sync is already running."] = "è già in corso una sincronizzazione."
    L["nobody online has data you are missing."] = "nessuno online ha dati che ti mancano."
    L["asking the guild for missing data..."] = "richiesta dei dati mancanti alla gilda..."
    L["waiting for offers"] = "in attesa di offerte"
    L["receiving from %s (%d |4record:records; so far)"] = "ricezione da %s (finora %d |4voce:voci;)"
    L["sending to %d |4member:members;"] = "invio a %d |4membro:membri;"
    L["%d |4message:messages; queued (%d |4part:parts;)"] = "%d |4messaggio:messaggi; in coda (%d |4parte:parti;)"
    L["paused: addon messages are blocked here"] = "in pausa: qui i messaggi degli add-on sono bloccati"
    L["idle"] = "inattiva"

    -- Roster
    L["Professions"] = "Professioni"
    L["Shared by Guild Professions & Recipes. Point at an icon for the skill, click it for the recipes."] = "Condivise da Guild Professions & Recipes. Passa il cursore su un'icona per vedere la competenza e cliccala per vedere le ricette."
    L["This member does not share recipes (Guild Professions & Recipes is not installed)."] = "Questo membro non condivide ricette (Guild Professions & Recipes non è installato)."
    L["Skill %d/%d"] = "Competenza %d/%d"
    L["Click to see the recipes."] = "Clicca per vedere le ricette."
    L["Recipes not shared yet: this member has to open the profession once."] = "Ricette non ancora condivise: questo membro deve aprire la professione una volta."
    L["Updated %s ago"] = "Aggiornato %s fa"

    -- Profession window
    L["Recipe #%d"] = "Ricetta n. %d"
    L["Other"] = "Altro"
    L["and %d more"] = "e altri %d"
    L["Creates %d-%d"] = "Crea %d-%d"
    L["Creates %d"] = "Crea %d"
    L["Also known by: %s"] = "La conoscono anche: %s"
    L["Nobody else in the guild is known to have this recipe."] = "Non risulta che altri nella gilda abbiano questa ricetta."
    L["your own data"] = "i tuoi dati"
    L["from the member"] = "dal membro stesso"
    L["passed on by the guild"] = "trasmesso dalla gilda"
    L["%d of %d |4recipe:recipes;"] = "%d di %d |4ricetta:ricette;"
    L["View live"] = "Vedi dal vivo"
    L["Opens the game's own profession window for this member. Only while they are online."] = "Apre la finestra di professione del gioco per questo membro. Solo mentre è online."
    L["Select a recipe."] = "Seleziona una ricetta."
    L["Reagents:"] = "Reagenti:"
    L["The game gives no reagents for this recipe here; point at the icon for its details."] = "Il gioco qui non indica i reagenti di questa ricetta; passa il cursore sull'icona per i dettagli."
    L["no data on %s yet."] = "ancora nessun dato su %s."
    L["none of your recipes have been read yet: open each profession window once."] = "nessuna delle tue ricette è ancora stata letta: apri una volta ogni finestra di professione."
    L["%s has not shared any recipes yet."] = "%s non ha ancora condiviso nessuna ricetta."

    -- Probe
    L["Press Ctrl+A, then Ctrl+C, and paste the text to the addon's author."] = "Premi Ctrl+A, poi Ctrl+C, e invia il testo all'autore dell'add-on."
end)
