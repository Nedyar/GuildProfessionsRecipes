-- 简体中文.
local _, ns = ...

ns.RegisterLocale("zhCN", function(L)
    L["a moment"] = "片刻"

    -- Chat
    L["/grecipes - your own professions"] = "/grecipes - 你自己的专业"
    L["/grecipes <name> - the professions of a guild member"] = "/grecipes <名字> - 某位公会成员的专业"
    L["/grecipes status - what the addon knows and is doing"] = "/grecipes status - 插件掌握的数据和正在进行的操作"
    L["/grecipes sync - ask the guild for missing data now"] = "/grecipes sync - 立即向公会索取缺少的数据"
    L["/grecipes probe - test report for the addon's author"] = "/grecipes probe - 给插件作者的测试报告"
    L["/grecipes language [code|auto] - language of the addon's texts"] = "/grecipes language [代码|auto] - 插件文字的语言"
    L["/grecipes debug - show the sync log in the chat"] = "/grecipes debug - 在聊天框中显示同步日志"
    L["/grecipes reset - forget the data of your current guild"] = "/grecipes reset - 清除当前公会的数据"
    L["version %s. Saved data loaded by the client: %s."] = "版本 %s。客户端已加载保存的数据：%s。"
    L["you are not in a guild (or the guild has not loaded yet)."] = "你不在公会中（或公会尚未加载）。"
    L["guild %s: data on %d |4member:members;, %d of them with recipes."] = "公会 %s：%d 名成员的数据，其中 %d 名有配方。"
    L["no recipes"] = "没有配方"
    L["recipes not read yet: open the profession once"] = "尚未读取配方：请打开一次该专业"
    L["%d |4recipe:recipes;"] = "%d 个配方"
    L["sync: %s"] = "同步：%s"
    L["sync log on."] = "同步日志已开启。"
    L["sync log off."] = "同步日志已关闭。"
    L["languages: %s, or auto for the client's."] = "语言：%s，或用 auto 跟随客户端。"
    L["language set to %s. Type /reload to update every window."] = "语言已设为 %s。输入 /reload 以更新所有窗口。"
    L["this forgets what you know about your current guild. Type /grecipes reset confirm to do it."] = "这会清除你所掌握的当前公会的数据。输入 /grecipes reset confirm 以执行。"
    L["data of your current guild forgotten."] = "已清除当前公会的数据。"
    L["open these profession windows once so your recipes can be shared with the guild: %s."] = "请各打开一次这些专业窗口，以便与公会分享你的配方：%s。"
    L["running the probe; the report opens in a few seconds."] = "正在运行测试，报告将在几秒后打开。"

    -- Sync
    L["a guild member uses a newer version of Guild Professions & Recipes that this one cannot talk to. Please update."] = "有公会成员使用了更新版本的 Guild Professions & Recipes，当前版本无法与之通信。请更新插件。"
    L["a newer version of Guild Professions & Recipes (%s) is in use in your guild."] = "你的公会中有人在使用更新版本的 Guild Professions & Recipes（%s）。"
    L["sync finished: %d |4record:records; received from %s."] = "同步完成：收到 %d 条记录，来自 %s。"
    L["a sync is already running."] = "同步已在进行中。"
    L["nobody online has data you are missing."] = "在线的人中没有你缺少的数据。"
    L["asking the guild for missing data..."] = "正在向公会索取缺少的数据……"
    L["waiting for offers"] = "等待响应"
    L["receiving from %s (%d |4record:records; so far)"] = "正在接收 %s 的数据（目前 %d 条记录）"
    L["sending to %d |4member:members;"] = "正在发送给 %d 名成员"
    L["%d |4message:messages; queued (%d |4part:parts;)"] = "%d 条消息排队中（%d 段）"
    L["paused: addon messages are blocked here"] = "已暂停：此处禁止插件消息"
    L["idle"] = "空闲"

    -- Roster
    L["Professions"] = "专业"
    L["Shared by Guild Professions & Recipes. Point at an icon for the skill, click it for the recipes."] = "由 Guild Professions & Recipes 分享。鼠标指向图标查看技能等级，点击查看配方。"
    L["This member does not share recipes (Guild Professions & Recipes is not installed)."] = "该成员未分享配方（未安装 Guild Professions & Recipes）。"
    L["Skill %d/%d"] = "技能 %d/%d"
    L["Click to see the recipes."] = "点击查看配方。"
    L["Recipes not shared yet: this member has to open the profession once."] = "尚未分享配方：该成员需要打开一次该专业。"
    L["Updated %s ago"] = "%s前更新"

    -- Profession window
    L["Recipe #%d"] = "配方 #%d"
    L["Other"] = "其他"
    L["and %d more"] = "另有 %d 人"
    L["Creates %d-%d"] = "制造 %d-%d 个"
    L["Creates %d"] = "制造 %d 个"
    L["Also known by: %s"] = "其他会此配方的成员：%s"
    L["Nobody else in the guild is known to have this recipe."] = "公会中没有已知的其他人拥有此配方。"
    L["your own data"] = "你自己的数据"
    L["from the member"] = "来自该成员本人"
    L["passed on by the guild"] = "由公会转发"
    L["%d of %d |4recipe:recipes;"] = "%d/%d 个配方"
    L["View live"] = "实时查看"
    L["Opens the game's own profession window for this member. Only while they are online."] = "为该成员打开游戏自带的专业窗口。仅在其在线时可用。"
    L["Select a recipe."] = "请选择一个配方。"
    L["Reagents:"] = "材料："
    L["The game gives no reagents for this recipe here; point at the icon for its details."] = "游戏在此处未提供该配方的材料；鼠标指向图标查看详情。"
    L["no data on %s yet."] = "尚无 %s 的数据。"
    L["none of your recipes have been read yet: open each profession window once."] = "你的配方尚未被读取：请将每个专业窗口各打开一次。"
    L["%s has not shared any recipes yet."] = "%s 尚未分享任何配方。"

    -- Probe
    L["Press Ctrl+A, then Ctrl+C, and paste the text to the addon's author."] = "按 Ctrl+A，再按 Ctrl+C，然后把文本发给插件作者。"
end)
