-- Português (Brasil). ptPT clients use these texts too (see Locales.lua).
local _, ns = ...

ns.RegisterLocale("ptBR", function(L)
    L["a moment"] = "um momento"

    -- Chat
    L["/grecipes - your own professions"] = "/grecipes - suas próprias profissões"
    L["/grecipes <name> - the professions of a guild member"] = "/grecipes <nome> - as profissões de um membro da guilda"
    L["/grecipes status - what the addon knows and is doing"] = "/grecipes status - o que o addon sabe e está fazendo"
    L["/grecipes sync - ask the guild for missing data now"] = "/grecipes sync - pedir agora à guilda os dados que faltam"
    L["/grecipes probe - test report for the addon's author"] = "/grecipes probe - relatório de teste para o autor do addon"
    L["/grecipes language [code|auto] - language of the addon's texts"] = "/grecipes language [código|auto] - idioma dos textos do addon"
    L["/grecipes debug - show the sync log in the chat"] = "/grecipes debug - mostrar o registro de sincronização no chat"
    L["/grecipes reset - forget the data of your current guild"] = "/grecipes reset - esquecer os dados da sua guilda atual"
    L["version %s. Saved data loaded by the client: %s."] = "versão %s. Dados salvos carregados pelo cliente: %s."
    L["you are not in a guild (or the guild has not loaded yet)."] = "você não está em uma guilda (ou a guilda ainda não foi carregada)."
    L["guild %s: data on %d |4member:members;, %d of them with recipes."] = "guilda %s: dados de %d |4membro:membros;, %d deles com receitas."
    L["no recipes"] = "sem receitas"
    L["recipes not read yet: open the profession once"] = "receitas ainda não lidas: abra a profissão uma vez"
    L["%d |4recipe:recipes;"] = "%d |4receita:receitas;"
    L["sync: %s"] = "sincronização: %s"
    L["sync log on."] = "registro de sincronização ativado."
    L["sync log off."] = "registro de sincronização desativado."
    L["languages: %s, or auto for the client's."] = "idiomas: %s, ou auto para o do cliente."
    L["language set to %s. Type /reload to update every window."] = "idioma definido como %s. Digite /reload para atualizar todas as janelas."
    L["this forgets what you know about your current guild. Type /grecipes reset confirm to do it."] = "isto apaga o que você sabe sobre sua guilda atual. Digite /grecipes reset confirm para fazê-lo."
    L["data of your current guild forgotten."] = "dados da sua guilda atual apagados."
    L["open these profession windows once so Guild Recipes can share your recipes with the guild: %s."] = "abra uma vez estas janelas de profissão para que o Guild Recipes possa compartilhar suas receitas com a guilda: %s."
    L["running the probe; the report opens in a few seconds."] = "executando o teste; o relatório abrirá em alguns segundos."

    -- Sync
    L["a guild member uses a newer version of Guild Recipes that this one cannot talk to. Please update."] = "um membro da guilda usa uma versão mais nova do Guild Recipes com a qual esta não consegue se comunicar. Atualize o addon."
    L["a newer version of Guild Recipes (%s) is in use in your guild."] = "uma versão mais nova do Guild Recipes (%s) está em uso na sua guilda."
    L["sync finished: %d |4record:records; received from %s."] = "sincronização concluída: %d |4registro recebido:registros recebidos; de %s."
    L["a sync is already running."] = "já há uma sincronização em andamento."
    L["nobody online has data you are missing."] = "ninguém conectado tem dados que faltam para você."
    L["asking the guild for missing data..."] = "pedindo à guilda os dados que faltam..."
    L["waiting for offers"] = "aguardando ofertas"
    L["receiving from %s (%d |4record:records; so far)"] = "recebendo de %s (%d |4registro:registros; até agora)"
    L["sending to %d |4member:members;"] = "enviando para %d |4membro:membros;"
    L["%d |4message:messages; queued (%d |4part:parts;)"] = "%d |4mensagem:mensagens; na fila (%d |4parte:partes;)"
    L["paused: addon messages are blocked here"] = "em pausa: as mensagens de addons estão bloqueadas aqui"
    L["idle"] = "ociosa"

    -- Roster
    L["Professions"] = "Profissões"
    L["Shared by Guild Recipes. Point at an icon for the skill, click it for the recipes."] = "Compartilhadas pelo Guild Recipes. Passe o mouse sobre um ícone para ver a perícia e clique nele para ver as receitas."
    L["This member does not share recipes (Guild Recipes is not installed)."] = "Este membro não compartilha receitas (o Guild Recipes não está instalado)."
    L["Skill %d/%d"] = "Perícia %d/%d"
    L["Click to see the recipes."] = "Clique para ver as receitas."
    L["Recipes not shared yet: this member has to open the profession once."] = "Receitas ainda não compartilhadas: este membro precisa abrir a profissão uma vez."
    L["Updated %s ago"] = "Atualizado há %s"

    -- Profession window
    L["Recipe #%d"] = "Receita nº %d"
    L["Other"] = "Outros"
    L["and %d more"] = "e mais %d"
    L["Creates %d-%d"] = "Cria %d-%d"
    L["Creates %d"] = "Cria %d"
    L["Also known by: %s"] = "Também a conhecem: %s"
    L["Nobody else in the guild is known to have this recipe."] = "Não se sabe de mais ninguém na guilda que tenha esta receita."
    L["your own data"] = "seus próprios dados"
    L["from the member"] = "do próprio membro"
    L["passed on by the guild"] = "repassado pela guilda"
    L["%d of %d |4recipe:recipes;"] = "%d de %d |4receita:receitas;"
    L["View live"] = "Ver ao vivo"
    L["Opens the game's own profession window for this member. Only while they are online."] = "Abre a janela de profissão do próprio jogo para este membro. Só enquanto estiver conectado."
    L["Select a recipe."] = "Selecione uma receita."
    L["Reagents:"] = "Reagentes:"
    L["The game gives no reagents for this recipe here; point at the icon for its details."] = "O jogo não informa aqui os reagentes desta receita; passe o mouse sobre o ícone para ver os detalhes."
    L["no data on %s yet."] = "ainda não há dados de %s."
    L["none of your recipes have been read yet: open each profession window once."] = "nenhuma das suas receitas foi lida ainda: abra uma vez a janela de cada profissão."
    L["%s has not shared any recipes yet."] = "%s ainda não compartilhou nenhuma receita."

    -- Probe
    L["Press Ctrl+A, then Ctrl+C, and paste the text to the addon's author."] = "Pressione Ctrl+A, depois Ctrl+C, e envie o texto ao autor do addon."
end)
