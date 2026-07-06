const $ = (sel, root = document) => root.querySelector(sel);
const $$ = (sel, root = document) => [...root.querySelectorAll(sel)];

const STORAGE_KEY = "tsd-codex-demo-state-v1";
const VAULT_SCHEMA_VERSION = "tsd-codex-vault-v1";
const PUBLIC_DEMO_URL = "https://raingodprc.github.io/TimeSlowDown-codex/";

const seedMoments = [
  {
    id: "m1",
    date: "今天",
    title: "跑完第一个 5 公里",
    text: "最后一公里很想停，但还是跑完了。不是人生从此改变，只是这件事我想记一下。",
    tags: ["第一次", "运动", "成就"],
    strength: "strong",
    sources: ["用户原话", "T1 忠实整理"]
  },
  {
    id: "m2",
    date: "昨天",
    title: "和爸爸吃了一碗面",
    text: "他说最近睡得还行。我发现他头发又白了一点。TSD 没有替我总结，只把这一幕留住。",
    tags: ["家人", "普通但值得", "晚饭"],
    strength: "memory",
    sources: ["用户确认切片"]
  },
  {
    id: "m3",
    date: "周三",
    title: "开会后那段沉默的路",
    text: "被怼之后，回家路上一直很烦，不想说话。晴天雨天都算人生旷野的一部分。",
    tags: ["低落", "工作", "允许不开心"],
    strength: "memory",
    sources: ["T1 语气门通过"]
  }
];

const defaultState = {
  onboarded: false,
  view: "now",
  activeTags: ["第一次"],
  draft: "今天带孩子去公园，他第一次自己爬上滑梯。我在下面有点紧张。",
  moments: seedMoments,
  aiMode: "rules",
  selectedGolden: "G001",
  weeklyClaimed: ["m1", "m2", "m3"],
  chapterTitle: "",
  chapterStory: "",
  shareMode: "private",
  meadowScale: "month",
  toast: "",
  age: 36,
  quietMode: false,
  deviceOnlyMode: true,
  lastExportAt: "",
  lastImportAt: "",
  vaultDeletedAt: "",
  monthName: "七月：压力、家人和一次完成",
  monthStarted: "开始把跑步当成一件属于自己的小事。",
  monthEnded: "不再把所有普通日子都当成空白。",
  monthChanged: "我开始承认：晴天雨天加在一起，才是完整。",
  quarterRecallDraft: "5 公里、和爸爸吃面、开会后那段沉默的回家路。",
  quarterRevealed: false
};

let state = loadState();

const evalCategories = [
  ["A", "普通日常", 10, "平淡日子能否具体化"],
  ["B", "高光瞬间", 8, "保留成就感但不过度升华"],
  ["C", "低落压力", 8, "不鸡汤、不强行正能量"],
  ["D", "家庭亲密", 8, "不乱猜关系和意义"],
  ["E", "模糊时间", 6, "年、月、人生阶段锚点"],
  ["F", "照片占位", 6, "不描述未解析照片内容"],
  ["G", "信息稀少", 5, "克制生成，转为轻追问"],
  ["H", "矛盾输入", 4, "标记冲突，请用户确认"],
  ["I", "周期编译", 3, "多切片总结与来源绑定"],
  ["J", "风格反馈", 2, "学习叙述偏好而非人格画像"]
];

const goldenSamples = [
  {
    id: "G001",
    title: "公园滑梯",
    input: "今天带孩子去公园，他第一次自己爬上滑梯。我在下面有点紧张。",
    must: ["公园", "孩子第一次自己爬上滑梯", "用户紧张"],
    forbid: ["学会放手", "孩子长大了", "人生转折"],
    output: "今天带孩子去公园，他第一次自己爬上滑梯。我在下面有点紧张。"
  },
  {
    id: "G002",
    title: "第一个 5 公里",
    input: "晚上跑了第一个5公里，最后一公里很想停，但还是跑完了。",
    must: ["第一个 5 公里", "最后一公里想停", "还是跑完了"],
    forbid: ["战胜自己", "人生从此不同", "长期坚持跑步"],
    output: "晚上跑完了第一个 5 公里。最后一公里很想停，但还是跑完了。"
  },
  {
    id: "G003",
    title: "工作压力",
    input: "今天开会被怼了，回家路上一直很烦，不想说话。",
    must: ["开会被怼", "回家路上烦", "不想说话"],
    forbid: ["成长机会", "明天会更好", "需要原谅别人"],
    output: "今天开会被怼了，回家路上一直很烦，不想说话。"
  },
  {
    id: "G004",
    title: "父亲吃饭",
    input: "晚上和爸爸吃了碗面，他说最近睡得还行。我发现他头发又白了一点。",
    must: ["和爸爸吃面", "最近睡得还行", "头发白了一点"],
    forbid: ["害怕失去父亲", "亲情的重量", "岁月无情"],
    output: "晚上和爸爸吃了碗面。他说最近睡得还行，我发现他头发又白了一点。"
  },
  {
    id: "G005",
    title: "20 岁学骑车",
    input: "我好像20岁那年才学会骑自行车，具体哪天忘了。",
    must: ["age_anchor=20", "模糊时间", "保留原句"],
    forbid: ["童年缺失", "迟来的自由", "比较别人"],
    output: "我好像 20 岁那年才学会骑自行车，具体哪天忘了。时间先保存为“20 岁那年”。"
  },
  {
    id: "G006",
    title: "照片占位",
    input: "上传了一张照片，备注：今天这杯咖啡很好喝。",
    must: ["只引用备注", "不看图时不描述画面"],
    forbid: ["拉花", "咖啡馆", "下午氛围"],
    output: "你上传了一张照片，并备注：今天这杯咖啡很好喝。"
  },
  {
    id: "G007",
    title: "只有还行",
    input: "今天还行。",
    must: ["朴素记录", "最多一个轻追问"],
    forbid: ["强行故事", "人生意义", "复杂总结"],
    output: "今天先记为：还行。要不要补一句，是哪件小事让它还行？"
  },
  {
    id: "G008",
    title: "时间冲突",
    input: "昨天晚上和朋友吃火锅，应该是今天中午吧，记不清了。",
    must: ["time_conflict=true", "请用户确认"],
    forbid: ["替用户确定时间", "删除冲突"],
    output: "这条记忆的时间有冲突：可能是昨天晚上，也可能是今天中午。先保存为待确认。"
  },
  {
    id: "G009",
    title: "周期编译",
    input: "周一加班买烤红薯；周三和妈妈通话；周六第一次跑完 5 公里。",
    must: ["每句绑定来源", "三件事都保留"],
    forbid: ["重新找回生活", "妈妈是最大支撑", "跑步治愈压力"],
    output: "这一周有三个被你认领的瞬间：加班后买了烤红薯；周三和妈妈通了电话；周六第一次跑完 5 公里。"
  },
  {
    id: "G010",
    title: "风格反馈",
    input: "用户把“这一刻像一束光照进生活”改成“这件事我想记一下”。",
    must: ["少用强比喻", "少用治愈系句子"],
    forbid: ["性格冷淡", "不重视情绪"],
    output: "叙述偏好已记录：更朴素，少用强比喻和治愈系句子。"
  }
];

function loadState() {
  try {
    return { ...defaultState, ...(JSON.parse(localStorage.getItem(STORAGE_KEY)) || {}) };
  } catch {
    return { ...defaultState };
  }
}

function saveState() {
  localStorage.setItem(STORAGE_KEY, JSON.stringify(state));
}

function setState(patch) {
  state = { ...state, ...patch };
  saveState();
  render();
}

function addMoment() {
  const text = state.draft.trim() || "今天有一个还没说清楚、但想先占位的瞬间。";
  const title = deriveTitle(text);
  const tags = state.activeTags.length ? state.activeTags : ["普通但值得"];
  const gates = analyzeMemory(text, tags);
  const moment = {
    id: `m${Date.now()}`,
    date: "今天",
    title,
    text: faithfulEdit(text, tags, gates),
    tags,
    strength: tags.includes("第一次") || tags.includes("成就") ? "strong" : "memory",
    gates,
    sources: ["用户原话", "L0 规则层", state.aiMode === "deepseek" ? "DeepSeek PoC 草稿" : "本地模板"]
  };
  setState({ moments: [moment, ...state.moments], view: "slice", draft: "" });
}

function vaultPayload() {
  return {
    schemaVersion: VAULT_SCHEMA_VERSION,
    app: "TimeSlowDown Codex",
    exportedAt: new Date().toISOString(),
    privacy: {
      storage: "browser-localStorage-demo",
      deviceOnlyMode: state.deviceOnlyMode,
      note: "Demo 版只导出当前浏览器里的本地数据；生产版需要 E2EE、账户同步和地区数据边界。"
    },
    data: {
      moments: state.moments,
      weeklyClaimed: state.weeklyClaimed,
      chapterTitle: state.chapterTitle,
      chapterStory: state.chapterStory,
      shareMode: state.shareMode,
      meadowScale: state.meadowScale,
      age: state.age,
      quietMode: state.quietMode,
      activeTags: state.activeTags,
      monthName: state.monthName,
      monthStarted: state.monthStarted,
      monthEnded: state.monthEnded,
      monthChanged: state.monthChanged,
      quarterRecallDraft: state.quarterRecallDraft,
      quarterRevealed: state.quarterRevealed
    }
  };
}

function vaultStats() {
  const payload = vaultPayload();
  const bytes = new Blob([JSON.stringify(payload)]).size;
  return {
    moments: state.moments.length,
    claimed: state.weeklyClaimed.filter(id => state.moments.some(moment => moment.id === id)).length,
    chapters: state.chapterTitle || state.chapterStory ? 1 : 0,
    bytes
  };
}

function exportVault() {
  const payload = vaultPayload();
  const text = JSON.stringify(payload, null, 2);
  const blob = new Blob([text], { type: "application/json" });
  const url = URL.createObjectURL(blob);
  const anchor = document.createElement("a");
  const stamp = new Date().toISOString().slice(0, 10);
  anchor.href = url;
  anchor.download = `timeslowdown-memory-vault-${stamp}.json`;
  document.body.appendChild(anchor);
  anchor.click();
  anchor.remove();
  URL.revokeObjectURL(url);
  setState({ lastExportAt: new Date().toLocaleString("zh-CN"), toast: "记忆保险箱 JSON 已导出到本机。" });
}

async function copyVault() {
  const text = JSON.stringify(vaultPayload(), null, 2);
  try {
    if (!navigator.clipboard) throw new Error("clipboard unavailable");
    await navigator.clipboard.writeText(text);
    setState({ lastExportAt: new Date().toLocaleString("zh-CN"), toast: "记忆保险箱 JSON 已复制。" });
  } catch {
    setState({ toast: "浏览器不允许自动复制；请使用“导出 JSON”保存到本机。" });
  }
}

function importDemoVault() {
  const imported = [
    {
      id: `import-${Date.now()}-1`,
      date: "20岁那年",
      title: "20 岁才学会骑自行车",
      text: "我记得自己 20 岁那年才学会骑自行车，具体哪天已经不重要了，但那种突然会了的感觉还在。",
      tags: ["人生补录", "第一次", "模糊时间"],
      strength: "memory",
      gates: { timeConflict: true, sparse: false, photoPlaceholder: false, sensitiveHint: false },
      sources: ["用户补录", "导入示例"]
    },
    {
      id: `import-${Date.now()}-2`,
      date: "上个月",
      title: "一次开心的额度刷新",
      text: "上个月遇到 GPT 额度刷新，那一刻很开心。它不宏大，但确实是那天的亮点。",
      tags: ["普通但值得", "开心", "月度补录"],
      strength: "memory",
      gates: { timeConflict: false, sparse: false, photoPlaceholder: false, sensitiveHint: false },
      sources: ["用户补录", "导入示例"]
    }
  ];
  setState({
    moments: [...imported, ...state.moments],
    lastImportAt: new Date().toLocaleString("zh-CN"),
    vaultDeletedAt: "",
    view: "settings",
    toast: "已导入 2 条跨时间粒度的示例回忆：年级别和月级别都可以被 TSD 接住。"
  });
}

function wipeLocalVault() {
  state = {
    ...defaultState,
    onboarded: true,
    view: "settings",
    moments: [],
    weeklyClaimed: [],
    chapterTitle: "",
    chapterStory: "",
    draft: "",
    vaultDeletedAt: new Date().toLocaleString("zh-CN"),
    toast: "本地记忆保险箱已清空。需要恢复 Demo 示例时，可点“重置 Demo”。"
  };
  saveState();
  render();
}

function getClaimedMoments() {
  const claimed = state.weeklyClaimed
    .map(id => state.moments.find(moment => moment.id === id))
    .filter(Boolean);
  return claimed.length ? claimed : state.moments.slice(0, 3);
}

function toggleClaim(id) {
  const current = state.weeklyClaimed.includes(id)
    ? state.weeklyClaimed.filter(item => item !== id)
    : [...state.weeklyClaimed, id];
  const trimmed = current.slice(Math.max(0, current.length - 3));
  setState({ weeklyClaimed: trimmed, toast: trimmed.length === 3 ? "已认领 3 个瞬间，可以编译本周章节。" : "" });
}

function compileChapter() {
  const claimed = getClaimedMoments().slice(0, 3);
  const title = deriveChapterTitle(claimed);
  const story = buildChapterStory(claimed);
  setState({
    chapterTitle: title,
    chapterStory: story,
    weeklyClaimed: claimed.map(moment => moment.id),
    toast: "本周章节草稿已生成。你可以直接改成自己的话。"
  });
}

function deriveChapterTitle(moments) {
  const titles = moments.map(moment => moment.title);
  if (moments.some(moment => moment.tags.includes("低落")) && moments.some(moment => moment.tags.includes("成就"))) return "这一周：有压力，也有完成";
  if (moments.some(moment => moment.tags.includes("家人")) && moments.some(moment => moment.tags.includes("第一次"))) return "这一周：家人、第一次和一点点变化";
  if (titles.length >= 2) return `这一周：${titles[0]}，和另外 ${titles.length - 1} 个瞬间`;
  return "这一周没有消失";
}

function buildChapterStory(moments) {
  if (!moments.length) return "这一周还没有被认领的瞬间。先留下一个很短的 Mark，也算开始。";
  const lines = moments.map((moment, index) => {
    const plain = moment.text.replace(/^这条记忆的时间有些不确定，TSD 先原样保存：/, "").replace(/^“|”$/g, "");
    return `${index + 1}. ${plain}（source: ${moment.id}）`;
  });
  return [
    `这一周，我认领了 ${moments.length} 个瞬间。`,
    ...lines,
    "TSD 没有替我总结人生，只把这些已经确认的线索放在一起。以后讲起这一周，我可以从这里开始。"
  ].join("\n");
}

function makeShareText() {
  const title = state.chapterTitle || deriveChapterTitle(getClaimedMoments());
  const story = state.chapterStory || buildChapterStory(getClaimedMoments());
  if (state.shareMode === "public") {
    return `${title}\n\n我用 TimeSlowDown 留下了这一周的几个瞬间。具体人名、地点和原文已隐藏，只分享这片小小的时间痕迹。`;
  }
  return `${title}\n\n${story}\n\n— 来自 TimeSlowDown`;
}

async function copyShareText() {
  const text = makeShareText();
  try {
    if (!navigator.clipboard) throw new Error("clipboard unavailable");
    await navigator.clipboard.writeText(text);
    setState({ toast: state.shareMode === "public" ? "已复制公开版分享文案。" : "已复制私密版章节文案。" });
  } catch {
    setState({ toast: "浏览器不允许自动复制；你仍可以手动选中文案。" });
  }
}

async function copyDemoLink() {
  try {
    if (!navigator.clipboard) throw new Error("clipboard unavailable");
    await navigator.clipboard.writeText(PUBLIC_DEMO_URL);
    setState({ toast: "公网试用链接已复制，可以发给朋友体验。" });
  } catch {
    setState({ toast: `浏览器不允许自动复制；请手动复制：${PUBLIC_DEMO_URL}` });
  }
}

async function copyPrivacySummary() {
  const text = [
    "TimeSlowDown Codex Demo 隐私摘要：",
    "1. 当前公网 Demo 不接入真实登录、云同步或真实 DeepSeek API。",
    "2. Demo 数据保存在当前浏览器 localStorage，可导出 JSON，也可清空。",
    "3. 生产版必须在账户同步、E2EE、模型处理、删除恢复窗口和地区数据边界完成后，才允许处理真实用户记忆。",
    "4. AI 只做忠实编辑，不替用户决定人生意义。"
  ].join("\n");
  try {
    if (!navigator.clipboard) throw new Error("clipboard unavailable");
    await navigator.clipboard.writeText(text);
    setState({ toast: "隐私摘要已复制，可发给试用者或审核者。" });
  } catch {
    setState({ toast: "浏览器不允许自动复制；请手动查看隐私摘要。" });
  }
}

function saveQuarterRecall() {
  setState({ toast: "已保存自由回忆。现在可以揭开季度风景，对照哪些是主动想起、哪些是被线索唤回。" });
}

function revealQuarter() {
  setState({ quarterRevealed: true, view: "ritual", toast: "季度风景已展开：先看主动想起，再看被线索唤回。" });
}

function resetQuarterRitual() {
  setState({ quarterRevealed: false, toast: "已收起季度风景。你可以重新先自由回忆。" });
}

function quarterMemoryCandidates() {
  const demoCandidates = [
    {
      id: "q-demo-1",
      date: "本季度",
      title: "孩子第一次自己爬上滑梯",
      text: "我在下面有点紧张，但他自己爬上去了。这是一张适合补录的亲子切片。",
      tags: ["第一次", "家人", "补录线索"],
      strength: "memory",
      sources: ["Demo 候选线索"]
    },
    {
      id: "q-demo-2",
      date: "上个月",
      title: "一次开心的额度刷新",
      text: "不是宏大的事，但那一刻确实开心。TSD 允许这种小小的高兴被留下。",
      tags: ["普通但值得", "月度补录"],
      strength: "memory",
      sources: ["Demo 候选线索"]
    },
    {
      id: "q-demo-3",
      date: "20岁那年",
      title: "20 岁才学会骑自行车",
      text: "具体哪天已经不重要，但它可以作为年粒度旧回忆被放进人生旷野。",
      tags: ["人生补录", "模糊时间"],
      strength: "memory",
      sources: ["Demo 候选线索"]
    }
  ];
  const seen = new Set();
  return [...state.moments, ...demoCandidates].filter(moment => {
    const key = moment.title;
    if (seen.has(key)) return false;
    seen.add(key);
    return true;
  }).slice(0, 8);
}

function recallHit(moment) {
  const recall = (state.quarterRecallDraft || "").replace(/\s/g, "");
  if (!recall) return false;
  const title = moment.title.replace(/\s/g, "");
  const text = moment.text.replace(/\s/g, "");
  const keywords = [
    title.slice(0, 2),
    title.slice(-2),
    ...moment.tags.map(tag => tag.replace(/\s/g, "").slice(0, 2))
  ].filter(token => token.length >= 2);
  return keywords.some(token => recall.includes(token)) || recall.includes(text.slice(0, 4));
}

function quarterStats() {
  const candidates = quarterMemoryCandidates();
  const recalled = candidates.filter(recallHit);
  return {
    candidates,
    recalled,
    assisted: candidates.filter(moment => !recallHit(moment))
  };
}

function deriveTitle(text) {
  if (text.includes("滑梯")) return "第一次自己爬上滑梯";
  if (text.includes("5公里") || text.includes("5 公里")) return "第一个 5 公里";
  if (text.includes("爸爸") || text.includes("妈妈")) return "和家人的一个短暂瞬间";
  if (text.length <= 10) return "一个先占位的今天";
  return text.replace(/[，。,.！!]/g, " ").trim().slice(0, 14);
}

function analyzeMemory(text, tags) {
  const compact = text.trim();
  return {
    timeConflict: /应该是|记不清|忘了|可能是|好像/.test(compact) && /昨天|今天|上周|上个月|那年|哪天/.test(compact),
    sparse: compact.length <= 8,
    photoPlaceholder: tags.includes("照片") || /上传.*照片|照片/.test(compact),
    sensitiveHint: /孩子|儿童|医院|病|位置|住址|亲密/.test(compact),
    forbids: ["新增无来源事实", "替用户总结人生意义", "强行正能量"]
  };
}

function faithfulEdit(text, tags, gates = analyzeMemory(text, tags)) {
  const safe = text.replace(/我突然意识到|人生从此|学会放手/g, "");
  if (gates.timeConflict) return `这条记忆的时间有些不确定，TSD 先原样保存：“${safe}”。周末回顾时再请你确认归属时间。`;
  if (gates.sparse) return `今天先留下一个很短的标记：“${safe}”。你可以周末再补一句为什么。`;
  if (gates.photoPlaceholder) return `你留下了一张照片，并写下：“${safe}”。TSD 不会描述没有被解析的照片内容。`;
  return safe.endsWith("。") ? safe : `${safe}。`;
}

function render() {
  const app = $("#app");
  app.innerHTML = state.onboarded ? mainTemplate() : onboardingTemplate();
  bindEvents();
  drawMeadow();
  drawLifeGrid();
}

function bindEvents() {
  $$("[data-view]").forEach(btn => btn.addEventListener("click", () => setState({ view: btn.dataset.view })));
  $("[data-onboard]")?.addEventListener("click", () => setState({ onboarded: true }));
  $("[data-reset]")?.addEventListener("click", () => {
    localStorage.removeItem(STORAGE_KEY);
    state = { ...defaultState };
    render();
  });
  $("[data-add]")?.addEventListener("click", addMoment);
  $("[data-compile-chapter]")?.addEventListener("click", compileChapter);
  $("[data-copy-share]")?.addEventListener("click", copyShareText);
  $("[data-copy-demo-link]")?.addEventListener("click", copyDemoLink);
  $("[data-copy-privacy]")?.addEventListener("click", copyPrivacySummary);
  $("[data-save-recall]")?.addEventListener("click", saveQuarterRecall);
  $("[data-reveal-quarter]")?.addEventListener("click", revealQuarter);
  $("[data-reset-ritual]")?.addEventListener("click", resetQuarterRitual);
  $("[data-export-vault]")?.addEventListener("click", exportVault);
  $("[data-copy-vault]")?.addEventListener("click", copyVault);
  $("[data-import-demo]")?.addEventListener("click", importDemoVault);
  $("[data-wipe-vault]")?.addEventListener("click", wipeLocalVault);
  $("[data-device-only]")?.addEventListener("click", () => setState({ deviceOnlyMode: !state.deviceOnlyMode, toast: state.deviceOnlyMode ? "已切换为可同步演示模式。" : "已切回仅设备优先模式。" }));
  $("[data-ai-mode]")?.addEventListener("click", () => setState({ aiMode: state.aiMode === "rules" ? "deepseek" : "rules" }));
  $("[data-quiet]")?.addEventListener("click", () => setState({ quietMode: !state.quietMode }));
  $$("[data-scale]").forEach(btn => btn.addEventListener("click", () => setState({ meadowScale: btn.dataset.scale })));
  $$("[data-claim]").forEach(btn => btn.addEventListener("click", () => toggleClaim(btn.dataset.claim)));
  $$("[data-share-mode]").forEach(btn => btn.addEventListener("click", () => setState({ shareMode: btn.dataset.shareMode })));
  $("[data-age]")?.addEventListener("input", (e) => setState({ age: Number(e.target.value || 36) }));
  const titleInput = $("[data-chapter-title]");
  titleInput?.addEventListener("input", e => {
    state.chapterTitle = e.target.value;
    saveState();
  });
  const storyInput = $("[data-chapter-story]");
  storyInput?.addEventListener("input", e => {
    state.chapterStory = e.target.value;
    saveState();
  });
  const input = $("[data-draft]");
  input?.addEventListener("input", e => {
    state.draft = e.target.value;
    saveState();
  });
  const quarterRecall = $("[data-quarter-recall]");
  quarterRecall?.addEventListener("input", e => {
    state.quarterRecallDraft = e.target.value;
    saveState();
  });
  const monthName = $("[data-month-name]");
  monthName?.addEventListener("input", e => {
    state.monthName = e.target.value;
    saveState();
  });
  const monthStarted = $("[data-month-started]");
  monthStarted?.addEventListener("input", e => {
    state.monthStarted = e.target.value;
    saveState();
  });
  const monthEnded = $("[data-month-ended]");
  monthEnded?.addEventListener("input", e => {
    state.monthEnded = e.target.value;
    saveState();
  });
  const monthChanged = $("[data-month-changed]");
  monthChanged?.addEventListener("input", e => {
    state.monthChanged = e.target.value;
    saveState();
  });
  $$("[data-tag]").forEach(tag => tag.addEventListener("click", () => {
    const value = tag.dataset.tag;
    const active = state.activeTags.includes(value);
    setState({ activeTags: active ? state.activeTags.filter(t => t !== value) : [...state.activeTags, value] });
  }));
  $$("[data-golden]").forEach(sample => sample.addEventListener("click", () => setState({ selectedGolden: sample.dataset.golden })));
  $$("[data-category-sample]").forEach(sample => sample.addEventListener("click", () => setState({ selectedGolden: sample.dataset.categorySample })));
}

function shell(content) {
  return `
  <div class="stage">
    <div class="phone">
      <div class="screen">
        <div class="statusbar"><span>9:41</span><span class="status-dots"><i class="dot"></i><i class="dot"></i><i class="dot"></i> 100%</span></div>
        <div class="screen-body">${content}</div>
        ${bottomNav()}
      </div>
    </div>
    ${sidePanel()}
  </div>`;
}

function mainTemplate() {
  const views = { now: nowView, slice: sliceView, meadow: meadowView, chapter: chapterView, ritual: ritualView, guide: guideView, ai: aiView, settings: settingsView };
  return shell((views[state.view] || nowView)());
}

function onboardingTemplate() {
  return shell(`
    <div class="onboarding">
      <div>
        <div class="eyebrow">Time Slow Down</div>
        <h1 class="onboard-title">不是活一辈子，<br/>而是活几个瞬间。</h1>
        <p class="onboard-copy">TSD 帮你把日复一日里真正不同的地方留下。今天先不用写日记，只要标记一个瞬间。</p>
      </div>
      <div class="onboard-art">
        <div class="meadow" style="position:absolute;left:16px;right:16px;bottom:16px"></div>
        <div class="floating-card">
          <div class="eyebrow">90 天后</div>
          <strong>你能讲出 5–10 个鲜明瞬间</strong>
          <p class="micro">不是靠连续打卡，而是靠被你认领过的切片。</p>
        </div>
      </div>
      <div>
        <button class="primary" data-onboard>留下今天的第一个瞬间</button>
        <button class="ghost" data-reset>重置 Demo</button>
      </div>
    </div>
  `);
}

function nowView() {
  return `
    <div class="topline">
      <div><div class="brand">此刻</div><div class="micro">今天不像昨天的地方，会在这里变成一张切片。</div></div>
      <div class="date-pill">7月5日 · 周日</div>
    </div>
    <section class="hero-card">
      <div class="eyebrow">Difference Radar</div>
      <h1 class="hero-title">今天有什么，<br/>不太一样？</h1>
      <p class="hero-subtitle">不需要完整日记。选一个线索，先把它钉在时间里。</p>
      <div class="action-row"><button class="primary" data-view="slice">开始 Quick Mark</button><button class="secondary" data-view="chapter">看本周章节</button></div>
    </section>
    <div class="radar">
      ${radarItem("第一次", "任何第一次都值得先占位，不必先判断它重不重要。", "✦")}
      ${radarItem("人", "今天有没有一个人，比平时更清晰？", "♙")}
      ${radarItem("情绪转弯", "从烦到松、从紧张到开心，都算。", "↺")}
    </div>
    <section class="journey-card">
      <div class="eyebrow">Try This Demo</div>
      <h2 class="section-title">推荐体验路线 <span class="micro">3 分钟</span></h2>
      <div class="journey-steps">
        ${journeyStep("01", "留下一张切片", "用 Quick Mark 写一句今天不同的地方。", "slice")}
        ${journeyStep("02", "编译本周章节", "认领 3 个瞬间，生成可编辑故事。", "chapter")}
        ${journeyStep("03", "缩放人生旷野", "从月度风景缩到一生周格。", "meadow")}
        ${journeyStep("04", "试一次 90 天回忆", "先自由回忆，再揭开季度风景。", "ritual")}
        ${journeyStep("05", "给朋友试用", "看 3 分钟导览、隐私和 PoC 边界。", "guide")}
      </div>
    </section>
  `;
}

function radarItem(title, copy, icon) {
  return `<div class="radar-item"><div class="radar-copy"><strong>${title}</strong><span>${copy}</span></div><div class="radar-icon">${icon}</div></div>`;
}

function journeyStep(num, title, copy, view) {
  return `<button class="journey-step" data-view="${view}">
    <span>${num}</span>
    <strong>${title}</strong>
    <em>${copy}</em>
  </button>`;
}

function sliceView() {
  const tags = ["第一次", "人", "地点", "情绪转弯", "成就", "照片", "普通但值得", "低落也算"];
  return `
    <div class="topline"><div><div class="brand">今日切片</div><div class="micro">5–15 秒先占位，周末再慢慢补全。</div></div></div>
    <section class="quick-panel">
      <h2 class="section-title">Quick Mark <span class="micro">${state.aiMode === "rules" ? "L0 规则层" : "DeepSeek PoC 草稿"}</span></h2>
      <textarea class="text-input" data-draft placeholder="写一句今天想留下的事">${escapeHtml(state.draft)}</textarea>
      <div class="quick-tags">
        ${tags.map(t => `<button class="tag ${state.activeTags.includes(t) ? "active" : ""}" data-tag="${t}">${t}</button>`).join("")}
      </div>
      <div class="action-row"><button class="primary" data-add>生成今日切片</button><button class="secondary" data-ai-mode>${state.aiMode === "rules" ? "切到 DeepSeek PoC" : "切回规则层"}</button></div>
      <p class="source-line">免费版永远可用：模型不可用时，TSD 会退回朴素模板，不让记录中断。</p>
    </section>
    ${latestSliceCard()}
  `;
}

function latestSliceCard() {
  const m = state.moments[0];
  if (!m) {
    return `<section class="slice-card empty-state">
      <div class="eyebrow">Latest Slice</div>
      <h2 class="slice-title">本地记忆保险箱是空的</h2>
      <p class="hero-subtitle">你可以写一句新的 Quick Mark，也可以在“我的”里导入示例备份。</p>
      <div class="action-row"><button class="primary" data-view="settings">去记忆保险箱</button></div>
    </section>`;
  }
  return `<section class="slice-card">
    <div class="eyebrow">Latest Slice</div>
    <h2 class="slice-title">${escapeHtml(m.title)}</h2>
    <p class="hero-subtitle">${escapeHtml(m.text)}</p>
    <div class="slice-meta">${m.tags.map(t => `<span class="meta">${escapeHtml(t)}</span>`).join("")}</div>
    ${gateBadges(m.gates)}
    <div class="source-line">来源：${m.sources.join(" · ")}。无来源的漂亮句子不会进入最终故事。</div>
  </section>`;
}

function gateBadges(gates) {
  if (!gates) return "";
  const badges = [
    gates.timeConflict && ["时间待确认", "warn"],
    gates.sparse && ["信息稀少", "soft"],
    gates.photoPlaceholder && ["不猜照片", "soft"],
    gates.sensitiveHint && ["敏感默认谨慎", "warn"]
  ].filter(Boolean);
  if (!badges.length) badges.push(["事实门通过", "ok"], ["语气门通过", "ok"]);
  return `<div class="gate-badges">${badges.map(([label, tone]) => `<span class="gate-badge ${tone}">${label}</span>`).join("")}</div>`;
}

function meadowView() {
  const scale = state.meadowScale || "month";
  return `
    <div class="topline"><div><div class="brand">人生旷野</div><div class="micro">有些日子长成花，有些日子只是草。都算人生。</div></div></div>
    <section class="hero-card">
      <div class="eyebrow">Semantic Zoom</div>
      <h1 class="hero-title">这不是相册，<br/>是一片会生长的草原。</h1>
      <p class="hero-subtitle">今天、月、年、十年以后，同一批记忆会在不同尺度下显影。</p>
    </section>
    <section class="zoom-card">
      <div class="scale-tabs">
        ${scaleButton("day", "日", "切片")}
        ${scaleButton("week", "周", "章节")}
        ${scaleButton("month", "月", "花丛")}
        ${scaleButton("year", "年", "图册")}
        ${scaleButton("life", "一生", "周格")}
      </div>
      ${semanticLens(scale)}
    </section>
    ${scale === "life" ? lifeScalePanel() : ""}
    ${scale === "year" ? yearAtlasPanel() : ""}
    ${scale === "month" ? monthLandscapePanel() : ""}
  `;
}

function scaleButton(id, label, sub) {
  return `<button class="scale-tab ${state.meadowScale === id ? "active" : ""}" data-scale="${id}"><strong>${label}</strong><span>${sub}</span></button>`;
}

function semanticLens(scale) {
  const claimed = getClaimedMoments().slice(0, 3);
  const chapterTitle = state.chapterTitle || deriveChapterTitle(claimed);
  const copy = {
    day: ["今日切片", state.moments[0]?.title || "今天还没有切片", "日尺度只回答：今天有什么不一样？"],
    week: ["本周章节", chapterTitle, "周尺度把 3 个被认领的瞬间放成一段可以讲的故事。"],
    month: ["月度风景", "七月：压力、家人和一次完成", "月尺度不数记录数量，而是看主题、人物和变化长成什么地貌。"],
    year: ["年度图册", "四季里有花，也有雨", "年尺度把每个月变成一页图册，让阶段变化看得见。"],
    life: ["一生周格", `${state.age} 岁 · 站在这一周`, "一生尺度用每周一个格子提醒时间珍贵，再放大当前阶段。"]
  }[scale];
  return `<div class="semantic-lens ${scale}">
    <div class="meadow" data-meadow><span class="hill"></span></div>
    <div class="lens-copy">
      <div class="eyebrow">${copy[0]}</div>
      <h2>${escapeHtml(copy[1])}</h2>
      <p>${escapeHtml(copy[2])}</p>
    </div>
  </div>`;
}

function monthLandscapePanel() {
  const themes = summarizeThemes();
  return `<section class="grid-card">
    <h2 class="section-title">月度风景 <span class="micro">花丛与主题</span></h2>
    <div class="month-map">
      ${themes.map((theme, index) => `<div class="theme-cluster cluster-${index}">
        <span class="cluster-flower"></span>
        <strong>${escapeHtml(theme.name)}</strong>
        <em>${theme.count} 个线索</em>
        <p>${escapeHtml(theme.copy)}</p>
      </div>`).join("")}
    </div>
    <div class="chapter-strip">
      ${["第 1 周", "第 2 周", "第 3 周", "第 4 周"].map((week, index) => `<button class="week-chip ${index === 0 ? "active" : ""}" data-view="chapter"><strong>${week}</strong><span>${index === 0 ? "已成章" : "待认领"}</span></button>`).join("")}
    </div>
    <div class="month-ritual-card">
      <strong>${escapeHtml(state.monthName)}</strong>
      <span>这个月开始了什么、结束了什么、悄悄改变了什么？</span>
      <button class="secondary" data-view="ritual">进入月度 / 季度仪式</button>
    </div>
    <p class="source-line">月度风景来自周章节和切片主题；平淡日子仍是草地，不因未记录而变成空白。</p>
  </section>`;
}

function summarizeThemes() {
  const allTags = state.moments.flatMap(moment => moment.tags);
  const count = tag => allTags.filter(item => item === tag).length || 1;
  return [
    { name: "家人与连接", count: count("家人") + count("人"), copy: "那些与人有关的短句，会在月尺度聚成一片花丛。" },
    { name: "完成与第一次", count: count("第一次") + count("成就"), copy: "不是宏大胜利，而是“我确实做到了”的小峰丘。" },
    { name: "雨天也算", count: count("低落") + count("允许不开心"), copy: "压力和沉默不被美化，也不被隐藏。它们是这片地貌的天气。" }
  ];
}

function yearAtlasPanel() {
  const months = ["一月", "二月", "三月", "四月", "五月", "六月", "七月", "八月", "九月", "十月", "十一月", "十二月"];
  return `<section class="grid-card">
    <h2 class="section-title">年度章节图册 <span class="micro">12 页风景</span></h2>
    <div class="atlas-grid">
      ${months.map((month, index) => `<button class="atlas-page ${index === 6 ? "current" : index < 6 ? "past" : ""}" data-scale="month">
        <span>${month}</span>
        <strong>${index === 6 ? "正在生长" : index < 6 ? "已有草纹" : "还在雾里"}</strong>
        <i style="--seed:${index + 1}"></i>
      </button>`).join("")}
    </div>
    <p class="source-line">年度不是一次性年终总结，而是 12 页逐月长出来的图册。</p>
  </section>`;
}

function lifeScalePanel() {
  return `<section class="grid-card life-panel">
    <h2 class="section-title">人生周格 <span class="micro">缩略全景 + 局部放大</span></h2>
    <input data-age type="range" min="18" max="90" value="${state.age}" />
    <p class="micro">当前年龄 ${state.age} 岁。全景负责提醒时间有限，局部放大负责告诉你：下一步可以从这一周开始。</p>
    <div class="life-grid mini" data-life-grid></div>
    <div class="focus-year">
      <div><strong>当前这一年</strong><span>52 周里的几个被记住瞬间</span></div>
      <div class="year-grid">${yearFocusCells()}</div>
    </div>
  </section>`;
}

function yearFocusCells() {
  return Array.from({ length: 52 }, (_, i) => {
    const cls = [4, 18, 31, 37].includes(i) ? "memory" : i === 27 ? "now" : "";
    return `<i class="week-cell ${cls}" title="week ${i + 1}"></i>`;
  }).join("");
}

function chapterView() {
  const claimed = getClaimedMoments().slice(0, 3);
  const title = state.chapterTitle || deriveChapterTitle(claimed);
  const story = state.chapterStory || buildChapterStory(claimed);
  const shareText = makeShareText();
  return `
    <div class="topline"><div><div class="brand">本周章节</div><div class="micro">先由你认领三个瞬间，TSD 再编译成可讲述故事。</div></div></div>
    <section class="chapter-card">
      <div class="eyebrow">Claim 3 Moments</div>
      <h2 class="slice-title">先认领，再编译</h2>
      <p class="hero-subtitle">AI 可以推荐候选，但这一周由你亲自认领。最多 3 个，少也可以。</p>
      <div class="claim-list">
        ${state.moments.slice(0, 6).map(moment => claimCard(moment)).join("")}
      </div>
      <div class="action-row"><button class="primary" data-compile-chapter>编译本周章节</button><button class="secondary" data-view="slice">再补一张切片</button></div>
      ${state.toast ? `<p class="toast">${state.toast}</p>` : ""}
    </section>
    <section class="chapter-card">
      <div class="eyebrow">Editable Chapter</div>
      <input class="chapter-title-input" data-chapter-title value="${escapeHtml(title)}" aria-label="本周章节标题" />
      <textarea class="story-input" data-chapter-story aria-label="本周章节正文">${escapeHtml(story)}</textarea>
      <div class="source-line">每个句子必须能追溯到 source；如果你改掉了来源，TSD 应该提醒你重新确认。</div>
    </section>
    <section class="chapter-card">
      <div class="eyebrow">Share Preview</div>
      <h2 class="section-title">隐私试衣间 <span class="micro">${state.shareMode === "public" ? "公开风景" : "讲给一个人"}</span></h2>
      <div class="share-mode">
        <button class="${state.shareMode === "private" ? "active" : ""}" data-share-mode="private">讲给一个人</button>
        <button class="${state.shareMode === "public" ? "active" : ""}" data-share-mode="public">分享一幅风景</button>
      </div>
      <div class="share-preview">${escapeHtml(shareText).replace(/\n/g, "<br/>")}</div>
      <div class="action-row"><button class="primary" data-copy-share>复制分享文案</button><button class="secondary" data-view="ai">检查 AI 四道门</button></div>
    </section>
    <section class="chapter-card ritual-teaser">
      <div class="eyebrow">90-Day Recall</div>
      <h2 class="slice-title">这三个月，不该像 90 个相同的一天。</h2>
      <p class="hero-subtitle">先不看答案，写下你脑中最先浮出来的几件事；再让 TSD 展开季度风景，区分“主动想起”和“被线索唤回”。</p>
      <div class="action-row"><button class="primary" data-view="ritual">开始季度回忆仪式</button><button class="secondary" data-scale="month" data-view="meadow">先看月度风景</button></div>
    </section>
  `;
}

function ritualView() {
  const { candidates, recalled, assisted } = quarterStats();
  const revealed = state.quarterRevealed;
  return `
    <div class="topline"><div><div class="brand">回忆仪式</div><div class="micro">先自由回忆，再看线索。TSD 不考你，只帮你看见时间去哪了。</div></div></div>
    <section class="hero-card">
      <div class="eyebrow">90-Day Ceremony</div>
      <h1 class="hero-title">过去三个月，<br/>有哪些瞬间还亮着？</h1>
      <p class="hero-subtitle">先写下你不看档案也能想到的事。揭开风景后，TSD 会把主动想起和线索唤回分开。</p>
    </section>
    <section class="ritual-card">
      <h2 class="section-title">月度命名 <span class="micro">3 个问题</span></h2>
      <input class="chapter-title-input" data-month-name value="${escapeHtml(state.monthName)}" aria-label="月度名字" />
      <div class="month-prompts">
        ${monthPrompt("开始", "data-month-started", state.monthStarted)}
        ${monthPrompt("结束", "data-month-ended", state.monthEnded)}
        ${monthPrompt("改变", "data-month-changed", state.monthChanged)}
      </div>
      <p class="source-line">月度仪式只问开始、结束、改变，不要求写完整月记；跳过也不会产生欠债。</p>
    </section>
    <section class="ritual-card">
      <div class="eyebrow">Step 1 · Free Recall</div>
      <h2 class="slice-title">60 秒自由回忆</h2>
      <textarea class="story-input recall-input" data-quarter-recall aria-label="季度自由回忆">${escapeHtml(state.quarterRecallDraft)}</textarea>
      <div class="action-row">
        <button class="secondary" data-save-recall>保存自由回忆</button>
        <button class="primary" data-reveal-quarter>揭开季度风景</button>
        ${revealed ? `<button class="ghost" data-reset-ritual>重新遮住</button>` : ""}
      </div>
      ${state.toast ? `<p class="toast">${state.toast}</p>` : ""}
    </section>
    ${revealed ? quarterLandscape(candidates, recalled, assisted) : quarterLocked()}
  `;
}

function guideView() {
  return `
    <div class="topline"><div><div class="brand">试用指南</div><div class="micro">给第一次打开 TSD 的人：怎么试、试什么、哪些还只是 PoC。</div></div></div>
    <section class="hero-card">
      <div class="eyebrow">Public Trial</div>
      <h1 class="hero-title">3 分钟，<br/>看懂 TSD 在帮你留住什么。</h1>
      <p class="hero-subtitle">这不是日记 App，也不是相册。你可以从一张切片开始，看它如何长成周章节、人生旷野和 90 天回忆。</p>
      <div class="action-row"><button class="primary" data-copy-demo-link>复制公网试用链接</button><button class="secondary" data-view="slice">从 Quick Mark 开始</button></div>
      ${state.toast ? `<p class="toast">${state.toast}</p>` : ""}
    </section>
    <section class="guide-card">
      <h2 class="section-title">推荐试用路线 <span class="micro">第一次打开</span></h2>
      <div class="trial-route">
        ${trialStep("01", "留下一张切片", "写一句今天不同的地方。", "slice")}
        ${trialStep("02", "编译一篇周章节", "认领 3 个瞬间，看它变成可编辑故事。", "chapter")}
        ${trialStep("03", "缩放人生旷野", "从月度花丛看到一生周格。", "meadow")}
        ${trialStep("04", "做 90 天回忆", "先自由回忆，再揭开季度风景。", "ritual")}
        ${trialStep("05", "检查记忆保险箱", "导出、导入、清空，确认记忆能带走。", "settings")}
      </div>
    </section>
    <section class="guide-card">
      <h2 class="section-title">当前能力边界 <span class="micro">说清楚才可信</span></h2>
      <div class="boundary-grid">
        ${boundaryColumn("已可试用", [
          "Quick Mark 与今日切片",
          "可编辑周章节与隐私分享预览",
          "人生旷野五档语义缩放",
          "记忆保险箱导出/导入/清空",
          "90 天回忆仪式"
        ], "ok")}
        ${boundaryColumn("PoC 模拟", [
          "AI 分层与 DeepSeek 模式为演示开关",
          "规则门禁用于模拟忠实编辑",
          "季度风景使用本地样例与当前切片",
          "分享仅生成文案，不发布到社交平台"
        ], "soft")}
        ${boundaryColumn("生产待做", [
          "账户、同步、E2EE 与恢复窗口",
          "真实模型网关与成本/额度策略",
          "App Store 隐私营养标签",
          "PWA manifest / iOS 原生壳与图标资产"
        ], "warn")}
      </div>
    </section>
    <section class="guide-card">
      <h2 class="section-title">隐私与 AI 说明 <span class="micro">外部试用版</span></h2>
      <div class="chapter-list">
        <div class="chapter-line"><strong>Demo 默认只用浏览器本地数据</strong><span>当前公网版本没有接入真实登录、云同步或真实 DeepSeek API；你在本机浏览器里的 Demo 数据可导出、可清空。</span></div>
        <div class="chapter-line"><strong>AI 是忠实编辑，不是人生意义作者</strong><span>漂亮但没有来源的句子不得进入最终故事；低落、压力和普通日子也允许被记录。</span></div>
        <div class="chapter-line"><strong>生产版会先解决数据边界</strong><span>真实用户记忆进入云端前，需要 E2EE、地区数据边界、删除/导出权和清晰的模型处理条款。</span></div>
      </div>
      <div class="action-row"><button class="secondary" data-copy-privacy>复制隐私摘要</button><button class="secondary" data-view="ai">查看 AI 边界</button></div>
    </section>
    <section class="guide-card">
      <h2 class="section-title">真实产品边界图 <span class="micro">v9</span></h2>
      <div class="production-map">
        ${productionNode("设备本地", "Quick Mark、敏感标记、仅设备记忆先留在本机。", "ready")}
        ${productionNode("L0 规则层", "事实门、语气门、照片门先在本地兜底。", "ready")}
        ${productionNode("云模型", "DeepSeek V4 Flash 只应处理用户允许的摘要或非敏感草稿。", "poc")}
        ${productionNode("加密同步", "生产版需账户、E2EE、恢复窗口和地区数据边界。", "todo")}
        ${productionNode("用户权利", "导出、删除、撤销 AI 草稿、查看来源必须是一级能力。", "ready")}
      </div>
      <p class="source-line">v9 仍不调用真实模型；它把未来生产路径写清楚，避免试用者误以为 Demo 已经上传或处理真实记忆。</p>
    </section>
    <section class="guide-card">
      <h2 class="section-title">App Store 方向清单</h2>
      <div class="readiness-list">
        ${readiness("产品灵魂", "完成", "时间切片机、人生旷野、90 天可讲述。")}
        ${readiness("数据权利", "Demo 覆盖", "导出、导入、清空已可点击；生产需账户与恢复。")}
        ${readiness("AI 边界", "PoC 覆盖", "分层架构和黄金样本已可看；生产需真实网关。")}
        ${readiness("安装体验", "待做", "受不新建文件约束，本轮未添加 manifest/icon。")}
        ${readiness("合规文本", "雏形", "隐私/AI/同步边界已写入 App 内。")}
      </div>
    </section>
  `;
}

function trialStep(num, title, copy, view) {
  return `<button class="trial-step" data-view="${view}"><span>${num}</span><strong>${title}</strong><em>${copy}</em></button>`;
}

function boundaryColumn(title, items, tone) {
  return `<div class="boundary-column ${tone}"><strong>${title}</strong>${items.map(item => `<span>${escapeHtml(item)}</span>`).join("")}</div>`;
}

function readiness(label, stateLabel, copy) {
  return `<div class="readiness-item"><span>${label}</span><strong>${stateLabel}</strong><em>${copy}</em></div>`;
}

function productionNode(title, copy, tone) {
  return `<div class="production-node ${tone}"><strong>${title}</strong><span>${copy}</span></div>`;
}

function monthPrompt(label, attr, value) {
  return `<label class="month-prompt"><span>${label}</span><textarea ${attr} rows="2">${escapeHtml(value)}</textarea></label>`;
}

function quarterLocked() {
  return `<section class="ritual-card locked-landscape">
    <div class="eyebrow">Step 2 · Hidden Landscape</div>
    <h2 class="slice-title">先别急着看答案。</h2>
    <p class="hero-subtitle">真正有价值的是：哪些事你不用提醒也能讲出来？哪些事看到线索后才重新回来？</p>
    <div class="quarter-week-grid">${quarterWeekCells(false)}</div>
  </section>`;
}

function quarterLandscape(candidates, recalled, assisted) {
  return `<section class="ritual-card">
    <div class="eyebrow">Step 2 · Quarter Landscape</div>
    <h2 class="section-title">季度风景 <span class="micro">${recalled.length} 个主动想起 · ${assisted.length} 个线索唤回</span></h2>
    <div class="quarter-stats">
      ${vaultStat("周格", 13, "周")}
      ${vaultStat("月景", 3, "幅")}
      ${vaultStat("主动", recalled.length, "个")}
      ${vaultStat("可讲", candidates.length, "个")}
    </div>
    <div class="quarter-week-grid">${quarterWeekCells(true)}</div>
    <div class="quarter-months">
      ${quarterMonth("第一个月", "草地开始有纹路", "普通日子被保留下来，不再完全蒸发。")}
      ${quarterMonth("第二个月", state.monthName, state.monthChanged)}
      ${quarterMonth("第三个月", "下一片风景正在长", "今天的 Quick Mark 会成为下个季度的线索。")}
    </div>
    <h2 class="section-title">可讲述瞬间 <span class="micro">5–10 个目标</span></h2>
    <div class="tellable-list">
      ${candidates.map(moment => tellableMoment(moment, recallHit(moment))).join("")}
    </div>
    <p class="source-line">这里不是记忆力分数。主动想起说明它已经在你心里变厚；线索唤回说明这段时间没有白过，只是需要一个入口。</p>
  </section>`;
}

function quarterWeekCells(revealed) {
  return Array.from({ length: 13 }, (_, index) => {
    const cls = revealed && [1, 4, 7, 10, 12].includes(index) ? "memory" : revealed && index === 8 ? "strong" : "";
    return `<i class="quarter-week ${cls}"><span>W${index + 1}</span></i>`;
  }).join("");
}

function quarterMonth(label, title, copy) {
  return `<div class="quarter-month-card"><span>${label}</span><strong>${escapeHtml(title)}</strong><em>${escapeHtml(copy)}</em></div>`;
}

function tellableMoment(moment, recalled) {
  const who = moment.tags.includes("家人") ? "家人" : moment.tags.includes("工作") ? "工作里的自己" : moment.tags.includes("第一次") ? "第一次尝试的自己" : "当时的我";
  const why = moment.tags.includes("低落") || moment.tags.includes("允许不开心")
    ? "它让雨天也被看见"
    : moment.tags.includes("成就") || moment.tags.includes("第一次")
      ? "它留下了一个完成感"
      : "它让普通日子有了一个锚点";
  return `<article class="tellable-card ${recalled ? "recalled" : ""}">
    <div><span class="gate-badge ${recalled ? "ok" : "soft"}">${recalled ? "主动想起" : "线索唤回"}</span><span class="source-chip">${escapeHtml(moment.date)}</span></div>
    <h3>${escapeHtml(moment.title)}</h3>
    <p>${escapeHtml(moment.text)}</p>
    <dl>
      <div><dt>发生了什么</dt><dd>${escapeHtml(moment.title)}</dd></div>
      <div><dt>和谁有关</dt><dd>${escapeHtml(who)}</dd></div>
      <div><dt>为什么重要</dt><dd>${escapeHtml(why)}</dd></div>
    </dl>
  </article>`;
}

function claimCard(moment) {
  const active = state.weeklyClaimed.includes(moment.id);
  return `<button class="claim-card ${active ? "active" : ""}" data-claim="${escapeHtml(moment.id)}">
    <span class="claim-check">${active ? "✓" : "+"}</span>
    <span><strong>${escapeHtml(moment.title)}</strong><em>${escapeHtml(moment.text)}</em><small>${escapeHtml(moment.tags.join(" · "))} · source: ${escapeHtml(moment.id)}</small></span>
  </button>`;
}

function aiView() {
  const selected = goldenSamples.find(sample => sample.id === state.selectedGolden) || goldenSamples[0];
  return `
    <div class="topline"><div><div class="brand">AI 忠实编辑器</div><div class="micro">不是代写日记，是把线索整理成可认领草稿。</div></div></div>
    <section class="ai-card">
      <h2 class="section-title">移动端 AI 分层 <span class="micro">v1</span></h2>
      <div class="ai-eval">
        ${evalRow("L0 规则层", "免费用户底座，永远可用", 100)}
        ${evalRow("L1 免费云额度", "只做非敏感轻任务，可降级", 58)}
        ${evalRow("L2 DeepSeek V4 Flash", "PoC / Plus 主力", 82)}
        ${evalRow("L3 BYOK", "高级用户自带 Key", 48)}
        ${evalRow("L4 未来本地 AI", "高端设备增强，不是 v1 前提", 22)}
      </div>
    </section>
    <section class="ai-card">
      <h2 class="section-title">60 条 PoC 样本分类</h2>
      <div class="eval-matrix">
        ${evalCategories.map(([code, title, count, focus]) => `<button class="eval-category" data-category-sample="${goldenSamples[Math.min(goldenSamples.length - 1, Math.max(0, code.charCodeAt(0) - 65))].id}"><strong>${code}</strong><span>${title}</span><em>${count} 条</em><small>${focus}</small></button>`).join("")}
      </div>
    </section>
    <section class="ai-card">
      <h2 class="section-title">10 条黄金样本 <span class="micro">可点击检查</span></h2>
      <div class="golden-tabs">
        ${goldenSamples.map(sample => `<button class="golden-tab ${sample.id === selected.id ? "active" : ""}" data-golden="${sample.id}">${sample.id}</button>`).join("")}
      </div>
      <div class="golden-card">
        <div class="eyebrow">${selected.id} · ${selected.title}</div>
        <p class="golden-input">${selected.input}</p>
        <div class="gate-grid">
          <div><strong>必须保留</strong>${selected.must.map(item => `<span>${item}</span>`).join("")}</div>
          <div><strong>禁止生成</strong>${selected.forbid.map(item => `<span>${item}</span>`).join("")}</div>
        </div>
        <div class="faithful-output"><strong>L0/L2 期望草稿</strong><p>${selected.output}</p></div>
      </div>
    </section>
    <section class="ai-card">
      <h2 class="section-title">Faithful Memory Editing Eval</h2>
      ${evalRow("事实忠实", "≥ 4.6 / 5", 92)}
      ${evalRow("无来源句子", "进入最终故事 = 0", 100)}
      ${evalRow("过度煽情率", "< 10%", 84)}
      ${evalRow("JSON Schema", "≥ 98%", 98)}
      <p class="source-line">所有黄金样本都遵守事实门、语气门、隐私门和认领门；漂亮但无来源的句子默认视为风险。</p>
    </section>
    <section class="ai-card">
      <h2 class="section-title">模型路由与降级 <span class="micro">v9 生产边界</span></h2>
      <div class="route-stack">
        ${routeStep("L0", "本地规则", "免费底座；时间冲突、信息稀少、照片占位、敏感提示先在本地处理。", "已在 Demo 中模拟")}
        ${routeStep("L1", "免费云额度", "只处理非敏感轻任务；失败时静默退回 L0，不让记录中断。", "生产待接入")}
        ${routeStep("L2", "DeepSeek V4 Flash", "Plus/PoC 主力；只可处理用户授权的草稿或摘要，不默认上传原始记忆。", "当前为演示开关")}
        ${routeStep("L3", "BYOK", "高级用户自带模型 Key，自担成本，适合长章节和年度图册。", "生产待接入")}
        ${routeStep("L4", "未来本地 AI", "高端设备增强；不是 v1 上线前提，也不能承诺所有手机可跑。", "方向保留")}
      </div>
      <div class="rights-strip">
        <span>无模型也能记录</span>
        <span>失败自动降级</span>
        <span>无来源不成章</span>
        <span>敏感默认谨慎</span>
      </div>
      <p class="source-line">v9 不伪装真实 API 调用。DeepSeek V4 Flash 仍是首发 PoC 目标，但当前公网 Demo 只展示路由、门禁和降级策略。</p>
    </section>
  `;
}

function evalRow(title, copy, value) {
  return `<div class="eval-row"><div><strong>${title}</strong><div class="micro">${copy}</div><div class="meter"><i style="width:${value}%"></i></div></div><div class="score">${value}%</div></div>`;
}

function routeStep(level, title, copy, status) {
  return `<div class="route-step"><span>${level}</span><strong>${title}</strong><em>${copy}</em><small>${status}</small></div>`;
}

function settingsView() {
  const stats = vaultStats();
  return `
    <div class="topline"><div><div class="brand">设置</div><div class="micro">隐私、付费和叙述偏好，都应该说人话。</div></div></div>
    <section class="settings-card">
      <h2 class="section-title">外部试用 <span class="micro">v8 · 公网导览</span></h2>
      <div class="chapter-list">
        <div class="chapter-line"><strong>公网地址</strong><span>${PUBLIC_DEMO_URL}</span></div>
        <div class="chapter-line"><strong>给新用户的说明</strong><span>如果你要推荐给朋友，建议让 TA 先走“试用指南”，再做 Quick Mark。</span></div>
      </div>
      <div class="action-row"><button class="primary" data-view="guide">打开试用指南</button><button class="secondary" data-copy-demo-link>复制链接</button></div>
      ${state.toast ? `<p class="toast">${state.toast}</p>` : ""}
    </section>
    <section class="settings-card">
      <h2 class="section-title">记忆保险箱 <span class="micro">v8 · 本地优先</span></h2>
      <div class="vault-grid">
        ${vaultStat("切片", stats.moments, "条")}
        ${vaultStat("认领", stats.claimed, "个")}
        ${vaultStat("章节", stats.chapters, "篇")}
        ${vaultStat("大小", Math.max(1, Math.ceil(stats.bytes / 1024)), "KB")}
      </div>
      <div class="chapter-list">
        <div class="chapter-line"><strong>导出我的记忆</strong><span>把当前浏览器里的切片、章节、偏好导出为 JSON。Demo 不上传你的原文。</span></div>
        <div class="chapter-line"><strong>导入旧回忆</strong><span>支持“20 岁那年”“上个月”这类年/月粒度补录；具体日期不知道也可以先保存。</span></div>
        <div class="chapter-line"><strong>删除本地数据</strong><span>清空当前浏览器的记忆保险箱。生产版应加入二次确认、恢复窗口和同步状态说明。</span></div>
      </div>
      <div class="action-row">
        <button class="primary" data-export-vault>导出 JSON</button>
        <button class="secondary" data-copy-vault>复制备份</button>
        <button class="secondary" data-import-demo>导入示例</button>
        <button class="ghost danger" data-wipe-vault>清空本地</button>
      </div>
      <p class="source-line">上次导出：${escapeHtml(state.lastExportAt || "尚未导出")}；上次导入：${escapeHtml(state.lastImportAt || "尚未导入")}；上次清空：${escapeHtml(state.vaultDeletedAt || "从未清空")}。</p>
      ${state.toast ? `<p class="toast">${state.toast}</p>` : ""}
    </section>
    <section class="settings-card">
      <h2 class="section-title">隐私中心</h2>
      <div class="chapter-list">
        <div class="chapter-line"><strong>中国区原始记忆默认不出境</strong><span>生产真实记忆进入云端前必须通过数据处理条款审查。</span></div>
        <div class="chapter-line"><strong>每条敏感记忆可设为仅设备</strong><span>儿童、健康、位置和亲密关系默认更谨慎。</span></div>
        <div class="chapter-line"><strong>AI 草稿可撤销</strong><span>事实不对、不像我、太煽情，都可以直接反馈。</span></div>
      </div>
      <div class="sync-map">
        ${syncItem("本机", "localStorage Demo", "当前已可用")}
        ${syncItem("加密盒", "E2EE 记忆保险箱", "生产待做")}
        ${syncItem("模型网关", "DeepSeek / BYOK 路由", "PoC 边界")}
        ${syncItem("删除权", "导出、清空、撤销草稿", "Demo 已覆盖")}
      </div>
      <div class="privacy-toggle">
        <span><strong>${state.deviceOnlyMode ? "仅设备优先" : "允许同步演示"}</strong><em>${state.deviceOnlyMode ? "敏感记忆默认留在本机，AI 只处理必要摘要。" : "当前只是演示开关，生产同步必须另有加密和条款。"}</em></span>
        <button class="secondary" data-device-only>${state.deviceOnlyMode ? "切到同步演示" : "切回仅设备"}</button>
      </div>
      <div class="action-row"><button class="secondary" data-quiet>${state.quietMode ? "关闭安静期" : "进入安静期"}</button><button class="secondary" data-copy-privacy>复制隐私摘要</button><button class="ghost" data-reset>重置 Demo</button></div>
    </section>
    <section class="settings-card">
      <h2 class="section-title">价值阶梯</h2>
      <div class="paywall-grid">
        ${plan("记住 Free", "核心记录永久可用，不是残缺试用版。")}
        ${plan("本地典藏 Pass", "一次买断：高级本地视图与导出。")}
        ${plan("时光生长 Plus", "同步、DeepSeek 编译、月度/季度旷野。")}
        ${plan("BYOK", "高级用户自带模型 Key，自担成本。")}
      </div>
    </section>
  `;
}

function vaultStat(label, value, unit) {
  return `<div class="vault-stat"><strong>${value}</strong><span>${label} · ${unit}</span></div>`;
}

function syncItem(title, copy, status) {
  return `<div class="sync-item"><strong>${title}</strong><span>${copy}</span><em>${status}</em></div>`;
}

function plan(name, copy) {
  return `<div class="plan-card"><strong>${name}<span>›</span></strong><p>${copy}</p></div>`;
}

function bottomNav() {
  const items = [
    ["now", "此刻", "✦"],
    ["slice", "切片", "◉"],
    ["meadow", "旷野", "♧"],
    ["chapter", "章节", "☰"],
    ["ai", "AI", "◇"],
    ["settings", "我的", "◎"]
  ];
  const activeView = state.view === "ritual" ? "chapter" : state.view === "guide" ? "settings" : state.view;
  return `<nav class="bottom-nav">${items.map(([id, label, icon]) => `<button class="nav-btn ${activeView === id ? "active" : ""}" data-view="${id}"><span class="nav-icon">${icon}</span>${label}</button>`).join("")}</nav>`;
}

function sidePanel() {
  return `<aside class="side-panel">
    <section class="desktop-card">
      <div class="eyebrow">Codex Branch</div>
      <h2>时间切片机</h2>
      <p>每天帮助用户发现一个不同，将它保存为今日切片；每周由用户亲自认领三个瞬间，TSD 再将它们编译成可以讲述的故事。</p>
      <div class="kpi-grid">
        <div class="kpi"><strong>90天</strong><span>可讲述成功率</span></div>
        <div class="kpi"><strong>5–15秒</strong><span>Quick Mark</span></div>
        <div class="kpi"><strong>3个</strong><span>周认领瞬间</span></div>
        <div class="kpi"><strong>L0</strong><span>免费底座可用</span></div>
      </div>
    </section>
    <section class="desktop-card">
      <h2>体验路线</h2>
      <div class="timeline">
        ${sideMoment("01", "时间唤醒", "人生周格提醒每周珍贵，但不制造付费焦虑。")}
        ${sideMoment("02", "差异雷达", "寻找今天不像昨天的地方。")}
        ${sideMoment("03", "今日切片", "忠实编辑器只整理，不替你感悟。")}
        ${sideMoment("04", "人生旷野", "长期回看时，花丛和青草一起构成人生。")}
      </div>
    </section>
    <section class="desktop-card">
      <h2>当前状态</h2>
      <p>当前 v9 聚焦生产边界：底部安全区、体验路线、语义缩放、周章节成品、记忆保险箱、月度/季度回忆、试用指南、AI 路由和同步/隐私边界已经可以在公网试用。下一步继续补安装资产或真实模型网关。</p>
    </section>
  </aside>`;
}

function sideMoment(num, title, copy) {
  return `<div class="moment"><div class="moment-pin">${num}</div><div class="moment-body"><strong>${title}</strong><span>${copy}</span></div></div>`;
}

function drawMeadow() {
  const meadow = $("[data-meadow]");
  if (!meadow) return;
  const flowers = state.moments.map((m, i) => {
    const left = 14 + ((i * 23) % 72);
    const top = 28 + ((i * 17) % 48);
    const color = m.strength === "strong" ? "var(--moss)" : i % 2 ? "var(--amber)" : "var(--rose)";
    return `<i class="flower" style="left:${left}%;top:${top}%;background:${color}"></i>`;
  }).join("");
  const grasses = Array.from({ length: 34 }, (_, i) => `<i class="grass-blade" style="left:${(i * 7) % 100}%;bottom:${8 + (i % 5) * 3}px;transform:rotate(${(i % 7) - 3}deg)"></i>`).join("");
  meadow.insertAdjacentHTML("beforeend", flowers + grasses);
}

function drawLifeGrid() {
  const grid = $("[data-life-grid]");
  if (!grid) return;
  const total = 52 * 80;
  const lived = Math.min(total, state.age * 52);
  const cells = Array.from({ length: total }, (_, i) => {
    let cls = "week-cell";
    if (i < lived) cls += " past";
    if ([320, 1180, 1824, 1840, 1868, 1888, 1901, 1912, 1936].includes(i)) cls += " memory";
    if ([1824, 1901, 1936].includes(i)) cls += " strong";
    if (i === lived) cls += " now";
    return `<i class="${cls}" title="week ${i + 1}"></i>`;
  }).join("");
  grid.innerHTML = cells;
}

function escapeHtml(str) {
  return String(str).replace(/[&<>"']/g, c => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));
}

render();
