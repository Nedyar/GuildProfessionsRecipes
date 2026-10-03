-- 한국어.
local _, ns = ...

ns.RegisterLocale("koKR", function(L)
    L["a moment"] = "잠시"

    -- Chat
    L["/grecipes - your own professions"] = "/grecipes - 내 전문 기술"
    L["/grecipes <name> - the professions of a guild member"] = "/grecipes <이름> - 길드원의 전문 기술"
    L["/grecipes status - what the addon knows and is doing"] = "/grecipes status - 애드온이 알고 있는 정보와 하고 있는 일"
    L["/grecipes sync - ask the guild for missing data now"] = "/grecipes sync - 빠진 데이터를 지금 길드에 요청"
    L["/grecipes probe - test report for the addon's author"] = "/grecipes probe - 애드온 제작자를 위한 테스트 보고서"
    L["/grecipes language [code|auto] - language of the addon's texts"] = "/grecipes language [코드|auto] - 애드온 텍스트의 언어"
    L["/grecipes debug - show the sync log in the chat"] = "/grecipes debug - 동기화 기록을 대화창에 표시"
    L["/grecipes reset - forget the data of your current guild"] = "/grecipes reset - 현재 길드의 데이터 지우기"
    L["version %s. Saved data loaded by the client: %s."] = "버전 %s. 클라이언트가 불러온 저장 데이터: %s."
    L["you are not in a guild (or the guild has not loaded yet)."] = "길드에 속해 있지 않습니다 (또는 길드 정보를 아직 불러오지 않았습니다)."
    L["guild %s: data on %d |4member:members;, %d of them with recipes."] = "길드 %s: 길드원 %d명의 데이터, 그중 %d명은 제조법 있음."
    L["no recipes"] = "제조법 없음"
    L["recipes not read yet: open the profession once"] = "제조법을 아직 읽지 않음: 전문 기술 창을 한 번 여세요"
    L["%d |4recipe:recipes;"] = "제조법 %d개"
    L["sync: %s"] = "동기화: %s"
    L["sync log on."] = "동기화 기록 켜짐."
    L["sync log off."] = "동기화 기록 꺼짐."
    L["languages: %s, or auto for the client's."] = "언어: %s, 또는 클라이언트 언어를 쓰려면 auto."
    L["language set to %s. Type /reload to update every window."] = "언어를 %s(으)로 설정했습니다. 모든 창을 갱신하려면 /reload를 입력하세요."
    L["this forgets what you know about your current guild. Type /grecipes reset confirm to do it."] = "현재 길드에 대해 알고 있는 정보를 지웁니다. 진행하려면 /grecipes reset confirm을 입력하세요."
    L["data of your current guild forgotten."] = "현재 길드의 데이터를 지웠습니다."
    L["open these profession windows once so your recipes can be shared with the guild: %s."] = "제조법을 길드와 공유할 수 있도록 이 전문 기술 창들을 한 번씩 여세요: %s."
    L["running the probe; the report opens in a few seconds."] = "테스트 중입니다. 몇 초 후에 보고서가 열립니다."

    -- Sync
    L["a guild member uses a newer version of Guild Professions & Recipes that this one cannot talk to. Please update."] = "어떤 길드원이 이 버전과 통신할 수 없는 새 버전의 Guild Professions & Recipes를 사용하고 있습니다. 애드온을 업데이트하세요."
    L["a newer version of Guild Professions & Recipes (%s) is in use in your guild."] = "길드에서 새 버전의 Guild Professions & Recipes(%s)를 사용하고 있습니다."
    L["sync finished: %d |4record:records; received from %s."] = "동기화 완료: 기록 %d개 받음 (보낸 사람: %s)."
    L["a sync is already running."] = "이미 동기화가 진행 중입니다."
    L["nobody online has data you are missing."] = "접속 중인 길드원 중 빠진 데이터를 가진 사람이 없습니다."
    L["asking the guild for missing data..."] = "빠진 데이터를 길드에 요청하는 중..."
    L["waiting for offers"] = "응답 기다리는 중"
    L["receiving from %s (%d |4record:records; so far)"] = "%s에게서 받는 중 (지금까지 기록 %d개)"
    L["sending to %d |4member:members;"] = "길드원 %d명에게 보내는 중"
    L["%d |4message:messages; queued (%d |4part:parts;)"] = "대기 중인 메시지 %d개 (조각 %d개)"
    L["paused: addon messages are blocked here"] = "일시 중지: 여기서는 애드온 메시지가 차단됩니다"
    L["idle"] = "대기"

    -- Roster
    L["Professions"] = "전문 기술"
    L["Shared by Guild Professions & Recipes. Point at an icon for the skill, click it for the recipes."] = "Guild Professions & Recipes로 공유된 정보입니다. 아이콘에 마우스를 올리면 기술 수준이, 클릭하면 제조법이 표시됩니다."
    L["This member does not share recipes (Guild Professions & Recipes is not installed)."] = "이 길드원은 제조법을 공유하지 않습니다 (Guild Professions & Recipes가 설치되어 있지 않음)."
    L["Skill %d/%d"] = "기술 %d/%d"
    L["Click to see the recipes."] = "클릭하면 제조법을 봅니다."
    L["Recipes not shared yet: this member has to open the profession once."] = "아직 공유된 제조법 없음: 이 길드원이 전문 기술 창을 한 번 열어야 합니다."
    L["Updated %s ago"] = "%s 전에 업데이트됨"

    -- Profession window
    L["Recipe #%d"] = "제조법 #%d"
    L["Other"] = "기타"
    L["and %d more"] = "외 %d명"
    L["Creates %d-%d"] = "%d-%d개 생성"
    L["Creates %d"] = "%d개 생성"
    L["Also known by: %s"] = "이 제조법을 아는 다른 길드원: %s"
    L["Nobody else in the guild is known to have this recipe."] = "길드에서 이 제조법을 가진 다른 사람은 알려져 있지 않습니다."
    L["your own data"] = "내 데이터"
    L["from the member"] = "길드원 본인에게서"
    L["passed on by the guild"] = "길드를 통해 전달됨"
    L["%d of %d |4recipe:recipes;"] = "제조법 %d/%d개"
    L["View live"] = "실시간 보기"
    L["Opens the game's own profession window for this member. Only while they are online."] = "이 길드원의 게임 전문 기술 창을 엽니다. 접속 중일 때만 가능합니다."
    L["Select a recipe."] = "제조법을 선택하세요."
    L["Reagents:"] = "재료:"
    L["The game gives no reagents for this recipe here; point at the icon for its details."] = "게임이 여기서는 이 제조법의 재료를 알려주지 않습니다. 아이콘에 마우스를 올려 자세한 정보를 확인하세요."
    L["no data on %s yet."] = "%s에 대한 데이터가 아직 없습니다."
    L["none of your recipes have been read yet: open each profession window once."] = "아직 읽은 제조법이 없습니다: 각 전문 기술 창을 한 번씩 여세요."
    L["%s has not shared any recipes yet."] = "%s 님은 아직 제조법을 공유하지 않았습니다."

    -- Probe
    L["Press Ctrl+A, then Ctrl+C, and paste the text to the addon's author."] = "Ctrl+A, Ctrl+C를 차례로 누른 다음 애드온 제작자에게 텍스트를 붙여넣어 보내세요."
end)
