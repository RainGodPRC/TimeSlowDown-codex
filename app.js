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
  weeklyClaimed: ["m1", "m2", "m3"],
  age: 36,
  quietMode: false
};

let state = loadState();

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
  const moment = {
    id: `m${Date.now()}`,
    date: "今天",
    title,
    text: faithfulEdit(text, tags),
    tags,
    strength: tags.includes("第一次") || tags.includes("成就") ? "strong" : "memory",
    sources: ["用户原话", "L0 规则层", state.aiMode === "deepseek" ? "DeepSeek PoC 草稿" : "本地模板"]
  };
  setState({ moments: [moment, ...state.moments], view: "slice", draft: "" });
}

function deriveTitle(text) {
  if (text.includes("滑梯")) return "第一次自己爬上滑梯";
  if (text.includes("5公里") || text.includes("5 公里")) return "第一个 5 公里";
  if (text.includes("爸爸") || text.includes("妈妈")) return "和家人的一个短暂瞬间";
  if (text.length <= 10) return "一个先占位的今天";
  return text.replace(/[，。,.！!]/g, " ").trim().slice(0, 14);
}

function faithfulEdit(text, tags) {
  const safe = text.replace(/我突然意识到|人生从此|学会放手/g, "");
  if (safe.length < 8) return `今天先留下一个很短的标记：“${safe}”。你可以周末再补一句为什么。`;
  if (tags.includes("照片")) return `你留下了一张照片，并写下：“${safe}”。TSD 不会描述没有被解析的照片内容。`;
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
  $("[data-ai-mode]")?.addEventListener("click", () => setState({ aiMode: state.aiMode === "rules" ? "deepseek" : "rules" }));
  $("[data-quiet]")?.addEventListener("click", () => setState({ quietMode: !state.quietMode }));
  $("[data-age]")?.addEventListener("input", (e) => setState({ age: Number(e.target.value || 36) }));
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
    <h2 class="slice-title">${m.title}</h2>
    <p class="hero-subtitle">${m.text}</p>
    <div class="slice-meta">${m.tags.map(t => `<span class="meta">${t}</span>`).join("")}</div>
    <div class="source-line">来源：${m.sources.join(" · ")}。无来源的漂亮句子不会进入最终故事。</div>
  </section>`;
}

function meadowView() {
  return `
    <div class="topline"><div><div class="brand">人生旷野</div><div class="micro">有些日子长成花，有些日子只是草。都算人生。</div></div></div>
    <section class="hero-card">
      <div class="eyebrow">Semantic Zoom</div>
      <h1 class="hero-title">这不是相册，<br/>是一片会生长的草原。</h1>
      <p class="hero-subtitle">今天、月、年、十年以后，同一批记忆会在不同尺度下显影。</p>
    </section>
    <div class="meadow" data-meadow><span class="hill"></span></div>
    <section class="grid-card">
      <h2 class="section-title">人生周格 <span class="micro">每周一个格子</span></h2>
      <input data-age type="range" min="18" max="90" value="${state.age}" />
      <p class="micro">当前年龄 ${state.age} 岁。不是制造焦虑，而是提醒每一周都可以留下一个锚点。</p>
      <div class="life-grid" data-life-grid></div>
    </section>
  `;
}

function chapterView() {
  return `
    <div class="topline"><div><div class="brand">本周章节</div><div class="micro">先由你认领三个瞬间，TSD 再编译成可讲述故事。</div></div></div>
    <section class="chapter-card">
      <div class="eyebrow">Claim 3 Moments</div>
      <h2 class="slice-title">这一周：扎根，与开花</h2>
      <p class="hero-subtitle">这不是总结你的人生，只是把你已经确认的三个片段放在一起。</p>
      <div class="chapter-list">
        ${state.moments.slice(0,3).map((m, i) => `<div class="chapter-line"><strong>${i + 1}. ${m.title}</strong><span>${m.text}</span><br/><span class="source-chip">source: ${m.id}</span></div>`).join("")}
      </div>
      <div class="action-row"><button class="primary" data-view="ai">检查 AI 四道门</button><button class="secondary" data-view="slice">再补一张切片</button></div>
    </section>
  `;
}

function aiView() {
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
      <h2 class="section-title">Faithful Memory Editing Eval</h2>
      ${evalRow("事实忠实", "≥ 4.6 / 5", 92)}
      ${evalRow("无来源句子", "进入最终故事 = 0", 100)}
      ${evalRow("过度煽情率", "< 10%", 84)}
      ${evalRow("JSON Schema", "≥ 98%", 98)}
      <p class="source-line">黄金样本 G001：公园滑梯。禁止 AI 写“学会放手”。</p>
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
    ["ai", "AI", "◇"]
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
