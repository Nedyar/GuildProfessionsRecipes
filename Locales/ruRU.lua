-- Русский. Counts take three forms: "|4one:few:many;".
local _, ns = ...

ns.RegisterLocale("ruRU", function(L)
    L["a moment"] = "мгновение"

    -- Chat
    L["/grecipes - your own professions"] = "/grecipes - ваши профессии"
    L["/grecipes <name> - the professions of a guild member"] = "/grecipes <имя> - профессии члена гильдии"
    L["/grecipes status - what the addon knows and is doing"] = "/grecipes status - что знает модификация и что она делает"
    L["/grecipes sync - ask the guild for missing data now"] = "/grecipes sync - запросить у гильдии недостающие данные сейчас"
    L["/grecipes probe - test report for the addon's author"] = "/grecipes probe - тестовый отчет для автора модификации"
    L["/grecipes language [code|auto] - language of the addon's texts"] = "/grecipes language [код|auto] - язык текстов модификации"
    L["/grecipes debug - show the sync log in the chat"] = "/grecipes debug - показывать журнал синхронизации в чате"
    L["/grecipes reset - forget the data of your current guild"] = "/grecipes reset - забыть данные текущей гильдии"
    L["version %s. Saved data loaded by the client: %s."] = "версия %s. Сохраненные данные загружены клиентом: %s."
    L["you are not in a guild (or the guild has not loaded yet)."] = "вы не состоите в гильдии (или гильдия еще не загрузилась)."
    L["guild %s: data on %d |4member:members;, %d of them with recipes."] = "гильдия %s: данные о %d |4участнике:участниках:участниках;, у %d из них есть рецепты."
    L["no recipes"] = "нет рецептов"
    L["recipes not read yet: open the profession once"] = "рецепты еще не прочитаны: откройте профессию один раз"
    L["%d |4recipe:recipes;"] = "%d |4рецепт:рецепта:рецептов;"
    L["sync: %s"] = "синхронизация: %s"
    L["sync log on."] = "журнал синхронизации включен."
    L["sync log off."] = "журнал синхронизации выключен."
    L["languages: %s, or auto for the client's."] = "языки: %s или auto для языка клиента."
    L["language set to %s. Type /reload to update every window."] = "выбран язык %s. Введите /reload, чтобы обновить все окна."
    L["this forgets what you know about your current guild. Type /grecipes reset confirm to do it."] = "это сотрет все, что известно о текущей гильдии. Введите /grecipes reset confirm, чтобы продолжить."
    L["data of your current guild forgotten."] = "данные текущей гильдии стерты."
    L["open these profession windows once so your recipes can be shared with the guild: %s."] = "откройте один раз эти окна профессий, чтобы ваши рецепты стали доступны гильдии: %s."
    L["running the probe; the report opens in a few seconds."] = "идет проверка; отчет откроется через несколько секунд."

    -- Sync
    L["a guild member uses a newer version of Guild Professions & Recipes that this one cannot talk to. Please update."] = "член гильдии использует более новую версию Guild Professions & Recipes, с которой эта версия не может обмениваться данными. Обновите модификацию."
    L["a newer version of Guild Professions & Recipes (%s) is in use in your guild."] = "в вашей гильдии используется более новая версия Guild Professions & Recipes (%s)."
    L["sync finished: %d |4record:records; received from %s."] = "синхронизация завершена: получено %d |4запись:записи:записей; от %s."
    L["a sync is already running."] = "синхронизация уже идет."
    L["nobody online has data you are missing."] = "ни у кого в сети нет данных, которых не хватает вам."
    L["asking the guild for missing data..."] = "запрос недостающих данных у гильдии..."
    L["waiting for offers"] = "ожидание предложений"
    L["receiving from %s (%d |4record:records; so far)"] = "получение от %s (пока %d |4запись:записи:записей;)"
    L["sending to %d |4member:members;"] = "отправка %d |4участнику:участникам:участникам;"
    L["%d |4message:messages; queued (%d |4part:parts;)"] = "%d |4сообщение:сообщения:сообщений; в очереди (%d |4часть:части:частей;)"
    L["paused: addon messages are blocked here"] = "пауза: здесь сообщения модификаций заблокированы"
    L["idle"] = "неактивна"

    -- Roster
    L["Professions"] = "Профессии"
    L["Shared by Guild Professions & Recipes. Point at an icon for the skill, click it for the recipes."] = "Данные Guild Professions & Recipes. Наведите курсор на значок, чтобы увидеть навык, и щелкните, чтобы увидеть рецепты."
    L["This member does not share recipes (Guild Professions & Recipes is not installed)."] = "Этот участник не делится рецептами (Guild Professions & Recipes не установлен)."
    L["Skill %d/%d"] = "Навык %d/%d"
    L["Click to see the recipes."] = "Щелкните, чтобы увидеть рецепты."
    L["Recipes not shared yet: this member has to open the profession once."] = "Рецепты еще не переданы: этот участник должен один раз открыть профессию."
    L["Updated %s ago"] = "Обновлено %s назад"

    -- Profession window
    L["Recipe #%d"] = "Рецепт №%d"
    L["Other"] = "Другое"
    L["and %d more"] = "и еще %d"
    L["Creates %d-%d"] = "Создает %d-%d"
    L["Creates %d"] = "Создает %d"
    L["Also known by: %s"] = "Также известен: %s"
    L["Nobody else in the guild is known to have this recipe."] = "Неизвестно, есть ли этот рецепт у кого-то еще в гильдии."
    L["your own data"] = "ваши собственные данные"
    L["from the member"] = "от самого участника"
    L["passed on by the guild"] = "передано гильдией"
    L["%d of %d |4recipe:recipes;"] = "%d из %d |4рецепта:рецептов:рецептов;"
    L["View live"] = "Смотреть вживую"
    L["Opens the game's own profession window for this member. Only while they are online."] = "Открывает окно профессии этого участника в самой игре. Только пока участник в сети."
    L["Select a recipe."] = "Выберите рецепт."
    L["Reagents:"] = "Реагенты:"
    L["The game gives no reagents for this recipe here; point at the icon for its details."] = "Игра здесь не сообщает реагенты этого рецепта; наведите курсор на значок, чтобы увидеть подробности."
    L["no data on %s yet."] = "пока нет данных: %s."
    L["none of your recipes have been read yet: open each profession window once."] = "ни один из ваших рецептов еще не прочитан: откройте один раз окно каждой профессии."
    L["%s has not shared any recipes yet."] = "%s пока не делится рецептами."

    -- Probe
    L["Press Ctrl+A, then Ctrl+C, and paste the text to the addon's author."] = "Нажмите Ctrl+A, затем Ctrl+C и отправьте текст автору модификации."
end)
