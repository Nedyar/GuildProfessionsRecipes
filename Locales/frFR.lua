-- Français.
local _, ns = ...

ns.RegisterLocale("frFR", function(L)
    L["a moment"] = "un instant"

    -- Chat
    L["/grecipes - your own professions"] = "/grecipes - vos propres métiers"
    L["/grecipes <name> - the professions of a guild member"] = "/grecipes <nom> - les métiers d'un membre de la guilde"
    L["/grecipes status - what the addon knows and is doing"] = "/grecipes status - ce que l'add-on sait et ce qu'il fait"
    L["/grecipes sync - ask the guild for missing data now"] = "/grecipes sync - demander maintenant à la guilde les données manquantes"
    L["/grecipes probe - test report for the addon's author"] = "/grecipes probe - rapport de test pour l'auteur de l'add-on"
    L["/grecipes language [code|auto] - language of the addon's texts"] = "/grecipes language [code|auto] - langue des textes de l'add-on"
    L["/grecipes debug - show the sync log in the chat"] = "/grecipes debug - afficher le journal de synchronisation dans la discussion"
    L["/grecipes reset - forget the data of your current guild"] = "/grecipes reset - oublier les données de votre guilde actuelle"
    L["version %s. Saved data loaded by the client: %s."] = "version %s. Données sauvegardées chargées par le client : %s."
    L["you are not in a guild (or the guild has not loaded yet)."] = "vous n'êtes pas dans une guilde (ou la guilde n'est pas encore chargée)."
    L["guild %s: data on %d |4member:members;, %d of them with recipes."] = "guilde %s : données sur %d |4membre:membres;, dont %d avec des recettes."
    L["no recipes"] = "aucune recette"
    L["recipes not read yet: open the profession once"] = "recettes pas encore lues : ouvrez le métier une fois"
    L["%d |4recipe:recipes;"] = "%d |4recette:recettes;"
    L["sync: %s"] = "synchronisation : %s"
    L["sync log on."] = "journal de synchronisation activé."
    L["sync log off."] = "journal de synchronisation désactivé."
    L["languages: %s, or auto for the client's."] = "langues : %s, ou auto pour celle du client."
    L["language set to %s. Type /reload to update every window."] = "langue définie sur %s. Tapez /reload pour mettre à jour toutes les fenêtres."
    L["this forgets what you know about your current guild. Type /grecipes reset confirm to do it."] = "ceci efface ce que vous savez de votre guilde actuelle. Tapez /grecipes reset confirm pour le faire."
    L["data of your current guild forgotten."] = "données de votre guilde actuelle effacées."
    L["open these profession windows once so Guild Recipes can share your recipes with the guild: %s."] = "ouvrez une fois ces fenêtres de métier pour que Guild Recipes puisse partager vos recettes avec la guilde : %s."
    L["running the probe; the report opens in a few seconds."] = "test en cours ; le rapport s'ouvre dans quelques secondes."

    -- Sync
    L["a guild member uses a newer version of Guild Recipes that this one cannot talk to. Please update."] = "un membre de la guilde utilise une version plus récente de Guild Recipes avec laquelle celle-ci ne peut pas communiquer. Veuillez mettre à jour l'add-on."
    L["a newer version of Guild Recipes (%s) is in use in your guild."] = "une version plus récente de Guild Recipes (%s) est utilisée dans votre guilde."
    L["sync finished: %d |4record:records; received from %s."] = "synchronisation terminée : %d |4fiche reçue:fiches reçues; de %s."
    L["a sync is already running."] = "une synchronisation est déjà en cours."
    L["nobody online has data you are missing."] = "personne en ligne n'a de données qui vous manquent."
    L["asking the guild for missing data..."] = "demande des données manquantes à la guilde..."
    L["waiting for offers"] = "en attente d'offres"
    L["receiving from %s (%d |4record:records; so far)"] = "réception depuis %s (%d |4fiche:fiches; jusqu'ici)"
    L["sending to %d |4member:members;"] = "envoi à %d |4membre:membres;"
    L["%d |4message:messages; queued (%d |4part:parts;)"] = "%d |4message:messages; en file d'attente (%d |4partie:parties;)"
    L["paused: addon messages are blocked here"] = "en pause : les messages d'add-on sont bloqués ici"
    L["idle"] = "inactive"

    -- Roster
    L["Professions"] = "Métiers"
    L["Shared by Guild Recipes. Point at an icon for the skill, click it for the recipes."] = "Partagés par Guild Recipes. Survolez une icône pour voir le niveau et cliquez dessus pour voir les recettes."
    L["This member does not share recipes (Guild Recipes is not installed)."] = "Ce membre ne partage pas de recettes (Guild Recipes n'est pas installé)."
    L["Skill %d/%d"] = "Compétence %d/%d"
    L["Click to see the recipes."] = "Cliquez pour voir les recettes."
    L["Recipes not shared yet: this member has to open the profession once."] = "Recettes pas encore partagées : ce membre doit ouvrir le métier une fois."
    L["Updated %s ago"] = "Mis à jour il y a %s"

    -- Profession window
    L["Recipe #%d"] = "Recette n° %d"
    L["Other"] = "Autre"
    L["and %d more"] = "et %d |4autre:autres;"
    L["Creates %d-%d"] = "Crée %d-%d"
    L["Creates %d"] = "Crée %d"
    L["Also known by: %s"] = "Également connue de : %s"
    L["Nobody else in the guild is known to have this recipe."] = "Personne d'autre dans la guilde n'est connu pour avoir cette recette."
    L["your own data"] = "vos propres données"
    L["from the member"] = "du membre lui-même"
    L["passed on by the guild"] = "transmis par la guilde"
    L["%d of %d |4recipe:recipes;"] = "%d sur %d |4recette:recettes;"
    L["View live"] = "Voir en direct"
    L["Opens the game's own profession window for this member. Only while they are online."] = "Ouvre la fenêtre de métier du jeu pour ce membre. Seulement tant qu'il est en ligne."
    L["Select a recipe."] = "Sélectionnez une recette."
    L["Reagents:"] = "Composants :"
    L["The game gives no reagents for this recipe here; point at the icon for its details."] = "Le jeu ne donne pas ici les composants de cette recette ; survolez l'icône pour ses détails."
    L["no data on %s yet."] = "pas encore de données sur %s."
    L["none of your recipes have been read yet: open each profession window once."] = "aucune de vos recettes n'a encore été lue : ouvrez une fois chaque fenêtre de métier."
    L["%s has not shared any recipes yet."] = "%s n'a encore partagé aucune recette."

    -- Probe
    L["Press Ctrl+A, then Ctrl+C, and paste the text to the addon's author."] = "Appuyez sur Ctrl+A, puis sur Ctrl+C, et envoyez le texte à l'auteur de l'add-on."
end)
