-- 繁體中文.
local _, ns = ...

ns.RegisterLocale("zhTW", function(L)
    L["a moment"] = "片刻"

    -- Chat
    L["/grecipes - your own professions"] = "/grecipes - 你自己的專業技能"
    L["/grecipes <name> - the professions of a guild member"] = "/grecipes <名字> - 某位公會成員的專業技能"
    L["/grecipes status - what the addon knows and is doing"] = "/grecipes status - 插件掌握的資料和正在進行的動作"
    L["/grecipes sync - ask the guild for missing data now"] = "/grecipes sync - 立即向公會索取缺少的資料"
    L["/grecipes probe - test report for the addon's author"] = "/grecipes probe - 給插件作者的測試報告"
    L["/grecipes language [code|auto] - language of the addon's texts"] = "/grecipes language [代碼|auto] - 插件文字的語言"
    L["/grecipes debug - show the sync log in the chat"] = "/grecipes debug - 在聊天視窗中顯示同步記錄"
    L["/grecipes reset - forget the data of your current guild"] = "/grecipes reset - 清除目前公會的資料"
    L["version %s. Saved data loaded by the client: %s."] = "版本 %s。用戶端已載入儲存的資料：%s。"
    L["you are not in a guild (or the guild has not loaded yet)."] = "你不在公會中（或公會尚未載入）。"
    L["guild %s: data on %d |4member:members;, %d of them with recipes."] = "公會 %s：%d 名成員的資料，其中 %d 名有配方。"
    L["no recipes"] = "沒有配方"
    L["recipes not read yet: open the profession once"] = "尚未讀取配方：請開啟一次該專業技能"
    L["%d |4recipe:recipes;"] = "%d 個配方"
    L["sync: %s"] = "同步：%s"
    L["sync log on."] = "同步記錄已開啟。"
    L["sync log off."] = "同步記錄已關閉。"
    L["languages: %s, or auto for the client's."] = "語言：%s，或用 auto 跟隨用戶端。"
    L["language set to %s. Type /reload to update every window."] = "語言已設為 %s。輸入 /reload 以更新所有視窗。"
    L["this forgets what you know about your current guild. Type /grecipes reset confirm to do it."] = "這會清除你所掌握的目前公會的資料。輸入 /grecipes reset confirm 以執行。"
    L["data of your current guild forgotten."] = "已清除目前公會的資料。"
    L["open these profession windows once so Guild Recipes can share your recipes with the guild: %s."] = "請各開啟一次這些專業技能視窗，讓 Guild Recipes 與公會分享你的配方：%s。"
    L["running the probe; the report opens in a few seconds."] = "正在執行測試，報告將在幾秒後開啟。"

    -- Sync
    L["a guild member uses a newer version of Guild Recipes that this one cannot talk to. Please update."] = "有公會成員使用較新版本的 Guild Recipes，目前版本無法與之通訊。請更新插件。"
    L["a newer version of Guild Recipes (%s) is in use in your guild."] = "你的公會中有人在使用較新版本的 Guild Recipes（%s）。"
    L["sync finished: %d |4record:records; received from %s."] = "同步完成：收到 %d 筆記錄，來自 %s。"
    L["a sync is already running."] = "同步已在進行中。"
    L["nobody online has data you are missing."] = "線上的人沒有你缺少的資料。"
    L["asking the guild for missing data..."] = "正在向公會索取缺少的資料……"
    L["waiting for offers"] = "等待回應"
    L["receiving from %s (%d |4record:records; so far)"] = "正在接收 %s 的資料（目前 %d 筆記錄）"
    L["sending to %d |4member:members;"] = "正在傳送給 %d 名成員"
    L["%d |4message:messages; queued (%d |4part:parts;)"] = "%d 則訊息排隊中（%d 段）"
    L["paused: addon messages are blocked here"] = "已暫停：此處禁止插件訊息"
    L["idle"] = "閒置"

    -- Roster
    L["Professions"] = "專業技能"
    L["Shared by Guild Recipes. Point at an icon for the skill, click it for the recipes."] = "由 Guild Recipes 分享。滑鼠指向圖示查看技能等級，點擊查看配方。"
    L["This member does not share recipes (Guild Recipes is not installed)."] = "該成員未分享配方（未安裝 Guild Recipes）。"
    L["Skill %d/%d"] = "技能 %d/%d"
    L["Click to see the recipes."] = "點擊查看配方。"
    L["Recipes not shared yet: this member has to open the profession once."] = "尚未分享配方：該成員需要開啟一次該專業技能。"
    L["Updated %s ago"] = "%s前更新"

    -- Profession window
    L["Recipe #%d"] = "配方 #%d"
    L["Other"] = "其他"
    L["and %d more"] = "另有 %d 人"
    L["Creates %d-%d"] = "製造 %d-%d 個"
    L["Creates %d"] = "製造 %d 個"
    L["Also known by: %s"] = "其他會此配方的成員：%s"
    L["Nobody else in the guild is known to have this recipe."] = "公會中沒有已知的其他人擁有此配方。"
    L["your own data"] = "你自己的資料"
    L["from the member"] = "來自該成員本人"
    L["passed on by the guild"] = "由公會轉傳"
    L["%d of %d |4recipe:recipes;"] = "%d/%d 個配方"
    L["View live"] = "即時檢視"
    L["Opens the game's own profession window for this member. Only while they are online."] = "為該成員開啟遊戲內建的專業技能視窗。僅在其在線上時可用。"
    L["Select a recipe."] = "請選擇一個配方。"
    L["Reagents:"] = "材料："
    L["The game gives no reagents for this recipe here; point at the icon for its details."] = "遊戲在此處未提供此配方的材料；滑鼠指向圖示查看詳細資訊。"
    L["no data on %s yet."] = "尚無 %s 的資料。"
    L["none of your recipes have been read yet: open each profession window once."] = "你的配方尚未被讀取：請將每個專業技能視窗各開啟一次。"
    L["%s has not shared any recipes yet."] = "%s 尚未分享任何配方。"

    -- Probe
    L["Press Ctrl+A, then Ctrl+C, and paste the text to the addon's author."] = "按 Ctrl+A，再按 Ctrl+C，然後把文字傳給插件作者。"
end)
