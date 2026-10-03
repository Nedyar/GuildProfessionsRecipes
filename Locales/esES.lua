-- Español (EU). esMX starts from these texts too (see esMX.lua).
local _, ns = ...

ns.RegisterLocale("esES", function(L)
    L["a moment"] = "un momento"

    -- Chat
    L["/grecipes - your own professions"] = "/grecipes - tus propias profesiones"
    L["/grecipes <name> - the professions of a guild member"] = "/grecipes <nombre> - las profesiones de un miembro de la hermandad"
    L["/grecipes status - what the addon knows and is doing"] = "/grecipes status - qué sabe el addon y qué está haciendo"
    L["/grecipes sync - ask the guild for missing data now"] = "/grecipes sync - pedir ahora a la hermandad los datos que faltan"
    L["/grecipes probe - test report for the addon's author"] = "/grecipes probe - informe de pruebas para el autor del addon"
    L["/grecipes language [code|auto] - language of the addon's texts"] = "/grecipes language [código|auto] - idioma de los textos del addon"
    L["/grecipes debug - show the sync log in the chat"] = "/grecipes debug - mostrar el registro de sincronización en el chat"
    L["/grecipes reset - forget the data of your current guild"] = "/grecipes reset - olvidar los datos de tu hermandad actual"
    L["version %s. Saved data loaded by the client: %s."] = "versión %s. Datos guardados cargados por el cliente: %s."
    L["you are not in a guild (or the guild has not loaded yet)."] = "no estás en una hermandad (o la hermandad aún no se ha cargado)."
    L["guild %s: data on %d |4member:members;, %d of them with recipes."] = "hermandad %s: datos de %d |4miembro:miembros;, %d de ellos con recetas."
    L["no recipes"] = "sin recetas"
    L["recipes not read yet: open the profession once"] = "recetas aún sin leer: abre la profesión una vez"
    L["%d |4recipe:recipes;"] = "%d |4receta:recetas;"
    L["sync: %s"] = "sincronización: %s"
    L["sync log on."] = "registro de sincronización activado."
    L["sync log off."] = "registro de sincronización desactivado."
    L["languages: %s, or auto for the client's."] = "idiomas: %s, o auto para el del cliente."
    L["language set to %s. Type /reload to update every window."] = "idioma cambiado a %s. Escribe /reload para actualizar todas las ventanas."
    L["this forgets what you know about your current guild. Type /grecipes reset confirm to do it."] = "esto olvida lo que sabes de tu hermandad actual. Escribe /grecipes reset confirm para hacerlo."
    L["data of your current guild forgotten."] = "datos de tu hermandad actual olvidados."
    L["open these profession windows once so Guild Recipes can share your recipes with the guild: %s."] = "abre una vez estas ventanas de profesión para que Guild Recipes pueda compartir tus recetas con la hermandad: %s."
    L["running the probe; the report opens in a few seconds."] = "ejecutando las pruebas; el informe se abrirá en unos segundos."

    -- Sync
    L["a guild member uses a newer version of Guild Recipes that this one cannot talk to. Please update."] = "un miembro de la hermandad usa una versión más nueva de Guild Recipes con la que esta no puede comunicarse. Actualiza el addon."
    L["a newer version of Guild Recipes (%s) is in use in your guild."] = "en tu hermandad se usa una versión más nueva de Guild Recipes (%s)."
    L["sync finished: %d |4record:records; received from %s."] = "sincronización terminada: %d |4registro recibido:registros recibidos; de %s."
    L["a sync is already running."] = "ya hay una sincronización en curso."
    L["nobody online has data you are missing."] = "nadie conectado tiene datos que te falten."
    L["asking the guild for missing data..."] = "pidiendo a la hermandad los datos que faltan..."
    L["waiting for offers"] = "esperando ofertas"
    L["receiving from %s (%d |4record:records; so far)"] = "recibiendo de %s (%d |4registro:registros; hasta ahora)"
    L["sending to %d |4member:members;"] = "enviando a %d |4miembro:miembros;"
    L["%d |4message:messages; queued (%d |4part:parts;)"] = "%d |4mensaje:mensajes; en cola (%d |4parte:partes;)"
    L["paused: addon messages are blocked here"] = "en pausa: aquí los mensajes de addons están bloqueados"
    L["idle"] = "inactiva"

    -- Roster
    L["Professions"] = "Profesiones"
    L["Shared by Guild Recipes. Point at an icon for the skill, click it for the recipes."] = "Compartidas por Guild Recipes. Pasa el ratón por un icono para ver la habilidad y haz clic para ver las recetas."
    L["This member does not share recipes (Guild Recipes is not installed)."] = "Este miembro no comparte recetas (no tiene Guild Recipes instalado)."
    L["Skill %d/%d"] = "Habilidad %d/%d"
    L["Click to see the recipes."] = "Haz clic para ver las recetas."
    L["Recipes not shared yet: this member has to open the profession once."] = "Recetas aún sin compartir: este miembro tiene que abrir la profesión una vez."
    L["Updated %s ago"] = "Actualizado hace %s"

    -- Profession window
    L["Recipe #%d"] = "Receta n.º %d"
    L["Other"] = "Otros"
    L["and %d more"] = "y %d más"
    L["Creates %d-%d"] = "Crea %d-%d"
    L["Creates %d"] = "Crea %d"
    L["Also known by: %s"] = "También la conocen: %s"
    L["Nobody else in the guild is known to have this recipe."] = "No se sabe de nadie más en la hermandad que tenga esta receta."
    L["your own data"] = "tus propios datos"
    L["from the member"] = "del propio miembro"
    L["passed on by the guild"] = "transmitido por la hermandad"
    L["%d of %d |4recipe:recipes;"] = "%d de %d |4receta:recetas;"
    L["View live"] = "Ver en directo"
    L["Opens the game's own profession window for this member. Only while they are online."] = "Abre la ventana de profesión del propio juego para este miembro. Solo mientras esté conectado."
    L["Select a recipe."] = "Selecciona una receta."
    L["Reagents:"] = "Componentes:"
    L["The game gives no reagents for this recipe here; point at the icon for its details."] = "El juego no da aquí los componentes de esta receta; pasa el ratón por el icono para ver sus detalles."
    L["no data on %s yet."] = "aún no hay datos de %s."
    L["none of your recipes have been read yet: open each profession window once."] = "aún no se ha leído ninguna de tus recetas: abre una vez la ventana de cada profesión."
    L["%s has not shared any recipes yet."] = "%s aún no ha compartido ninguna receta."

    -- Probe
    L["Press Ctrl+A, then Ctrl+C, and paste the text to the addon's author."] = "Pulsa Ctrl+A, luego Ctrl+C, y pega el texto al autor del addon."
end)
