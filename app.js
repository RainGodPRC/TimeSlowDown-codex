const $ = (sel, root = document) => root.querySelector(sel);
const $$ = (sel, root = document) => [...root.querySelectorAll(sel)];

const STORAGE_KEY = "tsd-codex-demo-state-v1";

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
  quietMode: false
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
  const views = { now: nowView, slice: sliceView, meadow: meadowView, chapter: chapterView, ai: aiView, settings: settingsView };
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
  `;
}

function radarItem(title, copy, icon) {
  return `<div class="radar-item"><div class="radar-copy"><strong>${title}</strong><span>${copy}</span></div><div class="radar-icon">${icon}</div></div>`;
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
  `;
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
  `;
}

function evalRow(title, copy, value) {
  return `<div class="eval-row"><div><strong>${title}</strong><div class="micro">${copy}</div><div class="meter"><i style="width:${value}%"></i></div></div><div class="score">${value}%</div></div>`;
}

function settingsView() {
  return `
    <div class="topline"><div><div class="brand">设置</div><div class="micro">隐私、付费和叙述偏好，都应该说人话。</div></div></div>
    <section class="settings-card">
      <h2 class="section-title">隐私中心</h2>
      <div class="chapter-list">
        <div class="chapter-line"><strong>中国区原始记忆默认不出境</strong><span>生产真实记忆进入云端前必须通过数据处理条款审查。</span></div>
        <div class="chapter-line"><strong>每条敏感记忆可设为仅设备</strong><span>儿童、健康、位置和亲密关系默认更谨慎。</span></div>
        <div class="chapter-line"><strong>AI 草稿可撤销</strong><span>事实不对、不像我、太煽情，都可以直接反馈。</span></div>
      </div>
      <div class="action-row"><button class="secondary" data-quiet>${state.quietMode ? "关闭安静期" : "进入安静期"}</button><button class="ghost" data-reset>重置 Demo</button></div>
    </section>
    <section class="settings-card">
      <h2 class="section-title">价值阶梯</h2>
      <div class="paywall-grid">
        ${plan("记住 Free", "核心记录永久可用，不是残缺试用版。")}
        ${plan("本地典藏 Pass", "一次买断：高级本地视图与导出。")}
        ${plan("时光生长 Plus", "同步、DeepSeek 编译、季度旷野。")}
        ${plan("BYOK", "高级用户自带模型 Key，自担成本。")}
      </div>
    </section>
  `;
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
  return `<nav class="bottom-nav">${items.map(([id, label, icon]) => `<button class="nav-btn ${state.view === id ? "active" : ""}" data-view="${id}"><span class="nav-icon">${icon}</span>${label}</button>`).join("")}</nav>`;
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
      <p>这是商品级 Web Demo 的第一轮可运行版本。后续会继续打磨真实交互、动画、测试集、部署和 GitHub Pages。</p>
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
