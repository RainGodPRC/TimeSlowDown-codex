const $ = (sel, root = document) => root.querySelector(sel);
const $$ = (sel, root = document) => [...root.querySelectorAll(sel)];

const STORAGE_KEY = "tsd-codex-demo-state-v1";
const VAULT_SCHEMA_VERSION = "tsd-codex-vault-v1";
const PUBLIC_DEMO_URL = "https://raingodprc.github.io/TimeSlowDown-codex/";
let deferredInstallPrompt = null;

const seedMoments = [
  {
    id: "m1",
    date: "今天",
    title: "跑完第一个 5 公里",
    text: "最后一公里很想停，但还是跑完了。不是人生从此改变，只是这件事我想记一下。",
    tags: ["第一次", "运动", "成就"],
    strength: "strong",
    media: {
      kind: "video",
      url: "https://example.com/first-5k-finish.mp4",
      label: "first-5k-finish.mp4",
      note: "短视频里能看到最后一公里结束时的喘气和路灯。",
      storage: "external-link",
      source: "Demo 影像线索",
      attachedAt: "2026-07-06T00:00:00.000Z"
    },
    sources: ["用户原话", "T1 忠实整理"]
  },
  {
    id: "m2",
    date: "昨天",
    title: "和爸爸吃了一碗面",
    text: "他说最近睡得还行。我发现他头发又白了一点。TSD 没有替我总结，只把这一幕留住。",
    tags: ["家人", "普通但值得", "晚饭"],
    strength: "memory",
    media: {
      kind: "image",
      url: "https://example.com/noodle-dinner.jpg",
      label: "noodle-dinner.jpg",
      note: "那碗面和桌上的纸巾，比完整日记更能把晚饭带回来。",
      storage: "external-link",
      source: "Demo 影像线索",
      attachedAt: "2026-07-06T00:00:00.000Z"
    },
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
  mediaFilter: "all",
  mediaLayout: "timeline",
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
  quarterRevealed: false,
  mediaDraftUrl: "",
  mediaDraftNote: "",
  mediaDraft: null,
  lastAiTaskAt: "",
  aiDraftRevokedAt: "",
  gatewayStatus: "idle",
  gatewayBudgetCents: 0,
  gatewayConsentAt: "",
  gatewayFallbackAt: "",
  gatewayRevokedAt: "",
  lastComplianceReportAt: "",
  lastQaReportAt: "",
  accountMode: "guest",
  syncMode: "local",
  lastSyncAt: "",
  syncPausedAt: "",
  recoveryUntil: "",
  subscriptionState: "free",
  connectedDevices: 1,
  passCreatedAt: "",
  recoveryKeyCreatedAt: "",
  deviceReviewAt: "",
  accountReportCopiedAt: "",
  lastStudioExportAt: "",
  lastStudioExportAsset: "",
  lastStudioShareAt: "",
  lastMediaExportAt: "",
  mediaDeleteRequestAt: "",
  mediaShareAt: "",
  mediaVaultSealedAt: "",
  mediaPermissionReviewAt: "",
  mediaThumbnailPurgeAt: "",
  mediaFamilyReviewAt: "",
  mediaPackageExportAt: "",
  installPromptSeenAt: "",
  installGuideCopiedAt: "",
  installAttemptAt: "",
  appInstalledAt: "",
  standaloneModeSeenAt: "",
  appShellCheckedAt: "",
  launchPreflightAt: "",
  launchChecksumAt: "",
  launchDeletionReceiptAt: "",
  launchStoreReviewAt: "",
  launchReportCopiedAt: "",
  nativeMigrationReviewAt: "",
  privacyManifestAuditAt: "",
  nativeHandoffCopiedAt: ""
};

let state = loadState();

window.addEventListener("beforeinstallprompt", event => {
  event.preventDefault();
  deferredInstallPrompt = event;
  setState({ installPromptSeenAt: new Date().toLocaleString("zh-CN") });
});

window.addEventListener("appinstalled", () => {
  deferredInstallPrompt = null;
  setState({ appInstalledAt: new Date().toLocaleString("zh-CN"), toast: "已收到浏览器安装完成事件。现在 TSD 更像一个主屏 App 了。" });
});

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
  const media = normalizeMediaDraft();
  const fallbackText = media
    ? `${mediaKindLabel(media.kind)}里有一个我想以后还能回来的瞬间。`
    : "今天有一个还没说清楚、但想先占位的瞬间。";
  const text = state.draft.trim() || media?.note || fallbackText;
  const title = deriveTitle(text);
  const mediaTags = media ? [media.kind === "video" ? "视频" : media.kind === "image" ? "照片" : "影像线索"] : [];
  const tags = [...new Set([...(state.activeTags.length ? state.activeTags : ["普通但值得"]), ...mediaTags])];
  const gates = analyzeMemory(text, tags);
  const moment = {
    id: `m${Date.now()}`,
    date: "今天",
    title,
    text: faithfulEdit(text, tags, gates),
    tags,
    strength: tags.includes("第一次") || tags.includes("成就") ? "strong" : "memory",
    gates,
    media,
    sources: ["用户原话", "L0 规则层", state.aiMode === "deepseek" ? "DeepSeek PoC 草稿" : "本地模板"]
  };
  if (media) moment.sources.push("影像线索");
  setState({ moments: [moment, ...state.moments], view: "slice", draft: "", mediaDraftUrl: "", mediaDraftNote: "", mediaDraft: null });
}

function guessMediaKind(value = "") {
  const lower = value.toLowerCase();
  if (/\.(mp4|mov|webm|m4v)(\?|#|$)/.test(lower) || lower.startsWith("video/")) return "video";
  if (/\.(jpg|jpeg|png|gif|webp|heic|heif|avif)(\?|#|$)/.test(lower) || lower.startsWith("image/")) return "image";
  return "link";
}

function mediaKindLabel(kind) {
  if (kind === "video") return "视频";
  if (kind === "image") return "照片";
  return "影像链接";
}

function formatBytes(bytes = 0) {
  if (!bytes) return "未知大小";
  if (bytes < 1024 * 1024) return `${Math.ceil(bytes / 1024)} KB`;
  return `${(bytes / 1024 / 1024).toFixed(1)} MB`;
}

function mediaHost(url = "") {
  try {
    const parsed = new URL(url);
    return parsed.hostname.replace(/^www\./, "");
  } catch {
    return url.replace(/^https?:\/\//, "").slice(0, 28) || "影像链接";
  }
}

function normalizeMediaDraft() {
  if (state.mediaDraft) {
    return {
      ...state.mediaDraft,
      note: state.mediaDraftNote.trim(),
      attachedAt: new Date().toISOString()
    };
  }
  const url = state.mediaDraftUrl.trim();
  if (!url) return null;
  const kind = guessMediaKind(url);
  return {
    kind,
    url,
    label: mediaHost(url),
    note: state.mediaDraftNote.trim(),
    storage: "external-link",
    source: "用户提供影像链接",
    attachedAt: new Date().toISOString()
  };
}

function attachMediaToMoment(momentId, media, toast) {
  const tag = media.kind === "video" ? "视频" : media.kind === "image" ? "照片" : "影像线索";
  const moments = state.moments.map(moment => {
    if (moment.id !== momentId) return moment;
    return {
      ...moment,
      media: { ...media, attachedAt: new Date().toISOString() },
      tags: [...new Set([...(moment.tags || []), tag])],
      sources: [...new Set([...(moment.sources || []), "影像线索"])]
    };
  });
  setState({ moments, toast });
}

function mediaFromFileBase(file) {
  const kind = guessMediaKind(file.type || file.name);
  return {
    kind,
    label: file.name,
    size: file.size,
    type: file.type || "unknown",
    storage: "browser-local-demo",
    source: "用户选择本地文件",
    previewUrl: "",
    note: "这张影像是后来补到切片上的记忆锚点。"
  };
}

function attachMediaFileToMoment(file, momentId) {
  const base = mediaFromFileBase(file);
  const shouldPreview = base.kind === "image" && file.size <= 900 * 1024;
  if (!shouldPreview) {
    attachMediaToMoment(
      momentId,
      base,
      base.kind === "video" ? "已把视频线索补到这张切片。" : "已把影像文件线索补到这张切片。大图只保存文件名和大小。"
    );
    return;
  }
  const reader = new FileReader();
  reader.onload = () => {
    attachMediaToMoment(momentId, { ...base, previewUrl: String(reader.result || "") }, "已把照片预览补到这张切片，它会出现在媒体记忆墙。");
  };
  reader.onerror = () => {
    attachMediaToMoment(momentId, base, "照片预览读取失败，但已把文件名和大小补到切片。");
  };
  reader.readAsDataURL(file);
}

function attachMediaLinkToMoment(momentId) {
  const url = window.prompt("粘贴这张切片对应的照片/视频链接：");
  if (!url?.trim()) return;
  const note = window.prompt("给这条影像补一句备注（可留空）：") || "";
  const kind = guessMediaKind(url.trim());
  attachMediaToMoment(
    momentId,
    {
      kind,
      url: url.trim(),
      label: mediaHost(url.trim()),
      note: note.trim() || "这条影像链接能把我带回当时。",
      storage: "external-link",
      source: "用户补充影像链接"
    },
    "已把影像链接补到这张切片。"
  );
}

function clearMediaDraft() {
  setState({ mediaDraftUrl: "", mediaDraftNote: "", mediaDraft: null, toast: "已移除本次影像线索。" });
}

function useDemoMedia() {
  setState({
    mediaDraftUrl: "https://example.com/family-park-photo.jpg",
    mediaDraftNote: state.mediaDraftNote || "这张照片能帮我想起当时孩子爬上滑梯前的表情。",
    mediaDraft: null,
    activeTags: [...new Set([...state.activeTags, "照片"])],
    toast: "已放入一条照片链接示例。生产版会接系统相册与加密存储。"
  });
}

function handleMediaFile(event) {
  const file = event.target.files?.[0];
  if (!file) return;
  const attachMomentId = event.currentTarget?.dataset.attachMoment;
  if (attachMomentId) {
    attachMediaFileToMoment(file, attachMomentId);
    return;
  }
  const nextView = event.currentTarget?.dataset.afterView;
  const clearDraft = event.currentTarget?.dataset.clearDraft === "true";
  const onboardFromMedia = event.currentTarget?.dataset.onboardMedia === "true";
  const contextPatch = {
    ...(onboardFromMedia ? { onboarded: true } : {}),
    ...(nextView ? { view: nextView } : {}),
    ...(clearDraft ? { draft: "" } : {})
  };
  const kind = guessMediaKind(file.type || file.name);
  const base = {
    kind,
    label: file.name,
    size: file.size,
    type: file.type || "unknown",
    storage: "browser-local-demo",
    source: "用户选择本地文件",
    previewUrl: "",
    note: state.mediaDraftNote.trim()
  };
  const shouldPreview = kind === "image" && file.size <= 900 * 1024;
  if (!shouldPreview) {
    setState({
      ...contextPatch,
      mediaDraft: base,
      mediaDraftUrl: "",
      activeTags: [...new Set([...state.activeTags, kind === "video" ? "视频" : "照片"])],
      toast: kind === "video" ? "已记录视频文件线索。Demo 不把大视频写入 localStorage。" : "已记录文件线索。大图仅保存文件名和大小，生产版需加密存储。"
    });
    return;
  }
  const reader = new FileReader();
  reader.onload = () => {
    setState({
      ...contextPatch,
      mediaDraft: { ...base, previewUrl: String(reader.result || "") },
      mediaDraftUrl: "",
      activeTags: [...new Set([...state.activeTags, "照片"])],
      toast: "已读取照片预览并作为本地影像线索，生成切片后会一起保存。"
    });
  };
  reader.onerror = () => {
    setState({ ...contextPatch, mediaDraft: base, mediaDraftUrl: "", toast: "照片预览读取失败，但已保留文件名和大小作为线索。" });
  };
  reader.readAsDataURL(file);
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
      mediaFilter: state.mediaFilter,
      mediaLayout: state.mediaLayout,
      age: state.age,
      quietMode: state.quietMode,
      activeTags: state.activeTags,
      monthName: state.monthName,
      monthStarted: state.monthStarted,
      monthEnded: state.monthEnded,
      monthChanged: state.monthChanged,
      quarterRecallDraft: state.quarterRecallDraft,
      quarterRevealed: state.quarterRevealed,
      lastAiTaskAt: state.lastAiTaskAt,
      aiDraftRevokedAt: state.aiDraftRevokedAt,
      gatewayStatus: state.gatewayStatus,
      gatewayBudgetCents: state.gatewayBudgetCents,
      gatewayConsentAt: state.gatewayConsentAt,
      gatewayFallbackAt: state.gatewayFallbackAt,
      gatewayRevokedAt: state.gatewayRevokedAt,
      lastComplianceReportAt: state.lastComplianceReportAt,
      lastQaReportAt: state.lastQaReportAt,
      accountMode: state.accountMode,
      syncMode: state.syncMode,
      lastSyncAt: state.lastSyncAt,
      syncPausedAt: state.syncPausedAt,
      recoveryUntil: state.recoveryUntil,
      subscriptionState: state.subscriptionState,
      connectedDevices: state.connectedDevices,
      passCreatedAt: state.passCreatedAt,
      recoveryKeyCreatedAt: state.recoveryKeyCreatedAt,
      deviceReviewAt: state.deviceReviewAt,
      accountReportCopiedAt: state.accountReportCopiedAt,
      lastStudioExportAt: state.lastStudioExportAt,
      lastStudioExportAsset: state.lastStudioExportAsset,
      lastStudioShareAt: state.lastStudioShareAt,
      lastMediaExportAt: state.lastMediaExportAt,
      mediaDeleteRequestAt: state.mediaDeleteRequestAt,
      mediaShareAt: state.mediaShareAt,
      launchPreflightAt: state.launchPreflightAt,
      launchChecksumAt: state.launchChecksumAt,
      launchDeletionReceiptAt: state.launchDeletionReceiptAt,
      launchStoreReviewAt: state.launchStoreReviewAt,
      launchReportCopiedAt: state.launchReportCopiedAt
    }
  };
}

function vaultStats() {
  const payload = vaultPayload();
  const bytes = new Blob([JSON.stringify(payload)]).size;
  return {
    moments: state.moments.length,
    media: state.moments.filter(moment => moment.media).length,
    claimed: state.weeklyClaimed.filter(id => state.moments.some(moment => moment.id === id)).length,
    chapters: state.chapterTitle || state.chapterStory ? 1 : 0,
    bytes
  };
}

function mediaMoments() {
  return state.moments.filter(moment => moment.media);
}

function filteredMediaMoments() {
  const items = mediaMoments();
  if (state.mediaFilter === "all") return items;
  if (state.mediaFilter === "link") return items.filter(moment => moment.media?.storage === "external-link" || moment.media?.kind === "link");
  return items.filter(moment => moment.media?.kind === state.mediaFilter);
}

function mediaStats() {
  const items = mediaMoments();
  return {
    total: items.length,
    image: items.filter(moment => moment.media?.kind === "image").length,
    video: items.filter(moment => moment.media?.kind === "video").length,
    link: items.filter(moment => moment.media?.storage === "external-link" || moment.media?.kind === "link").length
  };
}

const peopleLensRules = [
  { label: "自己", icon: "我", pattern: /(自己|跑完|5\s*公里|成就|第一次|20\s*岁|自行车|我想记|我确实)/, copy: "那些关于“我做到了 / 我撑过了”的瞬间，会变成一条自我叙事线。" },
  { label: "爸爸", icon: "爸", pattern: /(爸爸|父亲|老爸|爸\b|头发又白|家人)/, copy: "不是宏大的亲情总结，而是能重新讲起的一顿饭、一句话、一个表情。" },
  { label: "孩子", icon: "孩", pattern: /(孩子|滑梯|公园|第一次自己)/, copy: "孩子相关的记忆最容易被日常淹没，影像和一句话能把它们重新拎出来。" },
  { label: "工作关系", icon: "工", pattern: /(开会|工作|同事|公司|被怼|项目|会议)/, copy: "压力、沉默和完成都算；工作不是只有成就，也有天气。" },
  { label: "朋友", icon: "友", pattern: /(朋友|同学|故知|见面|聊天)/, copy: "能从一个人讲起的片段，比按日期翻找更接近真实回忆。" },
  { label: "妈妈", icon: "妈", pattern: /(妈妈|母亲|老妈|妈\b)/, copy: "家庭记忆不需要写成长文，先让一个称呼和一张切片发生连接。" }
];

const placeLensRules = [
  { label: "跑步路线", icon: "跑", pattern: /(5\s*公里|跑完|路灯|最后一公里|运动)/, copy: "身体记忆常常藏在路线、灯光和喘气里。" },
  { label: "饭桌 / 面馆", icon: "面", pattern: /(面|晚饭|饭桌|纸巾|吃了|饭店|面馆)/, copy: "饭桌是很多家庭记忆的取景框，不必写得宏大也值得留下。" },
  { label: "回家路", icon: "路", pattern: /(回家路|路上|那段.*路|路灯|沉默的路)/, copy: "路上的沉默、风和树影，常常是情绪转弯的地方。" },
  { label: "公园", icon: "园", pattern: /(公园|滑梯|草地|河边)/, copy: "地点让回忆从抽象变具体：我在哪里看见了这件事。" },
  { label: "公司 / 会议室", icon: "会", pattern: /(公司|开会|会议|工作|被怼|项目)/, copy: "这里记录的不只是绩效，而是人如何穿过压力。" },
  { label: "家", icon: "家", pattern: /(家里|回家|家人|爸爸|妈妈|孩子)/, copy: "家不是一个固定标签，而是一组能被讲起的生活画面。" }
];

function lensSourceText(moment) {
  return [
    moment.title,
    moment.text,
    ...(moment.tags || []),
    moment.media?.note,
    moment.media?.label
  ].filter(Boolean).join(" ");
}

function buildLens(ruleSet) {
  return ruleSet.map(rule => {
    const moments = state.moments.filter(moment => rule.pattern.test(lensSourceText(moment)));
    return { ...rule, moments, mediaCount: moments.filter(moment => moment.media).length };
  }).filter(item => item.moments.length)
    .sort((a, b) => b.moments.length - a.moments.length || b.mediaCount - a.mediaCount);
}

function peopleLens() {
  return buildLens(peopleLensRules);
}

function placeLens() {
  return buildLens(placeLensRules);
}

function lensTimeline() {
  const people = peopleLens();
  const places = placeLens();
  return state.moments.slice(0, 6).map(moment => {
    const text = lensSourceText(moment);
    const person = people.find(item => item.pattern.test(text));
    const place = places.find(item => item.pattern.test(text));
    return {
      moment,
      person: person?.label || "未命名的人",
      place: place?.label || "未命名地点"
    };
  });
}

function mediaLibraryStats() {
  const items = mediaMoments();
  const local = items.filter(moment => moment.media?.storage === "browser-local-demo").length;
  const external = items.filter(moment => moment.media?.storage === "external-link" || moment.media?.kind === "link").length;
  const previews = items.filter(moment => moment.media?.previewUrl).length;
  const sensitive = items.filter(moment => /孩子|爸爸|妈妈|家人|儿童|家庭|医院|病/.test(`${moment.title} ${moment.text} ${(moment.tags || []).join(" ")} ${moment.media?.note || ""}`)).length;
  return {
    total: items.length,
    local,
    external,
    previews,
    encrypted: items.length,
    deleteQueue: state.mediaDeleteRequestAt ? 1 : 0,
    sensitive,
    sealed: state.mediaVaultSealedAt ? items.length : 0,
    packageReady: state.mediaPackageExportAt ? 1 : 0
  };
}

function mediaLibraryManifest() {
  const stats = mediaLibraryStats();
  return {
    product: "TimeSlowDown Media Vault Path",
    version: "v32-demo",
    generatedAt: new Date().toISOString(),
    boundary: "Demo only: no persistent Photos permission, no GPS, no contacts, no face recognition, no real E2EE service. v32 adds Native Handoff Ledger on top of Launch Readiness, mobile UI polish, Bento cards, Journal timeline, photo wall, and map-style media switching while keeping Memory Camera, account rights, media vault path, and app-like install boundaries.",
    vaultState: {
      permission: state.mediaPermissionReviewAt ? "limited-picker-reviewed" : "single-picker-only",
      sealedAt: state.mediaVaultSealedAt || "",
      thumbnailPurgeAt: state.mediaThumbnailPurgeAt || "",
      familyReviewAt: state.mediaFamilyReviewAt || "",
      packageExportAt: state.mediaPackageExportAt || "",
      deleteRequestAt: state.mediaDeleteRequestAt || "",
      mediaCount: stats.total,
      sensitiveCandidateCount: stats.sensitive
    },
    media: mediaMoments().map(moment => ({
      sliceId: moment.id,
      date: moment.date,
      title: moment.title,
      kind: moment.media?.kind,
      label: moment.media?.label,
      storage: moment.media?.storage,
      hasPreview: Boolean(moment.media?.previewUrl),
      source: moment.media?.source || "unknown"
    }))
  };
}

function simulatePermissionReview() {
  setState({
    mediaPermissionReviewAt: new Date().toLocaleString("zh-CN"),
    toast: "已模拟有限相册选择说明：TSD 只访问本次选中的照片/视频，批量整理前再解释权限升级。"
  });
}

function sealMediaVaultDemo() {
  setState({
    mediaVaultSealedAt: new Date().toLocaleString("zh-CN"),
    toast: "已模拟封存媒体保险箱：原图/视频、缩略图和切片索引应分别加密、分别可导出/删除。"
  });
}

function purgeMediaThumbnailsDemo() {
  setState({
    mediaThumbnailPurgeAt: new Date().toLocaleString("zh-CN"),
    toast: "已模拟清除缩略图缓存。生产版应保留原始文件权利，同时重建或删除预览。"
  });
}

function markFamilyMediaReview() {
  setState({
    mediaFamilyReviewAt: new Date().toLocaleString("zh-CN"),
    toast: "已模拟家庭/儿童影像复核：公开分享默认隐藏原图、人名、地点和原文。"
  });
}

function exportMediaPackageDemo() {
  setState({
    mediaPackageExportAt: new Date().toLocaleString("zh-CN"),
    lastMediaExportAt: new Date().toLocaleString("zh-CN"),
    toast: "已模拟生成媒体导出包：原图/视频、缩略图、切片 JSON、source 追溯和可读说明。"
  });
}

async function copyMediaLibraryReport() {
  const manifest = JSON.stringify(mediaLibraryManifest(), null, 2);
  try {
    if (!navigator.clipboard) throw new Error("clipboard unavailable");
    await navigator.clipboard.writeText(manifest);
    setState({ lastMediaExportAt: new Date().toLocaleString("zh-CN"), toast: "媒体库清单已复制。生产版应导出原图/视频与缩略图包。" });
  } catch {
    setState({ lastMediaExportAt: new Date().toLocaleString("zh-CN"), toast: "浏览器不允许复制；已模拟生成媒体库清单。" });
  }
}

function simulateMediaDelete() {
  setState({
    mediaDeleteRequestAt: new Date().toLocaleString("zh-CN"),
    toast: "已模拟提交原始影像删除请求。生产版应删除原图、缩略图、云副本和模型任务缓存。"
  });
}

async function shareMediaLibraryDemo() {
  const shareText = `我用 TimeSlowDown 留下了 ${mediaMoments().length} 个带影像锚点的记忆。公开分享只包含时间风景，不包含原图、地点、人名或原文。`;
  const stamp = new Date().toLocaleString("zh-CN");
  try {
    if (navigator.share) {
      setState({ mediaShareAt: stamp, toast: "正在调用系统分享面板；原始影像不会被自动分享。" });
      await navigator.share({ title: "TimeSlowDown 媒体记忆", text: shareText, url: PUBLIC_DEMO_URL });
      setState({ mediaShareAt: stamp, toast: "已调用系统分享面板。生产版应先生成去隐私分享包。" });
      return;
    }
    if (!navigator.clipboard) throw new Error("share unavailable");
    await navigator.clipboard.writeText(shareText);
    setState({ mediaShareAt: stamp, toast: "当前浏览器无 Web Share；已复制去隐私分享文案。" });
  } catch {
    setState({ mediaShareAt: stamp, toast: "分享被取消或不可用；记忆仍保留在本机 Demo 中。" });
  }
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
    const mediaTrace = moment.media ? `；影像锚点：${mediaKindLabel(moment.media.kind)}《${moment.media.label || "未命名"}》` : "";
    return `${index + 1}. ${plain}${mediaTrace}（source: ${moment.id}）`;
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
    const mediaCount = getClaimedMoments().filter(moment => moment.media).length;
    return `${title}\n\n我用 TimeSlowDown 留下了这一周的几个瞬间${mediaCount ? `，其中 ${mediaCount} 个带有影像锚点` : ""}。具体人名、地点、原文和原始影像已隐藏，只分享这片小小的时间痕迹。`;
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

function studioAssets() {
  const claimed = getClaimedMoments().slice(0, 3);
  const title = state.chapterTitle || deriveChapterTitle(claimed);
  const story = state.chapterStory || buildChapterStory(claimed);
  const publicMode = state.shareMode === "public";
  const tellable = quarterStats().candidates.slice(0, 4);
  const mediaCount = state.moments.filter(moment => moment.media).length;
  return [
    {
      id: "week",
      eyebrow: "Weekly Poster",
      title,
      badge: `本周 3 个瞬间${claimed.filter(moment => moment.media).length ? " · 有影像锚点" : ""}`,
      className: "week",
      body: publicMode
        ? "这一周留下了几个被认领的瞬间。具体人名、地点和原文已隐藏，只分享时间长出花的样子。"
        : story.split("\n").slice(0, 4).join("\n"),
      footer: publicMode ? "公开风景 · 可发朋友圈" : "讲给亲友 · 保留细节"
    },
    {
      id: "quarter",
      eyebrow: "90-Day Card",
      title: "过去三个月，有些瞬间还亮着",
      badge: `${tellable.length} 个可讲述片段 · ${tellable.filter(moment => moment.media).length} 个影像锚点`,
      className: "quarter",
      body: publicMode
        ? tellable.map(moment => `• ${moment.title}`).join("\n")
        : tellable.map(moment => `• ${moment.title}｜${moment.text}`).join("\n"),
      footer: "自由回忆 + 线索唤回"
    },
    {
      id: "meadow",
      eyebrow: "Life Meadow",
      title: "让走过的时间，长成你的人生",
      badge: `${state.moments.length} 张切片 · ${mediaCount} 个影像锚点`,
      className: "meadow-card",
      body: publicMode
        ? "有些日子长出花丛，有些日子只有浅浅青草。照片、视频、文字一起构成完整旷野，不只记录高光。"
        : `${state.moments.slice(0, 3).map(moment => moment.media ? `${moment.title}（有影像）` : moment.title).join("、")}，正在成为这片旷野里能被指认的地方。`,
      footer: "人生旷野 · 语义缩放"
    }
  ];
}

function makeStudioText(assetId = "week") {
  const asset = studioAssets().find(item => item.id === assetId) || studioAssets()[0];
  return [
    `【${asset.title}】`,
    asset.body,
    "",
    `${asset.footer}｜来自 TimeSlowDown`
  ].join("\n");
}

async function copyStudioCard(event) {
  const assetId = event?.currentTarget?.dataset.studioCopy || "week";
  try {
    if (!navigator.clipboard) throw new Error("clipboard unavailable");
    await navigator.clipboard.writeText(makeStudioText(assetId));
    setState({ toast: state.shareMode === "public" ? "已复制公开版视觉卡文案。" : "已复制私密版视觉卡文案。" });
  } catch {
    setState({ toast: "浏览器不允许自动复制；请直接查看分享工作室卡片。" });
  }
}

function studioAssetById(assetId = "week") {
  return studioAssets().find(item => item.id === assetId) || studioAssets()[0];
}

function wrapCanvasText(ctx, text, x, y, maxWidth, lineHeight, maxLines = 8) {
  const normalized = String(text || "").replace(/\n/g, " ");
  const tokens = normalized.match(/[\u4e00-\u9fa5]|[^\s\u4e00-\u9fa5]+/g) || [];
  let line = "";
  let lines = 0;
  for (const token of tokens) {
    const spacer = /^[\u4e00-\u9fa5]$/.test(token) || !line ? "" : " ";
    const testLine = `${line}${spacer}${token}`;
    if (ctx.measureText(testLine).width > maxWidth && line) {
      ctx.fillText(line, x, y);
      y += lineHeight;
      lines += 1;
      line = token;
      if (lines >= maxLines - 1) break;
    } else {
      line = testLine;
    }
  }
  if (line && lines < maxLines) ctx.fillText(lines >= maxLines - 1 && line.length > 32 ? `${line.slice(0, 32)}…` : line, x, y);
}

function roundedRectPath(ctx, x, y, width, height, radius) {
  const r = Math.min(radius, width / 2, height / 2);
  ctx.beginPath();
  ctx.moveTo(x + r, y);
  ctx.arcTo(x + width, y, x + width, y + height, r);
  ctx.arcTo(x + width, y + height, x, y + height, r);
  ctx.arcTo(x, y + height, x, y, r);
  ctx.arcTo(x, y, x + width, y, r);
  ctx.closePath();
}

function renderStudioPng(asset) {
  const canvas = document.createElement("canvas");
  canvas.width = 1080;
  canvas.height = 1350;
  const ctx = canvas.getContext("2d");
  const gradient = ctx.createLinearGradient(0, 0, 1080, 1350);
  gradient.addColorStop(0, "#fffdf7");
  gradient.addColorStop(.48, asset.id === "quarter" ? "#dcead8" : "#f4efe4");
  gradient.addColorStop(1, asset.id === "meadow" ? "#bdcfad" : "#d7e5ec");
  ctx.fillStyle = gradient;
  ctx.fillRect(0, 0, 1080, 1350);

  ctx.fillStyle = "rgba(85,116,95,.13)";
  ctx.beginPath();
  ctx.ellipse(540, 1035, 520, 260, 0, 0, Math.PI * 2);
  ctx.fill();
  [["#d7a85f", 250, 730, 52], ["#b8796c", 540, 630, 44], ["#55745f", 810, 760, 48]].forEach(([color, x, y, r]) => {
    ctx.fillStyle = color;
    ctx.beginPath();
    ctx.arc(x, y, r, 0, Math.PI * 2);
    ctx.fill();
    ctx.strokeStyle = `${color}33`;
    ctx.lineWidth = 26;
    ctx.stroke();
  });

  roundedRectPath(ctx, 86, 86, 908, 1178, 56);
  ctx.fillStyle = "rgba(255,253,247,.78)";
  ctx.fill();
  ctx.strokeStyle = "rgba(32,52,43,.12)";
  ctx.lineWidth = 3;
  ctx.stroke();

  ctx.fillStyle = "#55745f";
  ctx.font = "700 30px -apple-system, BlinkMacSystemFont, sans-serif";
  ctx.fillText(asset.eyebrow.toUpperCase(), 142, 178);
  ctx.fillStyle = "#20342b";
  ctx.font = "700 68px Songti SC, STSong, serif";
  wrapCanvasText(ctx, asset.title, 142, 284, 790, 82, 3);

  ctx.fillStyle = "rgba(85,116,95,.12)";
  roundedRectPath(ctx, 142, 432, 620, 64, 32);
  ctx.fill();
  ctx.fillStyle = "#55745f";
  ctx.font = "800 28px -apple-system, BlinkMacSystemFont, sans-serif";
  ctx.fillText(asset.badge.slice(0, 34), 172, 474);

  ctx.fillStyle = "#59685e";
  ctx.font = "400 34px -apple-system, BlinkMacSystemFont, sans-serif";
  wrapCanvasText(ctx, asset.body, 142, 585, 790, 52, 8);

  ctx.fillStyle = "#b8796c";
  ctx.font = "800 30px -apple-system, BlinkMacSystemFont, sans-serif";
  ctx.fillText(asset.footer, 142, 1148);
  ctx.fillStyle = "rgba(32,52,43,.58)";
  ctx.font = "700 26px -apple-system, BlinkMacSystemFont, sans-serif";
  ctx.fillText("TimeSlowDown · 让走过的时间，长成你的人生", 142, 1204);
  ctx.fillText(state.shareMode === "public" ? "公开版：已隐藏具体人名、地点、原文和原始影像" : "私密版：仅适合主动发给信任的人", 142, 1244);
  return canvas.toDataURL("image/png");
}

function downloadDataUrl(dataUrl, filename) {
  const anchor = document.createElement("a");
  anchor.href = dataUrl;
  anchor.download = filename;
  document.body.appendChild(anchor);
  anchor.click();
  anchor.remove();
}

async function downloadStudioCard(event) {
  const asset = studioAssetById(event?.currentTarget?.dataset.studioDownload || "week");
  const stamp = new Date().toLocaleString("zh-CN");
  try {
    const dataUrl = renderStudioPng(asset);
    downloadDataUrl(dataUrl, `timeslowdown-${asset.id}-${state.shareMode}.png`);
    setState({
      lastStudioExportAt: stamp,
      lastStudioExportAsset: asset.id,
      toast: `已生成 ${asset.title} 的 PNG 图片；${state.shareMode === "public" ? "公开版已去细节。" : "私密版请只发给信任的人。"}`
    });
  } catch {
    setState({ toast: "当前浏览器无法生成 PNG；请先复制卡片文案或截图保存。" });
  }
}

async function shareStudioCard(event) {
  const asset = studioAssetById(event?.currentTarget?.dataset.studioShare || "week");
  const stamp = new Date().toLocaleString("zh-CN");
  const text = makeStudioText(asset.id);
  try {
    const dataUrl = renderStudioPng(asset);
    const blob = await (await fetch(dataUrl)).blob();
    const file = new File([blob], `timeslowdown-${asset.id}-${state.shareMode}.png`, { type: "image/png" });
    if (navigator.share && (!navigator.canShare || navigator.canShare({ files: [file] }))) {
      await navigator.share({ title: asset.title, text, files: [file] });
      setState({ lastStudioShareAt: stamp, toast: "已调用系统分享面板；原始影像不会被自动分享。" });
      return;
    }
    if (!navigator.clipboard) throw new Error("share unavailable");
    await navigator.clipboard.writeText(text);
    setState({ lastStudioShareAt: stamp, toast: "当前浏览器无图片分享；已复制去隐私分享文案。" });
  } catch {
    setState({ lastStudioShareAt: stamp, toast: "分享被取消或不可用；PNG 仍可手动导出，记忆仍保留在本机 Demo 中。" });
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

function isStandaloneMode() {
  return Boolean(window.matchMedia?.("(display-mode: standalone)")?.matches || window.navigator.standalone);
}

function installPlatformHint() {
  const ua = navigator.userAgent || "";
  if (/iPhone|iPad|iPod/i.test(ua)) return "iOS Safari：分享按钮 → 添加到主屏幕";
  if (/Android/i.test(ua)) return "Android Chrome：菜单 → 安装应用 / 添加到主屏幕";
  if (/Chrome|Edge|Brave/i.test(ua)) return "桌面 Chromium：地址栏安装图标或浏览器菜单 → 安装";
  return "浏览器菜单：添加到主屏幕 / 安装应用";
}

function installManifestState() {
  return {
    hasManifest: Boolean(document.querySelector('link[rel="manifest"]')),
    hasAppleMeta: Boolean(document.querySelector('meta[name="apple-mobile-web-app-capable"]')),
    hasTouchIcon: Boolean(document.querySelector('link[rel="apple-touch-icon"]')),
    standalone: isStandaloneMode(),
    promptReady: Boolean(deferredInstallPrompt),
    platform: installPlatformHint()
  };
}

async function requestInstallDemo() {
  const stamp = new Date().toLocaleString("zh-CN");
  if (deferredInstallPrompt) {
    try {
      deferredInstallPrompt.prompt();
      const choice = await deferredInstallPrompt.userChoice;
      deferredInstallPrompt = null;
      setState({ installAttemptAt: stamp, toast: `浏览器安装提示已触发：${choice?.outcome || "unknown"}。` });
      return;
    } catch {
      deferredInstallPrompt = null;
      setState({ installAttemptAt: stamp, toast: "浏览器安装提示不可用；请按下方手动安装说明操作。" });
      return;
    }
  }
  setState({ installAttemptAt: stamp, toast: "当前浏览器没有开放安装提示；请使用“复制安装说明”里的手动步骤。" });
}

async function copyInstallGuide() {
  const manifest = installManifestState();
  const text = [
    "TimeSlowDown Codex 安装说明（Demo v32）：",
    `公网地址：${PUBLIC_DEMO_URL}`,
    "",
    "iPhone / iPad：用 Safari 打开 → 点分享按钮 → 添加到主屏幕。",
    "Android：用 Chrome 打开 → 菜单 → 安装应用 / 添加到主屏幕。",
    "桌面 Chrome / Edge：打开地址栏右侧安装图标，或菜单 → 安装 TimeSlowDown。",
    "",
    `当前检测：manifest=${manifest.hasManifest ? "yes" : "no"}；apple-meta=${manifest.hasAppleMeta ? "yes" : "no"}；standalone=${manifest.standalone ? "yes" : "no"}；prompt=${manifest.promptReady ? "ready" : "manual"}.`,
    "边界：v32 使用 inline manifest 和 iOS meta，不新增文件；尚未接入 service worker/offline cache，也不是原生 iOS 壳。"
  ].join("\n");
  const stamp = new Date().toLocaleString("zh-CN");
  try {
    if (!navigator.clipboard) throw new Error("clipboard unavailable");
    await navigator.clipboard.writeText(text);
    setState({ installGuideCopiedAt: stamp, toast: "安装说明已复制，可以直接发给试用者。" });
  } catch {
    setState({ installGuideCopiedAt: stamp, toast: "浏览器不允许自动复制；请直接查看安装中心步骤。" });
  }
}

function checkAppShell() {
  const manifest = installManifestState();
  setState({
    appShellCheckedAt: new Date().toLocaleString("zh-CN"),
    standaloneModeSeenAt: manifest.standalone ? new Date().toLocaleString("zh-CN") : state.standaloneModeSeenAt,
    toast: manifest.standalone ? "当前已经在独立 App 窗口中运行。" : "当前仍在浏览器标签页中；可按安装说明添加到主屏幕。"
  });
}

function launchChecksum() {
  const text = JSON.stringify(vaultPayload());
  let hash = 2166136261;
  for (let i = 0; i < text.length; i += 1) {
    hash ^= text.charCodeAt(i);
    hash = Math.imul(hash, 16777619);
  }
  return `tsd-${(hash >>> 0).toString(16).padStart(8, "0")}-${text.length}`;
}

function launchReadinessRows() {
  const mediaCount = mediaMoments().length;
  const stats = vaultStats();
  return [
    ["Memory capture", "ready", "照片/视频可从 onboarding、顶部 Dock、底部“＋影像”、此刻页和媒体墙进入。"],
    ["Local vault", "ready", `${stats.moments} 条切片、${stats.media} 个影像锚点可导出为 JSON。`],
    ["Media vault", state.mediaVaultSealedAt || state.mediaPackageExportAt ? "ready" : "poc", mediaCount ? `${mediaCount} 个影像锚点；E2EE/导出包/删除审计为 PoC。` : "等待用户绑定第一张真实影像。"],
    ["Account rights", state.passCreatedAt || state.recoveryKeyCreatedAt ? "ready" : "poc", "访客可用、通行证、恢复钥匙、设备复核和退订取回均可演示。"],
    ["AI gateway", state.gatewayStatus !== "idle" ? "ready" : "poc", "DeepSeek V4 Flash 仍是假面；任务单、预算、队列、降级和撤销可演示。"],
    ["Export checksum", state.launchChecksumAt ? "ready" : "poc", state.launchChecksumAt ? `最近校验：${state.launchChecksumAt}` : "可生成导出包 checksum，真实签名待做。"],
    ["Deletion receipt", state.launchDeletionReceiptAt ? "ready" : "poc", state.launchDeletionReceiptAt ? `最近回执：${state.launchDeletionReceiptAt}` : "可模拟删除原文、原图、缩略图、云副本和模型缓存回执。"],
    ["App shell", state.appShellCheckedAt ? "ready" : "poc", "inline manifest、iOS meta、touch icon 与安装说明已可试用；离线缓存待做。"],
    ["Store review", state.launchStoreReviewAt ? "ready" : "todo", "正式隐私政策、DPA、原生权限弹窗和 App Store 审核仍需生产完成。"]
  ];
}

function nativeHandoffRows() {
  const mediaCount = mediaMoments().length;
  return [
    ["SwiftUI shell", state.nativeMigrationReviewAt ? "poc" : "todo", "iOS", "把当前 7 个底部入口迁成 SwiftUI Tab / NavigationStack；Web Demo 只做交互证明。"],
    ["PhotosPicker", state.privacyManifestAuditAt ? "poc" : "todo", "iOS", `用系统 PhotosPicker / limited library 取代 Web file input；当前 ${mediaCount} 个影像锚点可作为迁移样本。`],
    ["Keychain + E2EE", state.nativeMigrationReviewAt ? "poc" : "todo", "iOS + backend", "访客通行证、恢复钥匙和设备复核需要落到 Keychain、Secure Enclave 能力与服务端密钥恢复。"],
    ["Media package", state.mediaPackageExportAt ? "poc" : "todo", "iOS", "媒体包需要文件级 checksum、缩略图生命周期、原图导出和删除回执；当前仅演示 manifest。"],
    ["DeepSeek gateway", state.gatewayStatus !== "idle" ? "poc" : "todo", "backend", "PoC 模型为 DeepSeek V4 Flash；生产需服务端密钥、任务回放、限流、缓存删除和供应商审查。"],
    ["App Privacy Details", state.privacyManifestAuditAt ? "poc" : "todo", "App Store Connect", "把文字、照片/视频、用户内容、诊断、账号、订阅、AI 处理等数据类别映射到 App Store 隐私问卷。"],
    ["Privacy Manifest", state.privacyManifestAuditAt ? "poc" : "todo", "iOS", "追踪 SDK、第三方 SDK privacy manifest、required reason API、文件时间戳/UserDefaults/磁盘空间等 API 使用需要逐项审计。"],
    ["TestFlight packet", state.launchStoreReviewAt ? "poc" : "todo", "release", "准备审核说明、演示账号、订阅解释、AI 说明、儿童/家庭影像边界和删除/导出路径截图。"]
  ];
}

function nativeHandoffStats() {
  const rows = nativeHandoffRows();
  return {
    poc: rows.filter(row => row[1] === "poc").length,
    todo: rows.filter(row => row[1] === "todo").length,
    total: rows.length
  };
}

function launchStats() {
  const rows = launchReadinessRows();
  return {
    ready: rows.filter(row => row[1] === "ready").length,
    poc: rows.filter(row => row[1] === "poc").length,
    todo: rows.filter(row => row[1] === "todo").length,
    total: rows.length
  };
}

function runLaunchPreflight() {
  setState({
    launchPreflightAt: new Date().toLocaleString("zh-CN"),
    toast: "已跑完上架前预检：媒体入口、记忆保险箱、账户权利、AI 网关、隐私中心和 QA Console 均已纳入账本。"
  });
}

function verifyLaunchExport() {
  setState({
    launchChecksumAt: new Date().toLocaleString("zh-CN"),
    toast: `已生成导出包校验码：${launchChecksum()}。生产版应改为签名 manifest 与可重算校验。`
  });
}

function issueDeletionReceipt() {
  setState({
    launchDeletionReceiptAt: new Date().toLocaleString("zh-CN"),
    mediaDeleteRequestAt: state.mediaDeleteRequestAt || new Date().toLocaleString("zh-CN"),
    toast: "已模拟删除回执：原文、原图/视频、缩略图、云副本、模型任务缓存都应进入删除账本。"
  });
}

function markStoreReviewPacket() {
  setState({
    launchStoreReviewAt: new Date().toLocaleString("zh-CN"),
    toast: "已标记 App Store 审核包待复核：隐私标签、权限文案、AI 说明、儿童/家庭影像和订阅权利需正式法务确认。"
  });
}

function markNativeMigrationReview() {
  setState({
    nativeMigrationReviewAt: new Date().toLocaleString("zh-CN"),
    toast: "已标记原生迁移复核：SwiftUI 壳、PhotosPicker、Keychain/E2EE、媒体包和 DeepSeek 网关进入 iOS 施工账本。"
  });
}

function markPrivacyManifestAudit() {
  setState({
    privacyManifestAuditAt: new Date().toLocaleString("zh-CN"),
    toast: "已标记 Privacy Manifest / App Privacy Details 审计：required reason API、第三方 SDK 和数据类别需要逐项追踪。"
  });
}

async function copyNativeHandoffReport() {
  const stats = nativeHandoffStats();
  const text = [
    "TimeSlowDown Native Handoff Ledger（Demo v32）：",
    `公网：${PUBLIC_DEMO_URL}`,
    `资源：styles.css?v=32 / app.js?v=32`,
    `原生迁移复核：${state.nativeMigrationReviewAt || "尚未标记"}`,
    `Privacy Manifest 审计：${state.privacyManifestAuditAt || "尚未标记"}`,
    `状态：poc=${stats.poc} / todo=${stats.todo} / total=${stats.total}`,
    "",
    ...nativeHandoffRows().map(([name, status, owner, copy], index) => `${index + 1}. [${status.toUpperCase()}] ${name} · owner=${owner} — ${copy}`),
    "",
    "官方依据：App Store Review Guidelines、App Privacy Details、Privacy Manifest / required reason API。此报告是工程移交账本，不代表已经通过 Apple 审核。"
  ].join("\n");
  const stamp = new Date().toLocaleString("zh-CN");
  try {
    if (!navigator.clipboard) throw new Error("clipboard unavailable");
    await navigator.clipboard.writeText(text);
    setState({ nativeHandoffCopiedAt: stamp, toast: "Native Handoff Ledger 已复制，可交给 iOS / backend / legal 继续施工。" });
  } catch {
    setState({ nativeHandoffCopiedAt: stamp, toast: "浏览器不允许自动复制；已在上架就绪中心生成 Native Handoff 内容。" });
  }
}

async function copyLaunchReport() {
  const stats = launchStats();
  const nativeStats = nativeHandoffStats();
  const text = [
    "TimeSlowDown Launch Readiness Report（Demo v32）：",
    `公网：${PUBLIC_DEMO_URL}`,
    `资源：styles.css?v=32 / app.js?v=32`,
    `预检：${state.launchPreflightAt || "尚未运行"}`,
    `导出校验：${state.launchChecksumAt ? launchChecksum() : "尚未生成"}`,
    `删除回执：${state.launchDeletionReceiptAt || "尚未生成"}`,
    `App Store 审核包：${state.launchStoreReviewAt || "尚未标记"}`,
    `状态：ready=${stats.ready} / poc=${stats.poc} / todo=${stats.todo} / total=${stats.total}`,
    `Native handoff：poc=${nativeStats.poc} / todo=${nativeStats.todo} / total=${nativeStats.total}`,
    "",
    ...launchReadinessRows().map(([name, status, copy], index) => `${index + 1}. [${status.toUpperCase()}] ${name} — ${copy}`),
    "",
    "Native Handoff:",
    ...nativeHandoffRows().map(([name, status, owner, copy], index) => `${index + 1}. [${status.toUpperCase()}] ${name} · ${owner} — ${copy}`),
    "",
    "说明：这是 Web Demo 的上架就绪账本，不代表真实 iOS 原生壳、真实 E2EE、真实 DeepSeek API 或正式法律文本已完成。"
  ].join("\n");
  const stamp = new Date().toLocaleString("zh-CN");
  try {
    if (!navigator.clipboard) throw new Error("clipboard unavailable");
    await navigator.clipboard.writeText(text);
    setState({ launchReportCopiedAt: stamp, toast: "Launch Readiness 报告已复制，可发给测试者、agent 或未来审核角色。" });
  } catch {
    setState({ launchReportCopiedAt: stamp, toast: "浏览器不允许自动复制；已在上架就绪中心生成报告内容。" });
  }
}

async function copyPrivacySummary() {
  const text = [
    "TimeSlowDown Codex Demo 隐私摘要：",
    "1. 当前公网 Demo 不接入真实登录、云同步或真实 DeepSeek API。",
    "2. Demo 数据保存在当前浏览器 localStorage，可导出 JSON，也可清空。",
    "3. AI 任务单只模拟最小必要字段：被认领切片、来源、用户授权目的；不会发送完整人生档案或原始影像。",
    "4. v32 已支持生产隐私中心、账户权利中心、模型网关控制台、分享工作室 PNG 导出、Memory Camera、媒体保险箱路径、安装中心、Launch Readiness、Native Handoff Ledger 和 Demo QA Console。",
    "5. 媒体策略：照片/视频是切片入口，不是事后附件；v32 保留顶部 Dock、底部“＋影像”、首次进入影像入口、Quick Mark 影像区、媒体墙直接添加、旧切片补影像主路径。",
    "6. 账户策略：不登录也能记录；登录只为加密备份、多设备和恢复。退订不能扣留已有记忆，导出/查看/删除必须继续可用。",
    "7. 生产版必须在账户同步、E2EE、模型处理、删除恢复窗口、权限升级理由、媒体导出/删除审计和地区数据边界完成后，才允许处理真实用户记忆。",
    "8. AI 只做忠实编辑，不替用户决定人生意义。"
  ].join("\n");
  try {
    if (!navigator.clipboard) throw new Error("clipboard unavailable");
    await navigator.clipboard.writeText(text);
    setState({ toast: "隐私摘要已复制，可发给试用者或审核者。" });
  } catch {
    setState({ toast: "浏览器不允许自动复制；请手动查看隐私摘要。" });
  }
}

async function copyReviewPacket() {
  const text = [
    "TimeSlowDown Codex Demo 审核包摘要：",
    "1. 当前公网 Demo 是 Web 原型，不是已提交 App Store 的 iOS App。",
    "2. 权限策略：Demo 不请求持久相册、定位、通讯录、日历、麦克风或通知权限；影像只来自用户主动选择的文件或粘贴的链接。",
    "3. 数据策略：Demo 数据保存在浏览器 localStorage，可导出 JSON、复制备份、清空本地数据。",
    "4. AI 策略：当前不调用真实 DeepSeek API；AI 任务单只展示未来最小字段、禁止字段、失败降级和撤销权。",
    "5. 媒体策略：v32 保留照片/视频主路径：顶部 Dock、底部“＋影像”、首次进入影像入口、Quick Mark 影像区、媒体墙直接添加、已有切片事后补影像；并演示有限相册选择、E2EE 影像库、缩略图、媒体导出包、删除审计、家庭/儿童影像复核、PNG 分享成品、模型任务缓存删除和 Web Share 边界；不做人脸识别或 GPS 推断。",
    "6. 同步策略：同步控制台是状态机演示；真实账户、E2EE、密钥恢复、地区数据边界仍属生产待做。",
    "7. 上线前必须完成正式隐私政策、权限说明、供应商审查、生成式 AI 标识、Privacy Manifest / required reason API 审计、导出包签名、删除回执与法律评审。"
  ].join("\n");
  try {
    if (!navigator.clipboard) throw new Error("clipboard unavailable");
    await navigator.clipboard.writeText(text);
    setState({ toast: "审核包摘要已复制，可发给试用者、agent 或未来审核角色。" });
  } catch {
    setState({ toast: "浏览器不允许自动复制；请直接查看审核中心内容。" });
  }
}

async function copyComplianceReport() {
  const text = [
    "TimeSlowDown 生产隐私报告（Demo v32）：",
    "1. 当前 Demo：静态站点 + localStorage；不登录、不云同步、不调用真实模型、不请求持久相册/定位/通讯录/麦克风/通知。",
    "2. 数据生命周期：用户主动输入/选择 → 设备本地保存 → 可选 AI/同步任务单 → 导出/删除 → 分享包去隐私。",
    "3. 权限升级梯子：先单次选择；只有批量整理、同步、提醒等明确动作出现时才解释并请求更多权限。",
    "4. 影像边界：照片/视频是记忆锚点；不扫全库、不做人脸识别、不读 EXIF/GPS 推断地点。",
    "5. AI 边界：DeepSeek V4 Flash 仍是 PoC；真实生产需供应商审查、最小字段、预算、失败降级、撤销和缓存删除。",
    "6. 用户权利：导出、删除、清除缩略图、撤销 AI 草稿、暂停同步、退订取回已有记忆，必须是一等能力。",
    "7. 未成年/家庭影像：默认更谨慎；公开分享不带原图、人名、地点、原文和原始影像。",
    "8. 仍待生产完成：正式隐私政策、用户协议、DPA/供应商条款、地区数据边界、App Store 隐私标签和法务复核。"
  ].join("\n");
  try {
    if (!navigator.clipboard) throw new Error("clipboard unavailable");
    await navigator.clipboard.writeText(text);
    setState({ lastComplianceReportAt: new Date().toLocaleString("zh-CN"), toast: "生产隐私报告已复制，可发给试用者、审核者或未来法务。" });
  } catch {
    setState({ toast: "浏览器不允许自动复制；请直接查看生产隐私中心。" });
  }
}

function qaSnapshot() {
  const mediaCount = mediaMoments().length;
  const claimedCount = state.weeklyClaimed.filter(id => state.moments.some(moment => moment.id === id)).length;
  return {
    version: "v32",
    publicUrl: PUBLIC_DEMO_URL,
    resources: "styles.css?v=32 / app.js?v=32",
    moments: state.moments.length,
    mediaCount,
    claimedCount,
    gatewayStatus: gatewayStatusLabel(),
    privacyCenter: "v32",
    qaReportAt: state.lastQaReportAt || "尚未复制",
    checks: qaChecks(mediaCount, claimedCount)
  };
}

function qaChecks(mediaCount = mediaMoments().length, claimedCount = state.weeklyClaimed.length) {
  return [
    {
      area: "首次体验",
      status: "pass",
      route: "onboarding → 此刻",
      evidence: "可从照片/视频或一句话开始；推荐路线覆盖切片、章节、旷野、媒体、隐私。"
    },
    {
      area: "Quick Mark",
      status: state.moments.length ? "pass" : "warn",
      route: "切片",
      evidence: `${state.moments.length} 张切片在本地保险箱；信息稀少/时间冲突/照片占位有门禁。`
    },
    {
      area: "影像锚点",
      status: mediaCount ? "pass" : "warn",
      route: "Memory Camera / 切片 / 章节 / 媒体墙",
      evidence: `${mediaCount} 个切片已绑定照片/视频/链接；v32 保留顶部 Dock、底部悬浮 Memory Camera、此刻页 CTA、Quick Mark 和旧切片补影像主路径。`
    },
    {
      area: "影像入口可见性",
      status: "pass",
      route: "顶部 Dock / 底部 Memory Camera → 今日切片",
      evidence: "用户不必先写文字：点击底部“＋ 影像”或任意“照片/视频”入口即可选择文件并进入今日切片，文字和备注可后补。"
    },
    {
      area: "媒体保险箱",
      status: "pass",
      route: "媒体库生产",
      evidence: "v24 已演示有限相册说明、E2EE 分层、缩略图清除、导出包、删除审计和家庭/儿童影像复核。"
    },
    {
      area: "安装体验",
      status: "poc",
      route: "安装中心",
      evidence: "v32 保留 inline manifest、Apple web app meta、touch icon、安装中心、standalone 检测和可复制安装说明；仍无 service worker/offline。"
    },
    {
      area: "账户权利中心",
      status: "poc",
      route: "账户",
      evidence: "v27-v32 保留访客通行证、恢复钥匙、设备复核、退订取回窗口和可复制账户权利报告；真实登录/E2EE 仍待接入。"
    },
    {
      area: "周章节",
      status: claimedCount >= 3 ? "pass" : "warn",
      route: "章节",
      evidence: `${claimedCount} 个瞬间已认领；章节草稿保留 source 追溯。`
    },
    {
      area: "90 天回忆",
      status: "pass",
      route: "回忆仪式",
      evidence: "先自由回忆，再揭开季度风景；区分主动想起与线索唤回。"
    },
    {
      area: "视觉分享",
      status: "pass",
      route: "分享工作室",
      evidence: "周章节、季度回忆、人生旷野均可本地生成 PNG；公开版隐藏原始影像和具体隐私。"
    },
    {
      area: "AI 网关",
      status: "poc",
      route: "AI",
      evidence: "DeepSeek PoC 仍为假面；provider、预算、队列、授权、降级、撤销可演示。"
    },
    {
      area: "生产隐私",
      status: "poc",
      route: "审核中心",
      evidence: "数据生命周期、权限升级梯子、处理边界和可复制隐私报告已产品化；正式法务文本未完成。"
    },
    {
      area: "上架就绪中心",
      status: "poc",
      route: "Launch",
      evidence: "v32 新增 Launch Readiness：预检账本、导出包 checksum、删除回执、App Store 审核包和可复制上线报告。"
    },
    {
      area: "移动端视觉质感",
      status: "pass",
      route: "此刻 / 切片 / 底部导航",
      evidence: "v32 校准按钮层级、柔和阴影、卡片表面、触控反馈、底部导航和 Memory Camera FAB 位置，让影像入口显眼但不再遮挡主要内容。"
    },
    {
      area: "顶级 App DNA",
      status: "pass",
      route: "此刻 Bento / 媒体记忆墙",
      evidence: "v32 吸收 Day One / Diarly 的 Journal 时间轴、照片墙与地图切换，以及 Craft / Apple Journal 的 Bento 卡片结构；不是普通列表堆功能。"
    },
    {
      area: "原生移交账本",
      status: "poc",
      route: "Launch → Native Handoff",
      evidence: "v32 新增 Native Handoff Ledger，把 SwiftUI 壳、PhotosPicker、Keychain/E2EE、DeepSeek 网关、App Privacy Details、Privacy Manifest、required reason API 和 TestFlight 包拆成可复制施工项。"
    },
    {
      area: "原生上架",
      status: "todo",
      route: "生产待做",
      evidence: "真实 App Store 原生壳、原生权限弹窗、正式图标资产、真实账户、E2EE 与真实 API 仍待做。"
    }
  ];
}

function qaScore() {
  const checks = qaChecks();
  const pass = checks.filter(item => item.status === "pass").length;
  const poc = checks.filter(item => item.status === "poc").length;
  const todo = checks.filter(item => item.status === "todo").length;
  const warn = checks.filter(item => item.status === "warn").length;
  return { total: checks.length, pass, poc, todo, warn };
}

async function copyQaReport() {
  const snapshot = qaSnapshot();
  const text = [
    "TimeSlowDown Demo QA Console（v32）：",
    `公网：${snapshot.publicUrl}`,
    `资源：${snapshot.resources}`,
    `本地样本：${snapshot.moments} 张切片 / ${snapshot.mediaCount} 个影像锚点 / ${snapshot.claimedCount} 个周认领`,
    "",
    ...snapshot.checks.map((item, index) => `${index + 1}. [${item.status.toUpperCase()}] ${item.area} — ${item.route} — ${item.evidence}`),
    "",
    "说明：PASS 表示当前 Web Demo 可点击验证；POC 表示产品假面/边界已产品化但真实生产能力未接入；TODO 表示上架前仍需实现。"
  ].join("\n");
  const stamp = new Date().toLocaleString("zh-CN");
  try {
    if (!navigator.clipboard) throw new Error("clipboard unavailable");
    await navigator.clipboard.writeText(text);
    setState({ lastQaReportAt: stamp, toast: "Demo QA 报告已复制，可发给测试者或其他 agent。" });
  } catch {
    setState({ lastQaReportAt: stamp, toast: "浏览器不允许自动复制；已在 QA Console 中生成报告。" });
  }
}

function simulateAiTask() {
  setState({
    lastAiTaskAt: new Date().toLocaleString("zh-CN"),
    aiDraftRevokedAt: "",
    toast: "已模拟一次 AI 周章节任务：仅发送 3 个被认领切片的最小摘要，失败会退回本地模板。"
  });
}

function revokeAiDraft() {
  setState({
    aiDraftRevokedAt: new Date().toLocaleString("zh-CN"),
    toast: "AI 草稿已撤销。原始切片仍在本机，章节会回到用户可编辑状态。"
  });
}

function gatewaySnapshot() {
  const sheet = aiTaskSheet();
  const queue = [
    { id: "compile-week", label: "周章节编译", route: sheet.route, risk: "低", status: state.gatewayStatus === "sent" ? "已模拟发送" : "待授权" },
    { id: "quarter-recall", label: "90 天回忆候选", route: "L0→L2 可选", risk: "中", status: state.quarterRevealed ? "可排队" : "等待用户揭开季度风景" },
    { id: "media-caption", label: "影像备注整理", route: "L0 默认", risk: "高", status: "需单独授权看图" }
  ];
  return {
    provider: "DeepSeek V4 Flash",
    region: "PoC · 真实生产需供应商审查",
    status: state.gatewayStatus,
    budgetCap: 30,
    budgetUsed: state.gatewayBudgetCents || 0,
    queue,
    ledger: [
      ["最近授权", state.gatewayConsentAt || "尚未授权"],
      ["最近模拟发送", state.lastAiTaskAt || "尚未发送"],
      ["最近降级", state.gatewayFallbackAt || "尚未触发"],
      ["最近撤销", state.gatewayRevokedAt || state.aiDraftRevokedAt || "尚未撤销"]
    ]
  };
}

function simulateGatewayTask() {
  const now = new Date().toLocaleString("zh-CN");
  setState({
    aiMode: "deepseek",
    gatewayStatus: "sent",
    gatewayConsentAt: state.gatewayConsentAt || now,
    lastAiTaskAt: now,
    gatewayBudgetCents: Math.min(30, (state.gatewayBudgetCents || 0) + 4),
    aiDraftRevokedAt: "",
    toast: "已模拟 DeepSeek V4 Flash 网关任务：只发送任务单允许字段，并记录预算。"
  });
}

function simulateGatewayFallback() {
  const now = new Date().toLocaleString("zh-CN");
  setState({
    aiMode: "rules",
    gatewayStatus: "fallback",
    gatewayFallbackAt: now,
    toast: "已模拟模型不可用：任务退回 L0 本地规则层，记录不中断。"
  });
}

function revokeGatewayConsent() {
  const now = new Date().toLocaleString("zh-CN");
  setState({
    aiMode: "rules",
    gatewayStatus: "revoked",
    gatewayRevokedAt: now,
    aiDraftRevokedAt: now,
    toast: "已撤销本次模型授权。后续编译回到本地规则层，原始切片仍可导出/删除。"
  });
}

async function copyAiTaskSheet() {
  const sheet = aiTaskSheet();
  const text = [
    "TimeSlowDown AI 任务单（Demo 模拟）：",
    `任务：${sheet.title}`,
    `目的：${sheet.purpose}`,
    `模型路径：${sheet.route}`,
    `允许发送：${sheet.allowed.join("；")}`,
    `禁止发送：${sheet.blocked.join("；")}`,
    `失败降级：${sheet.fallback}`,
    `用户权利：${sheet.rights.join("；")}`
  ].join("\n");
  try {
    if (!navigator.clipboard) throw new Error("clipboard unavailable");
    await navigator.clipboard.writeText(text);
    setState({ toast: "AI 任务单已复制：它说明了本次任务会发什么、不发什么。" });
  } catch {
    setState({ toast: "浏览器不允许自动复制；请直接查看 AI 任务单。" });
  }
}

async function copyGatewayReport() {
  const gateway = gatewaySnapshot();
  const text = [
    "TimeSlowDown 模型网关报告（Demo 模拟）：",
    `Provider：${gateway.provider}`,
    `状态：${gateway.status}`,
    `预算：${gateway.budgetUsed}/${gateway.budgetCap} cents`,
    "队列：",
    ...gateway.queue.map(item => `- ${item.label}｜${item.route}｜风险:${item.risk}｜${item.status}`),
    "审计：",
    ...gateway.ledger.map(([key, value]) => `- ${key}: ${value}`),
    "边界：当前公网 Demo 不调用真实模型；生产版需供应商审查、最小字段、撤销、导出删除和地区数据边界。"
  ].join("\n");
  try {
    if (!navigator.clipboard) throw new Error("clipboard unavailable");
    await navigator.clipboard.writeText(text);
    setState({ toast: "模型网关报告已复制，可发给 agent、审核者或未来后端实现者。" });
  } catch {
    setState({ toast: "浏览器不允许自动复制；请直接查看模型网关控制台。" });
  }
}

function futureDate(days) {
  const date = new Date();
  date.setDate(date.getDate() + days);
  return date.toLocaleDateString("zh-CN");
}

function simulateEncryptedBackup() {
  setState({
    accountMode: "signed-in-demo",
    syncMode: "encrypted-backup",
    subscriptionState: "plus-demo",
    connectedDevices: Math.max(2, state.connectedDevices),
    lastSyncAt: new Date().toLocaleString("zh-CN"),
    syncPausedAt: "",
    recoveryUntil: futureDate(30),
    toast: "已模拟加密备份：2 台设备可见，服务端只保存加密盒，Demo 不上传真实数据。"
  });
}

function createGuestPassDemo() {
  setState({
    accountMode: "pass-demo",
    passCreatedAt: new Date().toLocaleString("zh-CN"),
    toast: "已模拟创建 TSD 通行证：本机记录不需要登录，通行证只用于未来加密备份和恢复。"
  });
}

function generateRecoveryKeyDemo() {
  setState({
    accountMode: state.accountMode === "guest" ? "pass-demo" : state.accountMode,
    recoveryKeyCreatedAt: new Date().toLocaleString("zh-CN"),
    recoveryUntil: futureDate(30),
    toast: "已模拟生成恢复钥匙：生产版应让用户离线保存，服务端不应持有明文密钥。"
  });
}

function reviewDevicesDemo() {
  setState({
    connectedDevices: Math.max(2, state.connectedDevices),
    deviceReviewAt: new Date().toLocaleString("zh-CN"),
    toast: "已模拟设备复核：生产版应展示设备名、最后活动时间、移除入口和同步状态。"
  });
}

async function copyAccountRightsReport() {
  const text = [
    "TimeSlowDown 账户权利报告（Demo v32）：",
    `账户模式：${accountModeLabel()}`,
    `同步状态：${syncModeLabel()}`,
    `订阅状态：${subscriptionLabel()}`,
    `设备数：${state.connectedDevices}`,
    `通行证创建：${state.passCreatedAt || "尚未创建"}`,
    `恢复钥匙：${state.recoveryKeyCreatedAt || "尚未生成"}`,
    `最近设备复核：${state.deviceReviewAt || "尚未复核"}`,
    `取回窗口：${state.recoveryUntil || "未开启"}`,
    "",
    "产品承诺：",
    "1. 不登录也能记录，访客模式不是残缺试用。",
    "2. 登录只用于加密备份、多设备和恢复，不作为记录门槛。",
    "3. 退订后已有记忆仍可查看、编辑、导出和删除。",
    "4. 恢复钥匙应由用户掌握，服务端不持有明文密钥。",
    "5. 设备列表、暂停同步、删除和导出必须是一级入口。"
  ].join("\n");
  const stamp = new Date().toLocaleString("zh-CN");
  try {
    if (!navigator.clipboard) throw new Error("clipboard unavailable");
    await navigator.clipboard.writeText(text);
    setState({ accountReportCopiedAt: stamp, toast: "账户权利报告已复制，可发给测试者或未来后端/法务。" });
  } catch {
    setState({ accountReportCopiedAt: stamp, toast: "浏览器不允许自动复制；已在账户权利中心生成报告内容。" });
  }
}

function pauseSync() {
  setState({
    syncMode: "paused",
    syncPausedAt: new Date().toLocaleString("zh-CN"),
    toast: "同步已暂停。你仍可在本机记录、查看和导出已有记忆。"
  });
}

function resumeSync() {
  setState({
    syncMode: state.accountMode === "guest" ? "local" : "encrypted-backup",
    lastSyncAt: state.accountMode === "guest" ? state.lastSyncAt : new Date().toLocaleString("zh-CN"),
    syncPausedAt: "",
    toast: state.accountMode === "guest" ? "当前仍是访客模式：记录保存在本机。" : "已恢复加密同步演示。"
  });
}

function cancelSubscriptionDemo() {
  setState({
    subscriptionState: "cancelled-demo",
    syncMode: "paused",
    syncPausedAt: new Date().toLocaleString("zh-CN"),
    recoveryUntil: futureDate(30),
    toast: "已模拟退订：已有记忆仍可查看、编辑、导出；云同步进入 30 天取回窗口。"
  });
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
  $$("[data-studio-copy]").forEach(btn => btn.addEventListener("click", copyStudioCard));
  $$("[data-studio-download]").forEach(btn => btn.addEventListener("click", downloadStudioCard));
  $$("[data-studio-share]").forEach(btn => btn.addEventListener("click", shareStudioCard));
  $("[data-copy-demo-link]")?.addEventListener("click", copyDemoLink);
  $$("[data-install-app]").forEach(btn => btn.addEventListener("click", requestInstallDemo));
  $$("[data-copy-install]").forEach(btn => btn.addEventListener("click", copyInstallGuide));
  $$("[data-check-app-shell]").forEach(btn => btn.addEventListener("click", checkAppShell));
  $("[data-copy-privacy]")?.addEventListener("click", copyPrivacySummary);
  $("[data-copy-review]")?.addEventListener("click", copyReviewPacket);
  $("[data-copy-compliance]")?.addEventListener("click", copyComplianceReport);
  $("[data-copy-qa]")?.addEventListener("click", copyQaReport);
  $$("[data-copy-media-library]").forEach(btn => btn.addEventListener("click", copyMediaLibraryReport));
  $$("[data-delete-media-library]").forEach(btn => btn.addEventListener("click", simulateMediaDelete));
  $$("[data-share-media-library]").forEach(btn => btn.addEventListener("click", shareMediaLibraryDemo));
  $$("[data-media-permission-review]").forEach(btn => btn.addEventListener("click", simulatePermissionReview));
  $$("[data-seal-media-vault]").forEach(btn => btn.addEventListener("click", sealMediaVaultDemo));
  $$("[data-purge-media-thumbnails]").forEach(btn => btn.addEventListener("click", purgeMediaThumbnailsDemo));
  $$("[data-family-media-review]").forEach(btn => btn.addEventListener("click", markFamilyMediaReview));
  $$("[data-export-media-package]").forEach(btn => btn.addEventListener("click", exportMediaPackageDemo));
  $$("[data-simulate-ai-task]").forEach(btn => btn.addEventListener("click", simulateAiTask));
  $$("[data-revoke-ai-draft]").forEach(btn => btn.addEventListener("click", revokeAiDraft));
  $$("[data-copy-ai-task]").forEach(btn => btn.addEventListener("click", copyAiTaskSheet));
  $$("[data-gateway-run]").forEach(btn => btn.addEventListener("click", simulateGatewayTask));
  $$("[data-gateway-fallback]").forEach(btn => btn.addEventListener("click", simulateGatewayFallback));
  $$("[data-gateway-revoke]").forEach(btn => btn.addEventListener("click", revokeGatewayConsent));
  $$("[data-copy-gateway]").forEach(btn => btn.addEventListener("click", copyGatewayReport));
  $$("[data-launch-preflight]").forEach(btn => btn.addEventListener("click", runLaunchPreflight));
  $$("[data-launch-checksum]").forEach(btn => btn.addEventListener("click", verifyLaunchExport));
  $$("[data-launch-delete-receipt]").forEach(btn => btn.addEventListener("click", issueDeletionReceipt));
  $$("[data-launch-store-review]").forEach(btn => btn.addEventListener("click", markStoreReviewPacket));
  $$("[data-copy-launch]").forEach(btn => btn.addEventListener("click", copyLaunchReport));
  $$("[data-native-review]").forEach(btn => btn.addEventListener("click", markNativeMigrationReview));
  $$("[data-privacy-manifest-audit]").forEach(btn => btn.addEventListener("click", markPrivacyManifestAudit));
  $$("[data-copy-native-handoff]").forEach(btn => btn.addEventListener("click", copyNativeHandoffReport));
  $$("[data-create-pass]").forEach(btn => btn.addEventListener("click", createGuestPassDemo));
  $$("[data-generate-recovery]").forEach(btn => btn.addEventListener("click", generateRecoveryKeyDemo));
  $$("[data-review-devices]").forEach(btn => btn.addEventListener("click", reviewDevicesDemo));
  $$("[data-copy-account-rights]").forEach(btn => btn.addEventListener("click", copyAccountRightsReport));
  $$("[data-simulate-backup]").forEach(btn => btn.addEventListener("click", simulateEncryptedBackup));
  $$("[data-pause-sync]").forEach(btn => btn.addEventListener("click", pauseSync));
  $$("[data-resume-sync]").forEach(btn => btn.addEventListener("click", resumeSync));
  $$("[data-cancel-subscription]").forEach(btn => btn.addEventListener("click", cancelSubscriptionDemo));
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
  $$("[data-media-filter]").forEach(btn => btn.addEventListener("click", () => setState({ mediaFilter: btn.dataset.mediaFilter })));
  $$("[data-media-layout]").forEach(btn => btn.addEventListener("click", () => setState({ mediaLayout: btn.dataset.mediaLayout })));
  $$("[data-attach-media-link]").forEach(btn => btn.addEventListener("click", () => attachMediaLinkToMoment(btn.dataset.attachMediaLink)));
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
  $$("[data-media-file]").forEach(input => input.addEventListener("change", handleMediaFile));
  $("[data-demo-media]")?.addEventListener("click", useDemoMedia);
  $("[data-clear-media]")?.addEventListener("click", clearMediaDraft);
  const mediaUrl = $("[data-media-url]");
  mediaUrl?.addEventListener("input", e => {
    state.mediaDraftUrl = e.target.value;
    state.mediaDraft = null;
    saveState();
  });
  const mediaNote = $("[data-media-note]");
  mediaNote?.addEventListener("input", e => {
    state.mediaDraftNote = e.target.value;
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
        ${state.onboarded ? mediaDock() : ""}
        <div class="screen-body">${content}</div>
        ${state.onboarded ? memoryCameraFab() : ""}
        ${bottomNav()}
      </div>
    </div>
    ${sidePanel()}
  </div>`;
}

function mediaDock() {
  return `<div class="media-dock" aria-label="快速添加照片或视频">
    <div class="media-dock-copy">
      <strong>Memory Camera</strong>
      <span>拍了照片？先钉到今天；文字、人物和地点都可以以后补。</span>
    </div>
    <label class="media-dock-button">
      <span>添加照片/视频</span>
      <input data-media-file data-after-view="slice" type="file" accept="image/*,video/*" />
    </label>
  </div>`;
}

function memoryCameraFab() {
  if (["slice", "media", "library", "launch", "qa", "review", "install", "account", "ai", "settings"].includes(state.view)) return "";
  return `<label class="memory-camera-fab" aria-label="添加照片或视频到今日切片">
    <span class="camera-mark">＋</span>
    <span class="camera-copy"><strong>影像</strong><em>先占位</em></span>
    <input data-media-file data-after-view="slice" type="file" accept="image/*,video/*" />
  </label>`;
}

function mainTemplate() {
  const views = { now: nowView, slice: sliceView, meadow: meadowView, media: mediaView, lens: lensView, library: mediaLibraryView, chapter: chapterView, ritual: ritualView, guide: guideView, studio: studioView, review: reviewView, qa: qaView, install: installView, launch: launchView, account: accountView, ai: aiView, settings: settingsView };
  return shell((views[state.view] || nowView)());
}

function onboardingTemplate() {
  return shell(`
    <div class="onboarding">
      <div>
        <div class="eyebrow">Time Slow Down</div>
        <h1 class="onboard-title">不是活一辈子，<br/>而是活几个瞬间。</h1>
        <p class="onboard-copy">TSD 帮你把日复一日里真正不同的地方留下。可以从一张照片、一段视频或一句话开始；影像不是附件，而是回忆的锚点。</p>
      </div>
      <div class="onboard-art">
        <div class="meadow" style="position:absolute;left:16px;right:16px;bottom:16px"></div>
        <div class="floating-card">
          <div class="eyebrow">90 天后</div>
          <strong>你能讲出 5–10 个鲜明瞬间</strong>
          <p class="micro">不是靠连续打卡，而是靠被你认领过的切片。</p>
        </div>
      </div>
      <section class="media-first-strip">
        <div>
          <div class="eyebrow">Photo / Video First</div>
          <strong>先选一张照片，文字可以以后再补。</strong>
          <span>选择后会直接进入今日切片：照片/视频会和这一天绑定，成为以后唤回现场的影像线索。</span>
        </div>
        <label class="media-first-button">
          <span>从照片/视频开始</span>
          <input data-media-file data-onboard-media="true" data-after-view="slice" data-clear-draft="true" type="file" accept="image/*,video/*" />
        </label>
      </section>
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
      <p class="hero-subtitle">不需要完整日记。可以先拍下/选中一个画面，再补一句话；影像本身就是回忆的入口。</p>
      <div class="action-row">
        <label class="primary media-inline-file">
          <span>添加照片/视频</span>
          <input data-media-file data-after-view="slice" data-clear-draft="true" type="file" accept="image/*,video/*" />
        </label>
        <button class="secondary" data-view="slice">文字 Quick Mark</button>
        <button class="secondary" data-view="media">看媒体记忆墙</button>
      </div>
      <p class="media-dock-note">如果你已经拍了照片，不用先想文字：点上方“照片/视频”，TSD 会把它作为今日切片的记忆锚点。</p>
    </section>
    <section class="bento-board" aria-label="今日 Bento 记忆工作台">
      ${bentoCard("capture", "Memory Camera", "先把现场钉住", "照片/视频优先，文字以后补。", "添加照片/视频", "slice")}
      ${bentoCard("timeline", "Journal Timeline", `${mediaMoments().length} 个影像锚点`, "按时间重新走一遍最近的瞬间。", "看时间线", "media")}
      ${bentoCard("chapter", "Weekly Story", "认领 3 个瞬间", "把零散切片编成能讲给人的章节。", "编译章节", "chapter")}
      ${bentoCard("meadow", "Life Meadow", "月、年、一生缩放", "让花丛、小草和雨天一起构成人生。", "缩放旷野", "meadow")}
    </section>
    <section class="media-first-strip">
      <div>
        <div class="eyebrow">Photo / Video First</div>
        <strong>用照片或视频，先把这一刻钉住。</strong>
        <span>选完会进入今日切片：可以只留影像备注，也可以周末再补完整故事。</span>
      </div>
      <label class="media-first-button">
        <span>选择照片/视频</span>
        <input data-media-file data-after-view="slice" data-clear-draft="true" type="file" accept="image/*,video/*" />
      </label>
    </section>
    <div class="radar">
      ${radarItem("第一次", "任何第一次都值得先占位，不必先判断它重不重要。", "✦")}
      ${radarItem("人", "今天有没有一个人，比平时更清晰？", "♙")}
      ${radarItem("影像", "照片、视频、截图、录音备注，都可以成为切片的第一线索。", "▧")}
    </div>
    <section class="journey-card">
      <div class="eyebrow">Try This Demo</div>
      <h2 class="section-title">推荐体验路线 <span class="micro">3 分钟</span></h2>
      <div class="journey-steps">
        ${journeyStep("01", "留下一张切片", "用照片/视频或一句话，先占住今天不同的地方。", "slice")}
        ${journeyStep("02", "编译本周章节", "认领 3 个瞬间，生成可编辑故事。", "chapter")}
        ${journeyStep("03", "缩放人生旷野", "从月度风景缩到一生周格。", "meadow")}
        ${journeyStep("04", "打开媒体记忆墙", "看照片、视频如何把切片串成时间线。", "media")}
        ${journeyStep("05", "打开人物地点镜头", "从谁和哪里，重新讲起最近的瞬间。", "lens")}
        ${journeyStep("06", "检查媒体库边界", "看相册权限、加密库、导出删除和分享。", "library")}
        ${journeyStep("07", "试一次 90 天回忆", "先自由回忆，再揭开季度风景。", "ritual")}
        ${journeyStep("08", "生成视觉成品", "把周章节、季度回忆和人生旷野变成可分享卡片。", "studio")}
      </div>
    </section>
  `;
}

function bentoCard(kind, label, title, copy, action, view) {
  return `<button class="bento-card ${kind}" data-view="${view}">
    <span>${label}</span>
    <strong>${title}</strong>
    <em>${copy}</em>
    <small>${action} ›</small>
  </button>`;
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
  const tags = ["第一次", "人", "地点", "情绪转弯", "成就", "照片", "视频", "普通但值得", "低落也算"];
  return `
    <div class="topline"><div><div class="brand">今日切片</div><div class="micro">5–15 秒先占位，周末再慢慢补全。</div></div></div>
    <section class="quick-panel">
      <h2 class="section-title">Quick Mark <span class="micro">${state.aiMode === "rules" ? "L0 规则层" : "DeepSeek PoC 草稿"}</span></h2>
      <div class="media-capture">
        <div class="media-capture-head">
          <div><strong>影像线索</strong><span>可以先选照片/视频，再写一句；影像不是附件，是这张切片的记忆锚点。</span></div>
          <button class="secondary small" data-demo-media>试一张照片</button>
        </div>
        <label class="media-file">
          <span>选择照片/视频</span>
          <input data-media-file type="file" accept="image/*,video/*" />
        </label>
        <input class="media-url-input" data-media-url value="${escapeHtml(state.mediaDraftUrl)}" placeholder="或粘贴照片/视频链接，例如 iCloud/相册分享/公开视频链接" />
        <textarea class="media-note-input" data-media-note rows="2" placeholder="这张影像为什么值得留下？">${escapeHtml(state.mediaDraftNote)}</textarea>
        ${mediaDraftPreview()}
      </div>
      <textarea class="text-input" data-draft placeholder="可选：写一句今天想留下的事。没想好也可以先用影像占位。">${escapeHtml(state.draft)}</textarea>
      <div class="quick-tags">
        ${tags.map(t => `<button class="tag ${state.activeTags.includes(t) ? "active" : ""}" data-tag="${t}">${t}</button>`).join("")}
      </div>
      <div class="action-row"><button class="primary" data-add>生成今日切片</button><button class="secondary" data-ai-mode>${state.aiMode === "rules" ? "切到 DeepSeek PoC" : "切回规则层"}</button></div>
      <p class="source-line">免费版永远可用：模型不可用时，TSD 会退回朴素模板；影像默认本地优先，生产版才接相册权限、加密存储和可选同步。</p>
    </section>
    ${latestSliceCard()}
  `;
}

function mediaDraftPreview() {
  const media = normalizeMediaDraft();
  if (!media) {
    return `<div class="media-empty"><span>还没有影像线索</span><em>可以从照片/视频开始，也可以只写一句话。TSD 不要求你当场写完整日记。</em></div>`;
  }
  return `<div class="media-preview">
    ${media.previewUrl ? `<img src="${media.previewUrl}" alt="本地照片预览" />` : `<div class="media-thumb">${media.kind === "video" ? "▶" : media.kind === "image" ? "▧" : "↗"}</div>`}
    <div>
      <strong>${mediaKindLabel(media.kind)} · ${escapeHtml(media.label || "未命名影像")}</strong>
      <span>${escapeHtml(media.note || "还没写影像备注。")}</span>
      <em>${media.storage === "external-link" ? "外部链接" : `本地 Demo · ${formatBytes(media.size)}`}</em>
    </div>
    <button class="ghost danger" data-clear-media>移除</button>
  </div>`;
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
    ${mediaBlock(m.media)}
    ${mediaAttachActions(m)}
    <div class="slice-meta">${m.tags.map(t => `<span class="meta">${escapeHtml(t)}</span>`).join("")}</div>
    ${gateBadges(m.gates)}
    <div class="source-line">来源：${m.sources.join(" · ")}。无来源的漂亮句子不会进入最终故事。</div>
  </section>`;
}

function mediaBlock(media) {
  if (!media) return "";
  return `<div class="media-memory">
    ${media.previewUrl ? `<img src="${media.previewUrl}" alt="切片影像预览" />` : `<div class="media-thumb">${media.kind === "video" ? "▶" : media.kind === "image" ? "▧" : "↗"}</div>`}
    <div>
      <strong>${mediaKindLabel(media.kind)}锚点：${escapeHtml(media.label || "未命名影像")}</strong>
      <span>${escapeHtml(media.note || "这条影像已经和切片绑定。")}</span>
      <em>${media.storage === "external-link" ? "外部链接 · 用户提供" : `本地 Demo 元信息 · ${formatBytes(media.size)}`}</em>
    </div>
  </div>`;
}

function mediaAttachActions(moment, compact = false) {
  const hasMedia = Boolean(moment.media);
  return `<div class="media-attach ${compact ? "compact" : ""}">
    <label class="media-attach-button">
      <span>${hasMedia ? "更换照片/视频" : "补照片/视频"}</span>
      <input data-media-file data-attach-moment="${escapeHtml(moment.id)}" type="file" accept="image/*,video/*" />
    </label>
    <button class="ghost small" data-attach-media-link="${escapeHtml(moment.id)}">粘贴影像链接</button>
  </div>`;
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
      <div class="action-row"><button class="secondary" data-view="media">打开媒体记忆墙</button><button class="secondary" data-view="lens">人物与地点镜头</button></div>
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
      <span>这个月开始了什么、结束了什么、悄悄改变了什么？影像层能帮你从照片和视频找回入口。</span>
      <button class="secondary" data-view="ritual">进入月度 / 季度仪式</button>
      <button class="secondary" data-view="media">查看媒体记忆墙</button>
      <button class="secondary" data-view="lens">人物与地点镜头</button>
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

function mediaView() {
  const stats = mediaStats();
  const items = filteredMediaMoments();
  const layout = state.mediaLayout || "timeline";
  return `
    <div class="topline"><div><div class="brand">媒体记忆墙</div><div class="micro">照片和视频不是附件，它们是能把回忆带回来的光。</div></div></div>
    <section class="guide-card media-hero">
      <div class="eyebrow">Media Memory Wall · v32</div>
      <h1 class="hero-title">影像让时间，<br/>重新有了入口。</h1>
      <p class="hero-subtitle">这里不是普通相册。TSD 只展示已经绑定到切片的照片/视频线索：它们有时间、有一句话、有来源，也能回到章节和人生旷野。</p>
      <div class="media-stats">
        ${mediaStat("影像", stats.total, "个")}
        ${mediaStat("照片", stats.image, "张")}
        ${mediaStat("视频", stats.video, "段")}
        ${mediaStat("链接", stats.link, "条")}
      </div>
      <div class="action-row">
        <label class="primary media-inline-file">
          <span>直接选择照片/视频</span>
          <input data-media-file data-after-view="slice" type="file" accept="image/*,video/*" />
        </label>
        <button class="secondary" data-view="slice">写一句切片</button>
        <button class="secondary" data-view="lens">人物地点镜头</button>
        <button class="secondary" data-view="library">媒体库生产</button>
        <button class="secondary" data-view="chapter">回到周章节</button>
      </div>
      ${state.toast ? `<p class="toast">${state.toast}</p>` : ""}
    </section>
    <section class="guide-card">
      <h2 class="section-title">影像筛选 <span class="micro">${items.length} 条 · ${mediaLayoutLabel(layout)}</span></h2>
      <div class="media-layout-switch" aria-label="媒体视图切换">
        ${mediaLayoutButton("timeline", "时间轴")}
        ${mediaLayoutButton("grid", "照片墙")}
        ${mediaLayoutButton("map", "地图")}
      </div>
      <div class="media-filter-row">
        ${mediaFilterButton("all", "全部")}
        ${mediaFilterButton("image", "照片")}
        ${mediaFilterButton("video", "视频")}
        ${mediaFilterButton("link", "链接")}
      </div>
      ${mediaLayoutView(items, layout)}
    </section>
    <section class="guide-card">
      <h2 class="section-title">生产边界 <span class="micro">不是普通云相册</span></h2>
      <div class="chapter-list">
        <div class="chapter-line"><strong>只展示被用户绑定过的影像</strong><span>TSD 不自动扫相册、不替用户判断哪张照片重要。影像必须和切片、备注或章节发生关系。</span></div>
        <div class="chapter-line"><strong>原始影像权利属于用户</strong><span>生产版需要原图/视频导出、删除、仅设备保存、E2EE 同步和缩略图边界。</span></div>
        <div class="chapter-line"><strong>AI 不默认看图</strong><span>没有用户授权和任务单，模型不能读取原始影像；最多先处理用户写下的影像备注和最小元信息。</span></div>
      </div>
      <div class="action-row"><button class="secondary" data-view="library">媒体库生产假面</button><button class="secondary" data-view="review">查看审核中心</button><button class="secondary" data-view="settings">记忆保险箱</button></div>
    </section>
  `;
}

function mediaLayoutLabel(layout) {
  if (layout === "grid") return "照片墙";
  if (layout === "map") return "地图";
  return "时间轴";
}

function mediaLayoutButton(layout, label) {
  return `<button class="layout-pill ${state.mediaLayout === layout ? "active" : ""}" data-media-layout="${layout}">${label}</button>`;
}

function mediaLayoutView(items, layout) {
  if (!items.length) return emptyMediaWall();
  if (layout === "grid") return `<div class="photo-wall">${items.map(photoWallTile).join("")}</div>`;
  if (layout === "map") return mediaMemoryMap(items);
  return `<div class="journal-timeline">${items.map(journalTimelineCard).join("")}</div>`;
}

function journalTimelineCard(moment, index) {
  const media = moment.media;
  return `<article class="journal-entry">
    <div class="journal-date"><strong>${escapeHtml(moment.date)}</strong><span>${String(index + 1).padStart(2, "0")}</span></div>
    <div class="journal-rail"><i></i></div>
    <div class="journal-card">
      <div class="journal-media ${media.kind}">
        ${media.previewUrl ? `<img src="${media.previewUrl}" alt="${escapeHtml(moment.title)}" />` : `<span>${media.kind === "video" ? "▶" : media.kind === "image" ? "▧" : "↗"}</span>`}
      </div>
      <div class="journal-copy">
        <div class="eyebrow">${mediaKindLabel(media.kind)} · ${moment.tags.slice(0, 2).map(escapeHtml).join(" / ")}</div>
        <h3>${escapeHtml(moment.title)}</h3>
        <p>${escapeHtml(media.note || moment.text)}</p>
        <small>source: ${escapeHtml(moment.id)} · 已绑定切片</small>
      </div>
    </div>
  </article>`;
}

function photoWallTile(moment, index) {
  const media = moment.media;
  return `<button class="photo-tile tile-${index % 4}" data-view="chapter" aria-label="打开 ${escapeHtml(moment.title)} 对应章节">
    <div class="photo-tile-art">
      ${media.previewUrl ? `<img src="${media.previewUrl}" alt="${escapeHtml(moment.title)}" />` : `<span>${media.kind === "video" ? "▶" : media.kind === "image" ? "▧" : "↗"}</span>`}
    </div>
    <div class="photo-tile-copy">
      <small>${escapeHtml(moment.date)}</small>
      <strong>${escapeHtml(moment.title)}</strong>
      <em>${escapeHtml(media.note || moment.text)}</em>
    </div>
  </button>`;
}

function mediaMemoryMap(items) {
  const pins = items.slice(0, 6).map((moment, index) => {
    const positions = [
      [18, 28], [68, 22], [48, 52], [24, 72], [76, 68], [56, 82]
    ];
    const [left, top] = positions[index % positions.length];
    return `<button class="memory-map-pin pin-${index}" style="--left:${left}%;--top:${top}%;" data-view="lens">
      <span>${moment.media.kind === "video" ? "▶" : moment.media.kind === "image" ? "▧" : "↗"}</span>
      <strong>${escapeHtml(moment.title)}</strong>
    </button>`;
  }).join("");
  return `<div class="memory-map">
    <div class="map-road road-a"></div>
    <div class="map-road road-b"></div>
    <div class="map-water"></div>
    ${pins}
    <div class="memory-map-caption"><strong>记忆地图</strong><span>Demo 不读取 GPS；这里只用用户确认的地点线索，进入“人物地点镜头”继续查看。</span></div>
  </div>`;
}

function mediaLibraryView() {
  const stats = mediaLibraryStats();
  return `
    <div class="topline"><div><div class="brand">媒体库生产</div><div class="micro">把照片/视频从 Demo 能力推进到上架前必须说清的边界。</div></div></div>
    <section class="guide-card library-hero">
      <div class="eyebrow">Media Vault Path · v24</div>
      <h1 class="hero-title">不是普通相册，<br/>而是可带走、可删除的记忆库。</h1>
      <p class="hero-subtitle">这里演示生产版媒体层应如何处理：有限相册选择、端到端加密影像库、缩略图、媒体导出包、删除审计、家庭/儿童影像复核和去隐私分享。当前仍是 Web Demo，不请求持久相册权限。</p>
      <div class="library-stats">
        ${libraryStat("影像锚点", stats.total, "个")}
        ${libraryStat("本地文件", stats.local, "个")}
        ${libraryStat("外部链接", stats.external, "条")}
        ${libraryStat("缩略预览", stats.previews, "张")}
      </div>
      <div class="action-row"><button class="primary" data-copy-media-library>复制媒体库清单</button><button class="secondary" data-share-media-library>模拟系统分享</button></div>
      ${state.toast ? `<p class="toast">${state.toast}</p>` : ""}
    </section>
    <section class="guide-card">
      <h2 class="section-title">媒体保险箱状态 <span class="micro">user rights ledger</span></h2>
      <div class="media-vault-dashboard">
        ${vaultStatus("相册权限", state.mediaPermissionReviewAt ? "已解释有限选择" : "单次选择", state.mediaPermissionReviewAt || "尚未复核", "ready")}
        ${vaultStatus("保险箱封存", state.mediaVaultSealedAt ? "已模拟封存" : "待封存", state.mediaVaultSealedAt || "尚未封存", state.mediaVaultSealedAt ? "ready" : "todo")}
        ${vaultStatus("导出包", state.mediaPackageExportAt ? "已生成" : "待生成", state.mediaPackageExportAt || "尚未导出", state.mediaPackageExportAt ? "ready" : "todo")}
        ${vaultStatus("家庭影像", stats.sensitive ? `${stats.sensitive} 个候选` : "暂无候选", state.mediaFamilyReviewAt || "尚未复核", stats.sensitive ? "warn" : "ready")}
      </div>
      <div class="action-row"><button class="secondary" data-media-permission-review>解释相册权限</button><button class="secondary" data-seal-media-vault>模拟封存保险箱</button><button class="secondary" data-export-media-package>生成导出包</button><button class="ghost danger" data-family-media-review>复核家庭影像</button></div>
      <p class="source-line">保险箱状态只写入当前浏览器 Demo；生产版需要真实 E2EE、密钥恢复、删除回执和导出包校验。</p>
    </section>
    <section class="guide-card">
      <h2 class="section-title">权限策略 <span class="micro">Photos Picker first</span></h2>
      <div class="library-flow">
        ${libraryStep("01", "单次/有限选择", "首发不请求完整相册。用户主动选择照片/视频后，TSD 才能把它绑定到切片。", "ready")}
        ${libraryStep("02", "不扫全库", "不自动扫描相册、不做人脸识别、不从 EXIF/GPS 推断地点。", "safe")}
        ${libraryStep("03", "权限升级有理由", "只有当用户明确要批量整理时，才解释为什么需要更多相册访问。", "todo")}
      </div>
    </section>
    <section class="guide-card">
      <h2 class="section-title">加密影像库 <span class="micro">E2EE vault</span></h2>
      <div class="library-vault">
        ${vaultLayer("原始文件", "保留用户可导出的原图/视频；不因订阅状态扣留。", stats.encrypted)}
        ${vaultLayer("缩略图", "设备端生成小预览，用于媒体墙/人物地点镜头；可单独清除。", stats.previews)}
        ${vaultLayer("索引元信息", "只保存用户写下的备注、source、切片 ID 和最小类型信息。", stats.total)}
      </div>
      <div class="media-audit-strip">
        ${auditChip("封存", state.mediaVaultSealedAt || "未封存")}
        ${auditChip("清缩略图", state.mediaThumbnailPurgeAt || "未清除")}
        ${auditChip("删除请求", state.mediaDeleteRequestAt || "未请求")}
      </div>
      <div class="action-row"><button class="secondary" data-seal-media-vault>模拟 E2EE 封存</button><button class="ghost danger" data-purge-media-thumbnails>清除缩略图缓存</button></div>
      <p class="source-line">Demo 只保存小图预览或文件元信息；生产版需要真正的加密文件库、密钥恢复和多设备同步策略。</p>
    </section>
    <section class="guide-card">
      <h2 class="section-title">导出与删除 <span class="micro">用户权利</span></h2>
      <div class="chapter-list">
        <div class="chapter-line"><strong>导出包应包含什么</strong><span>原图/视频、缩略图、切片 JSON、source 追溯和用户可读说明。</span></div>
        <div class="chapter-line"><strong>删除必须删干净</strong><span>删除原始影像时，同步删除缩略图、云副本、任务缓存和分享草稿。</span></div>
        <div class="chapter-line"><strong>退订不能扣留记忆</strong><span>Plus 过期后仍应允许查看、导出和删除已有媒体。</span></div>
      </div>
      <div class="action-row"><button class="secondary" data-copy-media-library>复制导出清单</button><button class="secondary" data-export-media-package>生成媒体导出包</button><button class="ghost danger" data-delete-media-library>模拟删除请求</button></div>
      <p class="source-line">上次媒体导出：${escapeHtml(state.lastMediaExportAt || "尚未导出")}；导出包：${escapeHtml(state.mediaPackageExportAt || "尚未生成")}；上次删除请求：${escapeHtml(state.mediaDeleteRequestAt || "尚未请求")}。</p>
    </section>
    <section class="guide-card">
      <h2 class="section-title">家庭 / 儿童影像 <span class="micro">extra care</span></h2>
      <div class="family-media-card">
        <strong>不靠恐惧提醒用户，但对家庭影像更谨慎。</strong>
        <span>含孩子、家人、医院、住址等线索的媒体，公开分享默认隐藏原图、人名、地点和原文；AI 任务默认只读用户备注，不读原始影像。</span>
        <small>候选数：${stats.sensitive}；上次复核：${escapeHtml(state.mediaFamilyReviewAt || "尚未复核")}。</small>
      </div>
      <div class="action-row"><button class="secondary" data-family-media-review>模拟敏感影像复核</button><button class="secondary" data-view="review">查看生产隐私中心</button></div>
    </section>
    <section class="guide-card">
      <h2 class="section-title">Web Share / 图片导出 <span class="micro">去隐私分享包</span></h2>
      <div class="library-share-grid">
        ${shareBoundary("公开分享", "只分享时间风景和主题，不包含原图、人名、地点和原文。")}
        ${shareBoundary("私密分享", "适合发给亲友，可包含更多故事，但仍需二次确认。")}
        ${shareBoundary("真实图片导出", "分享工作室可生成 PNG 成品；公开版默认去掉原图、人名、地点和原文。")}
      </div>
      <div class="action-row"><button class="primary" data-share-media-library>模拟 Web Share</button><button class="secondary" data-view="studio">打开分享工作室</button></div>
      <p class="source-line">上次分享：${escapeHtml(state.mediaShareAt || "尚未分享")}。当前 Web Demo 只复制文案或调用可用的系统分享；未上传原始影像。</p>
    </section>
  `;
}

function lensView() {
  const people = peopleLens();
  const places = placeLens();
  const timeline = lensTimeline();
  const mediaCount = timeline.filter(item => item.moment.media).length;
  return `
    <div class="topline"><div><div class="brand">人物与地点</div><div class="micro">从谁和哪里，重新走进一段时间。</div></div></div>
    <section class="guide-card lens-hero">
      <div class="eyebrow">People & Place Lens · v17</div>
      <h1 class="hero-title">从人和地点，<br/>重新讲起最近的时间。</h1>
      <p class="hero-subtitle">日期会模糊，但“和爸爸吃面”“那段回家路”“跑完 5 公里的路灯”会把记忆带回来。TSD 只使用你写下或绑定过的词，不读取通讯录、GPS 或相册人脸。</p>
      <div class="lens-stats">
        ${lensStat("人物镜头", people.length, "组")}
        ${lensStat("地点镜头", places.length, "处")}
        ${lensStat("影像线索", mediaCount, "个")}
      </div>
      <div class="action-row"><button class="secondary" data-view="media">回到媒体记忆墙</button><button class="secondary" data-view="chapter">编译周章节</button></div>
    </section>
    <section class="guide-card">
      <h2 class="section-title">人物镜头 <span class="micro">${people.length} 组</span></h2>
      <div class="lens-card-grid">
        ${people.map(item => lensCard(item, "person-lens-card")).join("")}
      </div>
    </section>
    <section class="guide-card">
      <h2 class="section-title">地点镜头 <span class="micro">${places.length} 处</span></h2>
      <div class="lens-card-grid">
        ${places.map(item => lensCard(item, "place-lens-card")).join("")}
      </div>
    </section>
    <section class="guide-card">
      <h2 class="section-title">可讲述线索 <span class="micro">人 / 地点 / 影像</span></h2>
      <div class="lens-timeline">
        ${timeline.map((item, index) => lensTimeRow(item, index)).join("")}
      </div>
    </section>
    <section class="guide-card">
      <h2 class="section-title">生产边界 <span class="micro">镜头不是监控</span></h2>
      <div class="chapter-list">
        <div class="chapter-line"><strong>只用用户留下的词</strong><span>人物和地点来自切片文本、标签和影像备注；不是通讯录、定位轨迹或相册扫描。</span></div>
        <div class="chapter-line"><strong>不做人脸识别</strong><span>生产版若接系统相册，也应先让用户主动绑定影像，再决定是否添加人物/地点标签。</span></div>
        <div class="chapter-line"><strong>目的是帮你讲起回忆</strong><span>这些镜头不是评分、画像或社交关系分析，只是回到记忆的入口。</span></div>
      </div>
    </section>
  `;
}

function lensStat(label, value, unit) {
  return `<div class="lens-stat"><strong>${value}</strong><span>${label} · ${unit}</span></div>`;
}

function lensCard(item, className) {
  const latest = item.moments[0];
  return `<article class="lens-card ${className}">
    <div class="lens-icon">${escapeHtml(item.icon)}</div>
    <div>
      <div class="eyebrow">${item.mediaCount ? `${item.mediaCount} 个影像锚点` : "文字线索"}</div>
      <h3>${escapeHtml(item.label)}</h3>
      <p>${escapeHtml(item.copy)}</p>
      <small>${item.moments.length} 张切片 · 最近：${escapeHtml(latest.date)}《${escapeHtml(latest.title)}》</small>
    </div>
  </article>`;
}

function lensTimeRow(item, index) {
  const media = item.moment.media;
  return `<div class="lens-time-row">
    <span>${String(index + 1).padStart(2, "0")}</span>
    <div>
      <strong>${escapeHtml(item.moment.title)}</strong>
      <em>${escapeHtml(item.person)} · ${escapeHtml(item.place)}${media ? ` · ${mediaKindLabel(media.kind)}锚点` : ""}</em>
      <small>${escapeHtml(item.moment.date)} · source: ${escapeHtml(item.moment.id)}</small>
    </div>
  </div>`;
}

function mediaStat(label, value, unit) {
  return `<div class="media-stat"><strong>${value}</strong><span>${label} · ${unit}</span></div>`;
}

function libraryStat(label, value, unit) {
  return `<div class="library-stat"><strong>${value}</strong><span>${label} · ${unit}</span></div>`;
}

function libraryStep(num, title, copy, tone) {
  return `<div class="library-step ${tone}"><span>${num}</span><strong>${title}</strong><em>${copy}</em></div>`;
}

function vaultLayer(title, copy, count) {
  return `<div class="vault-layer"><strong>${title}<span>${count}</span></strong><em>${copy}</em></div>`;
}

function vaultStatus(title, status, stamp, tone = "ready") {
  return `<div class="vault-status ${tone}"><strong>${title}</strong><span>${status}</span><em>${escapeHtml(stamp)}</em></div>`;
}

function auditChip(label, value) {
  return `<div class="audit-chip"><strong>${label}</strong><span>${escapeHtml(value)}</span></div>`;
}

function shareBoundary(title, copy) {
  return `<div class="share-boundary"><strong>${title}</strong><span>${copy}</span></div>`;
}

function mediaFilterButton(filter, label) {
  return `<button class="tag ${state.mediaFilter === filter ? "active" : ""}" data-media-filter="${filter}">${label}</button>`;
}

function emptyMediaWall() {
  return `<div class="empty-media-wall">
    <strong>这一类暂时没有影像线索</strong>
    <span>可以新建一张影像切片，也可以把照片/视频补到已经存在的切片上。TSD 关心的是影像和哪一个瞬间绑定。</span>
    <div class="action-row"><button class="secondary" data-view="slice">新建影像切片</button><button class="secondary" data-view="chapter">给旧切片补影像</button></div>
  </div>`;
}

function mediaWallCard(moment) {
  const media = moment.media;
  return `<article class="media-wall-card">
    <div class="media-wall-thumb">
      ${media.previewUrl ? `<img src="${media.previewUrl}" alt="${escapeHtml(moment.title)} 影像预览" />` : `<span>${media.kind === "video" ? "▶" : media.kind === "image" ? "▧" : "↗"}</span>`}
    </div>
    <div class="media-wall-copy">
      <div class="eyebrow">${mediaKindLabel(media.kind)} · ${escapeHtml(moment.date)}</div>
      <h3>${escapeHtml(moment.title)}</h3>
      <p>${escapeHtml(media.note || moment.text)}</p>
      <div class="media-wall-tags">
        ${moment.tags.slice(0, 3).map(tag => `<span>${escapeHtml(tag)}</span>`).join("")}
      </div>
      <small>${escapeHtml(media.label || "未命名影像")} · source: ${escapeHtml(moment.id)}</small>
    </div>
  </article>`;
}

function mediaTimeline(items) {
  if (!items.length) return `<div class="media-timeline-empty">没有可展示的影像时间线。</div>`;
  return items.map((moment, index) => {
    const media = moment.media;
    return `<div class="media-time-row">
      <span>${String(index + 1).padStart(2, "0")}</span>
      <div>
        <strong>${escapeHtml(moment.date)} · ${escapeHtml(moment.title)}</strong>
        <em>${mediaKindLabel(media.kind)}锚点：${escapeHtml(media.note || media.label || "已绑定影像线索")}</em>
      </div>
    </div>`;
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
      <div class="action-row"><button class="primary" data-copy-share>复制分享文案</button><button class="secondary" data-view="studio">生成视觉卡</button><button class="secondary" data-view="ai">检查 AI 四道门</button></div>
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

function studioView() {
  const assets = studioAssets();
  return `
    <div class="topline"><div><div class="brand">分享工作室</div><div class="micro">把记录变成可转述、可截图、可分享的视觉成品。</div></div></div>
    <section class="guide-card studio-hero">
      <div class="eyebrow">Visual Share Studio · v20</div>
      <h1 class="hero-title">不是发日记，<br/>是递出一张时间明信片。</h1>
      <p class="hero-subtitle">TSD 的分享不追求炫耀连续打卡，而是把“这一周/这一季/这一片旷野”整理成一个可讲述入口。现在可生成 PNG；公开版隐藏具体人名、地点、原文和原始影像，私密版适合讲给亲友。</p>
      <div class="share-mode studio-mode" aria-label="分享隐私模式">
        <button class="${state.shareMode === "private" ? "active" : ""}" data-share-mode="private">讲给一个人</button>
        <button class="${state.shareMode === "public" ? "active" : ""}" data-share-mode="public">分享一幅风景</button>
      </div>
      <div class="export-status">
        <strong>上次导出</strong>
        <span>${escapeHtml(state.lastStudioExportAt || "尚未导出 PNG")} ${state.lastStudioExportAsset ? `· ${escapeHtml(state.lastStudioExportAsset)}` : ""}</span>
        <strong>上次分享</strong>
        <span>${escapeHtml(state.lastStudioShareAt || "尚未调用分享")}</span>
      </div>
      ${state.toast ? `<p class="toast">${state.toast}</p>` : ""}
    </section>
    <section class="guide-card">
      <h2 class="section-title">成品预览 <span class="micro">${state.shareMode === "public" ? "公开风景" : "私密叙述"}</span></h2>
      <div class="poster-grid">
        ${assets.map(asset => posterCard(asset)).join("")}
      </div>
    </section>
    <section class="guide-card">
      <h2 class="section-title">导出流水线 <span class="micro">PNG / Web Share / fallback</span></h2>
      <div class="export-lab">
        ${exportStep("01", "选择隐私模式", "公开版先去细节，私密版保留更多可讲述性；切换后再导出。")}
        ${exportStep("02", "生成 PNG", "浏览器本地 canvas 生成图片，不上传原始记忆或照片。")}
        ${exportStep("03", "分享或降级", "系统支持时调用分享面板；不支持时复制去隐私文案并保留 PNG 下载。")}
      </div>
    </section>
    <section class="guide-card">
      <h2 class="section-title">分享边界 <span class="micro">产品原则</span></h2>
      <div class="chapter-list">
        <div class="chapter-line"><strong>分享是用户主动行为</strong><span>TSD 不自动发布、不默认公开、不用社交压力逼用户连续记录。</span></div>
        <div class="chapter-line"><strong>公开版先去细节</strong><span>适合朋友圈/小红书/群聊，只展示时间风景和主题，不暴露具体人名、地点、原文。</span></div>
        <div class="chapter-line"><strong>私密版保留可讲述性</strong><span>适合发给家人朋友，帮助用户把“最近都做了什么”讲得出来。</span></div>
      </div>
      <div class="action-row"><button class="secondary" data-view="chapter">回到周章节</button><button class="secondary" data-view="guide">试用指南</button><button class="secondary" data-copy-privacy>复制隐私摘要</button></div>
    </section>
  `;
}

function posterCard(asset) {
  return `
    <article class="poster-card ${asset.className}">
      <div class="poster-art" aria-hidden="true">
        <i></i><i></i><i></i><span></span>
      </div>
      <div class="poster-copy">
        <div class="eyebrow">${asset.eyebrow}</div>
        <h3>${escapeHtml(asset.title)}</h3>
        <div class="poster-badge">${escapeHtml(asset.badge)}</div>
        <p>${escapeHtml(asset.body).replace(/\n/g, "<br/>")}</p>
        <footer>${escapeHtml(asset.footer)}</footer>
      </div>
      <div class="poster-actions">
        <button class="primary poster-action" data-studio-download="${asset.id}">导出 PNG</button>
        <button class="secondary poster-action" data-studio-share="${asset.id}">系统分享</button>
        <button class="ghost poster-action" data-studio-copy="${asset.id}">复制文案</button>
      </div>
    </article>
  `;
}

function exportStep(num, title, copy) {
  return `<div class="export-step"><span>${num}</span><strong>${title}</strong><em>${copy}</em></div>`;
}

function installView() {
  const install = installManifestState();
  return `
    <div class="topline"><div><div class="brand">安装中心</div><div class="micro">让公网 Demo 更像一个能放到主屏幕的 App。</div></div></div>
    <section class="guide-card install-hero">
      <div class="eyebrow">Install Center · v32</div>
      <h1 class="hero-title">把 TSD 放到主屏幕，<br/>像 App 一样试用。</h1>
      <p class="hero-subtitle">v32 在不新增文件的前提下保留 inline manifest、iOS Web App meta、安装说明和 standalone 检测，并新增上架就绪中心。它提升外部试用质感，但仍不是原生 iOS App，也没有 service worker 离线缓存。</p>
      <div class="install-badges">
        ${installBadge("Manifest", install.hasManifest ? "ready" : "missing")}
        ${installBadge("iOS Meta", install.hasAppleMeta ? "ready" : "missing")}
        ${installBadge("Standalone", install.standalone ? "active" : "browser")}
        ${installBadge("Prompt", install.promptReady ? "ready" : "manual")}
      </div>
      <div class="action-row"><button class="primary" data-install-app>尝试浏览器安装</button><button class="secondary" data-copy-install>复制安装说明</button><button class="secondary" data-check-app-shell>检测 App 模式</button></div>
      <p class="source-line">当前平台建议：${escapeHtml(install.platform)}。上次安装尝试：${escapeHtml(state.installAttemptAt || "尚未尝试")}。</p>
      ${state.toast ? `<p class="toast">${state.toast}</p>` : ""}
    </section>
    <section class="guide-card">
      <h2 class="section-title">安装步骤 <span class="micro">给试用者</span></h2>
      <div class="install-steps">
        ${installStep("iPhone / iPad", "用 Safari 打开公网地址，点分享按钮，选择“添加到主屏幕”。")}
        ${installStep("Android", "用 Chrome 打开公网地址，点菜单，选择“安装应用”或“添加到主屏幕”。")}
        ${installStep("桌面", "用 Chrome / Edge 打开，点地址栏右侧安装图标，或从菜单选择安装。")}
      </div>
      <div class="action-row"><button class="secondary" data-copy-demo-link>复制公网链接</button><button class="secondary" data-copy-install>复制安装说明</button></div>
    </section>
    <section class="guide-card">
      <h2 class="section-title">App-like Shell <span class="micro">边界说明</span></h2>
      <div class="processing-ledger">
        ${processingBoundary("已做", "v32", "inline manifest、Apple web app meta、touch icon、主屏安装说明、standalone 检测、QA 路线、底部 Memory Camera、Launch Readiness。", "safe")}
        ${processingBoundary("未做", "生产待做", "未新增 service worker；不承诺离线缓存、后台同步、推送或原生权限弹窗。", "warn")}
        ${processingBoundary("App Store", "未来", "真实上架仍需 iOS 原生壳、正式图标资产、权限文案、隐私政策和审核材料。", "warn")}
      </div>
      <p class="source-line">上次检测：${escapeHtml(state.appShellCheckedAt || "尚未检测")}；浏览器安装提示：${escapeHtml(state.installPromptSeenAt || "尚未出现")}；安装完成事件：${escapeHtml(state.appInstalledAt || "尚未收到")}。</p>
    </section>
  `;
}

function installBadge(label, value) {
  return `<div class="install-badge ${value}"><strong>${label}</strong><span>${value}</span></div>`;
}

function installStep(title, copy) {
  return `<div class="install-step"><strong>${title}</strong><span>${copy}</span></div>`;
}

function launchView() {
  const stats = launchStats();
  const nativeStats = nativeHandoffStats();
  const checksum = launchChecksum();
  return `
    <div class="topline"><div><div class="brand">上架就绪</div><div class="micro">把商品级 App 上线前的证据、缺口和回执摊开。</div></div></div>
    <section class="guide-card launch-hero">
      <div class="eyebrow">Launch Readiness · v32</div>
      <h1 class="hero-title">不是说“快好了”，<br/>而是逐项给出证据。</h1>
      <p class="hero-subtitle">TSD 处理的是人生记忆。上架前必须能回答：影像怎么进来、数据怎么带走、删除如何回执、AI 如何降级、账号为何不是牢笼、审核材料还缺什么。</p>
      <div class="launch-score-grid">
        ${launchMetric("Ready", stats.ready, "已可点击验证")}
        ${launchMetric("PoC", stats.poc, "产品假面")}
        ${launchMetric("Todo", stats.todo, "生产硬缺口")}
        ${launchMetric("Native", nativeStats.total, "原生移交项")}
      </div>
      <div class="action-row"><button class="primary" data-launch-preflight>运行上架预检</button><button class="secondary" data-copy-launch>复制上线报告</button><button class="secondary" data-copy-native-handoff>复制原生移交账本</button><button class="secondary" data-view="qa">QA Console</button></div>
      <p class="source-line">上次预检：${escapeHtml(state.launchPreflightAt || "尚未运行")}；上次报告：${escapeHtml(state.launchReportCopiedAt || "尚未复制")}。</p>
      ${state.toast ? `<p class="toast">${state.toast}</p>` : ""}
    </section>
    <section class="guide-card">
      <h2 class="section-title">生产闭环 <span class="micro">capture → vault → launch</span></h2>
      <div class="launch-flow">
        ${launchStep("01", "捕捉入口", "Memory Camera、Quick Mark、媒体墙和旧切片补影像。", "ready")}
        ${launchStep("02", "本地保险箱", "JSON 导出、示例导入、清空、本地优先。", "ready")}
        ${launchStep("03", "媒体保险箱", "有限相册、E2EE 分层、缩略图、媒体导出包。", state.mediaVaultSealedAt ? "ready" : "poc")}
        ${launchStep("04", "账户与恢复", "访客可用、通行证、恢复钥匙、设备复核、退订取回。", state.passCreatedAt ? "ready" : "poc")}
        ${launchStep("05", "AI 网关", "任务单、预算、队列、授权、降级、撤销。", state.gatewayStatus !== "idle" ? "ready" : "poc")}
        ${launchStep("06", "导出与删除", "checksum、删除回执、模型缓存删除、媒体包回收。", state.launchDeletionReceiptAt ? "ready" : "poc")}
        ${launchStep("07", "审核材料", "隐私标签、权限文案、生成式 AI 说明、订阅权利。", state.launchStoreReviewAt ? "ready" : "todo")}
      </div>
    </section>
    <section class="guide-card">
      <h2 class="section-title">就绪账本 <span class="micro">${stats.total} checks</span></h2>
      <div class="launch-ledger">
        ${launchReadinessRows().map(([name, status, copy]) => launchLedgerRow(name, status, copy)).join("")}
      </div>
    </section>
    <section class="guide-card native-handoff-card">
      <h2 class="section-title">原生移交账本 <span class="micro">Native Handoff · iOS</span></h2>
      <p class="hero-subtitle">v32 把 Web Demo 的能力拆成 iOS / backend / App Store Connect / release 四类施工项。它不是“已经原生化”，而是让下一步 SwiftUI、PhotosPicker、E2EE、隐私表单和 TestFlight 准备有可复制的任务单。</p>
      <div class="native-score-grid">
        ${launchMetric("PoC", nativeStats.poc, "已有演示证据")}
        ${launchMetric("Todo", nativeStats.todo, "真实施工")}
        ${launchMetric("Rows", nativeStats.total, "移交条目")}
      </div>
      <div class="native-ledger">
        ${nativeHandoffRows().map(([name, status, owner, copy]) => nativeHandoffRow(name, status, owner, copy)).join("")}
      </div>
      <div class="native-source-grid">
        ${nativeSource("App Review Guidelines", "审核内容、用户生成内容、订阅、AI 和数据权利仍需按 Apple 当前指南逐项复核。")}
        ${nativeSource("App Privacy Details", "App Store Connect 隐私问卷必须映射 TSD 的用户内容、照片/视频、账号、诊断和可选模型处理。")}
        ${nativeSource("Privacy Manifest", "第三方 SDK、required reason API 和追踪声明需要在原生工程中用 manifest/审计记录承接。")}
      </div>
      <div class="action-row"><button class="secondary" data-native-review>标记原生迁移复核</button><button class="secondary" data-privacy-manifest-audit>标记 Privacy Manifest 审计</button><button class="secondary" data-copy-native-handoff>复制原生移交账本</button></div>
      <p class="source-line">原生迁移复核：${escapeHtml(state.nativeMigrationReviewAt || "尚未标记")}；Privacy Manifest 审计：${escapeHtml(state.privacyManifestAuditAt || "尚未标记")}；移交报告：${escapeHtml(state.nativeHandoffCopiedAt || "尚未复制")}。</p>
    </section>
    <section class="guide-card">
      <h2 class="section-title">导出包校验 <span class="micro">portable memory</span></h2>
      <div class="launch-receipt-card">
        <strong>${escapeHtml(checksum)}</strong>
        <span>基于当前本地记忆保险箱 JSON 计算的 Demo checksum。生产版应升级为签名 manifest、文件级 checksum、媒体包清单和可重算验证器。</span>
      </div>
      <div class="action-row"><button class="secondary" data-launch-checksum>生成导出校验</button><button class="secondary" data-export-vault>导出 JSON</button><button class="secondary" data-copy-vault>复制保险箱</button></div>
      <p class="source-line">上次导出校验：${escapeHtml(state.launchChecksumAt || "尚未生成")}。</p>
    </section>
    <section class="guide-card">
      <h2 class="section-title">删除回执 <span class="micro">delete receipt</span></h2>
      <div class="delete-receipt-grid">
        ${deleteReceiptItem("原文/切片", state.vaultDeletedAt ? "已清空演示" : "可清空")}
        ${deleteReceiptItem("原图/视频", state.mediaDeleteRequestAt ? "已请求" : "待请求")}
        ${deleteReceiptItem("缩略图", state.mediaThumbnailPurgeAt ? "已清除" : "待清除")}
        ${deleteReceiptItem("AI 缓存", state.gatewayRevokedAt || state.aiDraftRevokedAt ? "已撤销" : "待撤销")}
        ${deleteReceiptItem("云副本", state.syncPausedAt ? "已暂停" : "假面待做")}
        ${deleteReceiptItem("回执", state.launchDeletionReceiptAt || "尚未生成")}
      </div>
      <div class="action-row"><button class="ghost danger" data-launch-delete-receipt>生成删除回执</button><button class="secondary" data-purge-media-thumbnails>清缩略图</button><button class="secondary" data-gateway-revoke>撤销 AI 授权</button></div>
    </section>
    <section class="guide-card">
      <h2 class="section-title">App Store 审核包 <span class="micro">review packet</span></h2>
      <div class="review-pack-grid">
        ${reviewPackItem("隐私政策", "待正式法务", "Demo 已有生产隐私中心和复制报告。")}
        ${reviewPackItem("权限文案", "PoC", "相册有限选择、通知不默认请求、定位/通讯录不请求。")}
        ${reviewPackItem("生成式 AI", "PoC", "DeepSeek 任务单、预算、降级和撤销账本。")}
        ${reviewPackItem("订阅权利", "PoC", "退订不扣留已有记忆，导出/查看/删除继续可用。")}
        ${reviewPackItem("儿童/家庭影像", "PoC", "家庭影像复核，公开分享默认隐藏原图和身份线索。")}
        ${reviewPackItem("原生能力", "Todo", "真实 iOS 壳、正式图标、service worker/offline、原生权限弹窗。")}
      </div>
      <div class="action-row"><button class="secondary" data-launch-store-review>标记审核包待复核</button><button class="secondary" data-copy-review>复制审核摘要</button><button class="secondary" data-view="review">生产隐私中心</button></div>
      <p class="source-line">上次审核包标记：${escapeHtml(state.launchStoreReviewAt || "尚未标记")}。</p>
    </section>
  `;
}

function launchMetric(label, value, copy) {
  return `<div class="launch-metric"><strong>${escapeHtml(String(value))}</strong><span>${escapeHtml(label)}</span><em>${escapeHtml(copy)}</em></div>`;
}

function launchStep(num, title, copy, status) {
  return `<div class="launch-step ${status}"><span>${num}</span><strong>${escapeHtml(title)}</strong><em>${escapeHtml(copy)}</em><small>${escapeHtml(status)}</small></div>`;
}

function launchLedgerRow(name, status, copy) {
  return `<div class="launch-row ${status}"><strong>${escapeHtml(name)}</strong><span>${escapeHtml(status)}</span><em>${escapeHtml(copy)}</em></div>`;
}

function nativeHandoffRow(name, status, owner, copy) {
  return `<div class="native-row ${status}">
    <span>${escapeHtml(status)}</span>
    <strong>${escapeHtml(name)}</strong>
    <small>${escapeHtml(owner)}</small>
    <em>${escapeHtml(copy)}</em>
  </div>`;
}

function nativeSource(title, copy) {
  return `<div class="native-source"><strong>${escapeHtml(title)}</strong><span>${escapeHtml(copy)}</span></div>`;
}

function deleteReceiptItem(title, value) {
  return `<div class="delete-receipt-item"><strong>${escapeHtml(title)}</strong><span>${escapeHtml(value)}</span></div>`;
}

function reviewPackItem(title, status, copy) {
  return `<div class="review-pack-item"><strong>${escapeHtml(title)}</strong><span>${escapeHtml(status)}</span><em>${escapeHtml(copy)}</em></div>`;
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
        ${trialStep("04", "看媒体记忆墙", "照片/视频如何把切片串成回忆时间线。", "media")}
        ${trialStep("05", "看人物地点镜头", "从人和地点重新讲起一段时间。", "lens")}
        ${trialStep("06", "看媒体库生产", "相册权限、加密库、缩略图、导出删除。", "library")}
        ${trialStep("07", "做 90 天回忆", "先自由回忆，再揭开季度风景。", "ritual")}
        ${trialStep("08", "生成视觉成品", "看周章节海报、季度卡和人生旷野卡。", "studio")}
        ${trialStep("09", "检查记忆保险箱", "导出、导入、清空，确认记忆能带走。", "settings")}
        ${trialStep("10", "看账户权利", "访客、恢复钥匙、设备、退订取回和权利报告。", "account")}
        ${trialStep("11", "看审核中心", "权限、隐私、AI、同步和生产待做。", "review")}
        ${trialStep("12", "安装到主屏幕", "复制安装说明，检测是否像 App 一样打开。", "install")}
        ${trialStep("13", "看上架就绪中心", "预检、导出校验、删除回执和审核包。", "launch")}
        ${trialStep("14", "看原生移交账本", "确认 SwiftUI、PhotosPicker、E2EE、隐私表单和 TestFlight 的真实施工项。", "launch")}
        ${trialStep("15", "打开 QA Console", "看当前公网 Demo 哪些路径已通过、哪些仍是 PoC。", "qa")}
      </div>
    </section>
    <section class="guide-card">
      <h2 class="section-title">当前能力边界 <span class="micro">说清楚才可信</span></h2>
      <div class="boundary-grid">
        ${boundaryColumn("已可试用", [
          "Quick Mark 与今日切片",
          "影像线索与媒体记忆墙",
          "可编辑周章节与隐私分享预览",
          "人生旷野五档语义缩放",
          "分享工作室三类视觉成品",
          "记忆保险箱导出/导入/清空",
          "同步控制台、账户权利中心与数据离机账本",
          "Demo QA Console 验收面板",
          "Launch Readiness 上架就绪账本",
          "媒体库生产假面",
          "90 天回忆仪式"
        ], "ok")}
        ${boundaryColumn("PoC 模拟", [
          "AI 分层与 DeepSeek 模式为演示开关",
          "规则门禁用于模拟忠实编辑",
          "季度风景使用本地样例与当前切片",
          "分享卡仅生成视觉预览和文案，不发布到社交平台"
        ], "soft")}
        ${boundaryColumn("生产待做", [
          "真实账户、E2EE 密钥恢复与服务端同步",
          "真实 API 接入、供应商条款和生产密钥管理",
          "App Store 隐私营养标签",
          "Service worker、离线缓存、iOS 原生壳与正式图标资产",
          "Privacy Manifest、required reason API、TestFlight 审核包"
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
      <div class="action-row"><button class="secondary" data-copy-privacy>复制隐私摘要</button><button class="secondary" data-copy-review>复制审核包</button><button class="secondary" data-view="launch">上架就绪中心</button><button class="secondary" data-view="account">账户权利中心</button><button class="secondary" data-view="qa">打开 QA Console</button><button class="secondary" data-view="ai">查看 AI 边界</button></div>
    </section>
    <section class="guide-card">
      <h2 class="section-title">真实产品边界图 <span class="micro">v32</span></h2>
      <div class="production-map">
        ${productionNode("设备本地", "Quick Mark、敏感标记、仅设备记忆先留在本机。", "ready")}
        ${productionNode("L0 规则层", "事实门、语气门、照片门先在本地兜底。", "ready")}
        ${productionNode("云模型", "DeepSeek V4 Flash 只应处理用户允许的摘要或非敏感草稿。", "poc")}
        ${productionNode("加密同步", "生产版需账户、E2EE、恢复窗口和地区数据边界。", "todo")}
        ${productionNode("用户权利", "导出、删除、撤销 AI 草稿、查看来源必须是一级能力。", "ready")}
      </div>
      <p class="source-line">v32 仍不调用真实模型和真实账户；它在 v28 Memory Camera 主入口之上新增 Launch Readiness，并吸收 Day One / Diarly / Craft / Apple Journal 的优秀 DNA：Bento 首页、Journal 时间轴、照片墙/地图切换、按钮层级和微动效共同构成上架前证据链。</p>
    </section>
    <section class="guide-card">
      <h2 class="section-title">App Store 方向清单</h2>
      <div class="readiness-list">
        ${readiness("产品灵魂", "完成", "时间切片机、人生旷野、90 天可讲述。")}
        ${readiness("数据权利", "Demo 覆盖", "导出、导入、清空已可点击；生产需账户与恢复。")}
        ${readiness("AI 边界", "PoC 覆盖", "分层架构和黄金样本已可看；生产需真实网关。")}
        ${readiness("安装体验", "v32 PoC", "inline manifest、iOS meta、touch icon、安装中心、standalone 检测和 Memory Camera 主入口已加入；离线缓存仍待做。")}
        ${readiness("账户权利", "v27-v32 PoC", "访客通行证、恢复钥匙、设备复核、退订取回窗口和权利报告已加入；真实账户/E2EE 待做。")}
        ${readiness("合规文本", "雏形", "隐私/AI/同步边界已写入 App 内。")}
        ${readiness("审核中心", "v12", "权限说明、FAQ、隐私标签雏形可查看。")}
        ${readiness("视觉成品", "v13", "分享工作室可生成周章节、季度回忆和人生旷野卡。")}
        ${readiness("影像线索", "v14", "Quick Mark 支持照片/视频文件、影像链接和影像备注。")}
        ${readiness("媒体优先入口", "v19", "首次进入即可从照片/视频开始，文字可后补；影像被视为切片锚点而非附件。")}
        ${readiness("切片补影像", "v22", "已有切片可事后补照片/视频或影像链接，周末回顾时也能把真实影像贴回记忆。")}
        ${readiness("PNG 分享成品", "v20", "分享工作室可本地生成 PNG；公开版默认隐藏原图、人名、地点和原文。")}
        ${readiness("模型网关控制台", "v21", "Provider、预算、队列、授权、降级和撤销日志可点击演示。")}
        ${readiness("Memory Camera", "v28", "底部悬浮“＋影像”让用户不用读说明也能从照片/视频开始一张切片。")}
        ${readiness("Launch Readiness", "v32", "预检账本、导出包 checksum、删除回执、App Store 审核包和可复制上线报告。")}
        ${readiness("Native Handoff", "v32", "SwiftUI 壳、PhotosPicker、Keychain/E2EE、DeepSeek 网关、App Privacy Details、Privacy Manifest 和 TestFlight 包已拆成移交账本。")}
        ${readiness("QA Console", "v32", "核心试用路径、账户权利、安装体验、PoC 边界、媒体入口、媒体保险箱、上架就绪、原生移交和生产待做被整理成可复制验收报告。")}
        ${readiness("媒体墙", "v15", "可按照片/视频/链接筛选已绑定影像，并查看回忆时间线。")}
        ${readiness("人物地点镜头", "v17", "从用户写下的词和影像备注中聚合可讲述的人/地点线索。")}
        ${readiness("媒体保险箱", "v24", "相册权限、E2EE 分层、缩略图清除、导出包、删除审计和家庭/儿童影像复核。")}
      </div>
      <div class="action-row"><button class="secondary" data-view="media">打开媒体记忆墙</button><button class="secondary" data-view="lens">人物地点镜头</button><button class="secondary" data-view="library">媒体库生产</button><button class="secondary" data-view="account">账户权利</button><button class="secondary" data-view="install">安装中心</button><button class="secondary" data-view="launch">上架就绪</button><button class="secondary" data-view="studio">打开分享工作室</button><button class="secondary" data-view="review">打开审核中心</button><button class="secondary" data-view="qa">打开 QA Console</button></div>
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

function reviewView() {
  return `
    <div class="topline"><div><div class="brand">审核中心</div><div class="micro">给试用者、agent、未来审核和法务看的边界页。</div></div></div>
    <section class="guide-card review-hero">
      <div class="eyebrow">Review Packet · v32</div>
      <h1 class="hero-title">记忆产品的信任，<br/>必须能被看见。</h1>
      <p class="hero-subtitle">TSD 处理的是人生记忆，所以“说清楚”本身就是产品能力。这里把权限、数据生命周期、AI、影像、同步和删除权做成可读的生产隐私中心雏形。</p>
      <div class="action-row"><button class="primary" data-copy-compliance>复制生产隐私报告</button><button class="secondary" data-copy-review>复制审核包摘要</button><button class="secondary" data-view="launch">上架就绪中心</button><button class="secondary" data-view="account">账户权利中心</button><button class="secondary" data-view="qa">打开 QA Console</button><button class="secondary" data-view="guide">回到试用指南</button></div>
      <p class="source-line">上次生产隐私报告：${escapeHtml(state.lastComplianceReportAt || "尚未复制")}。</p>
      ${state.toast ? `<p class="toast">${state.toast}</p>` : ""}
    </section>
    <section class="guide-card">
      <h2 class="section-title">数据生命周期 <span class="micro">从输入到删除</span></h2>
      <div class="lifecycle-map">
        ${lifecycleStep("01", "用户主动留下", "文字、照片/视频、影像备注、标签和认领动作都来自用户主动输入或选择。")}
        ${lifecycleStep("02", "本地先保存", "当前 Demo 写入浏览器 localStorage；生产版默认本地优先，不因未登录阻断记录。")}
        ${lifecycleStep("03", "可选离机任务", "AI、同步、图片分享必须通过任务单或明确动作触发，不读取整个人生档案。")}
        ${lifecycleStep("04", "可带走可删除", "导出 JSON/媒体包、清空本地、撤销 AI 草稿、删除缩略图和任务缓存必须可见。")}
        ${lifecycleStep("05", "分享先去隐私", "公开卡片默认隐藏原图、人名、地点、原文和原始影像，只分享时间风景。")}
      </div>
    </section>
    <section class="guide-card">
      <h2 class="section-title">权限升级梯子 <span class="micro">Just-in-time permission</span></h2>
      <div class="permission-ladder">
        ${permissionLadder("相册", "单次/有限选择", "只有用户主动绑定照片/视频时才触发；批量整理前必须解释原因。")}
        ${permissionLadder("通知", "默认不请求", "只有用户选择温和时间唤醒时才请求；不得用焦虑或连续打卡逼迫。")}
        ${permissionLadder("网络/AI", "任务单授权", "模型网关只处理本次任务最小字段；失败退回本地规则层。")}
        ${permissionLadder("定位/通讯录", "首发不请求", "地点和人物来自用户手写，不读 GPS、轨迹、通讯录或相册人脸。")}
      </div>
    </section>
    <section class="guide-card">
      <h2 class="section-title">权限说明 <span class="micro">Demo 当前请求</span></h2>
      <div class="permission-grid">
        ${permissionCard("相册", "有限选择优先", "Web Demo 不请求持久相册权限；生产首发也应优先用单次/有限选择器。")}
        ${permissionCard("定位", "未请求", "地点只来自用户手写，不读取 GPS 或轨迹。")}
        ${permissionCard("通讯录", "未请求", "人物关系由用户输入，不访问联系人。")}
        ${permissionCard("通知", "未请求", "时间唤醒为界面演示，不发系统推送。")}
        ${permissionCard("麦克风", "未请求", "语音 Mark 属未来方向，当前不录音。")}
        ${permissionCard("网络", "静态站点", "公网 Demo 加载静态资源，不调用真实模型接口。")}
      </div>
    </section>
    <section class="guide-card">
      <h2 class="section-title">隐私营养标签雏形 <span class="micro">上线前需复核</span></h2>
      <div class="nutrition-grid">
        ${nutritionItem("当前收集", "浏览器本地 Demo 数据、影像链接/元信息、小图预览", "local")}
        ${nutritionItem("当前不收集", "身份、联系人、定位、自动相册扫描", "safe")}
        ${nutritionItem("未来可选", "账户、E2EE 同步、加密影像库、缩略图、模型任务摘要", "poc")}
        ${nutritionItem("用户权利", "导出、清空、撤销草稿、暂停同步、退订取回、恢复钥匙", "safe")}
      </div>
      <p class="source-line">生产版必须用正式法务文本和平台表单重做；这里的价值是提前把数据类别和用户权利放进产品界面。</p>
    </section>
    <section class="guide-card">
      <h2 class="section-title">处理边界台账 <span class="micro">Media / AI / Sync</span></h2>
      <div class="processing-ledger">
        ${processingBoundary("原始影像", "不自动上传", "仅用户主动绑定；生产版需 E2EE、导出包和删除原图/缩略图。", "safe")}
        ${processingBoundary("模型任务", "最小字段", "只发送任务单允许字段；缓存、草稿和撤销日志必须可见。", "poc")}
        ${processingBoundary("同步数据", "可暂停", "同步是增强，不是扣押；退订后已有记忆仍可查看、编辑、导出。v27-v32 已提供账户权利中心假面。", "safe")}
        ${processingBoundary("家庭/未成年影像", "默认谨慎", "公开分享不带原图、人名、地点和原文；未来需更严格提示。", "warn")}
      </div>
    </section>
    <section class="guide-card">
      <h2 class="section-title">试用者 FAQ</h2>
      <div class="faq-list">
        ${faqItem("这是真 App 吗？", "不是。当前是公网 Web Demo，用来验证产品体验、信息架构和信任边界。")}
        ${faqItem("我的记录会上传吗？", "当前 Demo 记录保存在你的浏览器 localStorage；可以导出 JSON，也可以清空。")}
        ${faqItem("AI 真的调用 DeepSeek 吗？", "没有。DeepSeek V4 Flash 是 PoC 目标，当前只演示任务单、路由、门禁和降级。")}
        ${faqItem("退订会丢记忆吗？", "产品原则是不扣留已有记忆；同步控制台已演示取回窗口。")}
        ${faqItem("低落和普通日子会被保留吗？", "会。TSD 不只记录高光，晴天雨天一起构成人生旷野。")}
      </div>
    </section>
    <section class="guide-card">
      <h2 class="section-title">生产待做清单 <span class="micro">不能假装完成</span></h2>
      <div class="readiness-list">
        ${readiness("原生壳", "待做", "iOS 项目、权限弹窗、安装资产、App Icon。")}
        ${readiness("账户同步", "v27-v32 假面", "账户权利中心已演示访客通行证、恢复钥匙、设备复核、退订取回；真实登录、E2EE、密钥恢复、设备管理仍待做。")}
        ${readiness("媒体库", "v18/v20 雏形", "相册权限、加密影像库、缩略图、导出删除、PNG 成品和分享边界已产品化。")}
        ${readiness("模型网关", "v21 假面", "Provider 状态、限流预算、任务队列、失败降级和撤销日志已产品化；真实 API/密钥仍待接入。")}
        ${readiness("合规文本", "v22 雏形", "生产隐私中心、生命周期、权限升级和处理边界已产品化；正式法律文本仍待复核。")}
        ${readiness("审核材料", "v22/v32 雏形", "本页可复制生产隐私报告、账户权利报告、Launch Report 和 Demo 验收报告；不代表已通过法务或上架审核。")}
      </div>
    </section>
  `;
}

function qaView() {
  const score = qaScore();
  const snapshot = qaSnapshot();
  return `
    <div class="topline"><div><div class="brand">QA Console</div><div class="micro">把当前公网 Demo 的可靠性和边界摊开给试用者看。</div></div></div>
    <section class="guide-card qa-hero">
      <div class="eyebrow">Demo QA Console · v32</div>
      <h1 class="hero-title">这不是口头说“能用”，<br/>而是把证据放出来。</h1>
      <p class="hero-subtitle">TSD 的 demo 越接近商品级，越需要让用户、测试者和其他 agent 清楚知道：哪些路径已经可以点击验证，哪些仍只是 PoC，哪些上架前必须补完。</p>
      <div class="qa-scoreboard">
        ${qaMetric("PASS", score.pass, "可点击验证")}
        ${qaMetric("POC", score.poc, "假面/边界")}
        ${qaMetric("TODO", score.todo + score.warn, "生产待做")}
      </div>
      <div class="action-row"><button class="primary" data-copy-qa>复制 QA 报告</button><button class="secondary" data-view="launch">上架就绪</button><button class="secondary" data-view="guide">试用路线</button><button class="secondary" data-view="review">生产隐私中心</button></div>
      <p class="source-line">上次 QA 报告：${escapeHtml(snapshot.qaReportAt)}。公网：${escapeHtml(snapshot.publicUrl)}；资源：${escapeHtml(snapshot.resources)}。</p>
      ${state.toast ? `<p class="toast">${state.toast}</p>` : ""}
    </section>
    <section class="guide-card">
      <h2 class="section-title">当前样本状态 <span class="micro">Local demo state</span></h2>
      <div class="qa-state-grid">
        ${qaState("切片", snapshot.moments, "张")}
        ${qaState("影像锚点", snapshot.mediaCount, "个")}
        ${qaState("周认领", snapshot.claimedCount, "个")}
        ${qaState("AI 网关", snapshot.gatewayStatus, "")}
      </div>
      <p class="source-line">这些是当前浏览器里的样本状态，不是云端统计；Demo 仍保持本地优先。</p>
    </section>
    <section class="guide-card">
      <h2 class="section-title">验收路线 <span class="micro">${score.total} checks</span></h2>
      <div class="qa-checklist">
        ${snapshot.checks.map(qaCheckRow).join("")}
      </div>
    </section>
    <section class="guide-card">
      <h2 class="section-title">推荐人工 smoke <span class="micro">3 分钟</span></h2>
      <div class="qa-route">
        ${qaRouteStep("01", "从照片/视频开始", "点底部“＋影像”、onboarding 或此刻页选一张图，确认进入今日切片。", "slice")}
        ${qaRouteStep("02", "给旧切片补影像", "到周章节候选卡，给无影像的切片补一张照片。", "chapter")}
        ${qaRouteStep("03", "看媒体保险箱", "进入媒体库生产，模拟权限说明、封存、导出包和删除审计。", "library")}
        ${qaRouteStep("04", "看媒体墙", "确认媒体数增加，照片/视频进入回忆时间线。", "media")}
        ${qaRouteStep("05", "编译章节", "认领 3 个瞬间，确认章节正文保留 source。", "chapter")}
        ${qaRouteStep("06", "导出视觉成品", "到分享工作室生成 PNG，公开版隐藏原文和原始影像。", "studio")}
        ${qaRouteStep("07", "检查账户权利", "打开账户权利中心，创建通行证、生成恢复钥匙、复核设备、复制权利报告。", "account")}
        ${qaRouteStep("08", "检查安装体验", "打开安装中心，复制安装说明并检测 App-like shell。", "install")}
        ${qaRouteStep("09", "运行上架预检", "进入 Launch Readiness，生成导出 checksum、删除回执和上线报告。", "launch")}
        ${qaRouteStep("10", "检查原生移交账本", "在 Launch Readiness 里标记原生迁移复核和 Privacy Manifest 审计。", "launch")}
        ${qaRouteStep("11", "复制隐私/QA 报告", "在生产隐私中心与 QA Console 复制报告，确认边界可讲清。", "review")}
      </div>
    </section>
    <section class="guide-card">
      <h2 class="section-title">上线前硬缺口 <span class="micro">不能靠 demo 混过去</span></h2>
      <div class="processing-ledger">
        ${processingBoundary("真实模型", "待接入", "DeepSeek V4 Flash 目前仍是 PoC 假面；生产需密钥管理、限流、供应商审查和任务回放。", "warn")}
        ${processingBoundary("真实同步", "待接入", "账户权利中心是 v27-v32 假面；真实账户、E2EE、密钥恢复、设备管理、地区数据边界仍未实现。", "warn")}
        ${processingBoundary("相册权限", "PoC 边界", "v24 已有媒体保险箱路径；真实系统 Photos Picker、E2EE 文件库和删除回执仍待接入。", "warn")}
        ${processingBoundary("安装资产", "PoC 边界", "v32 保留 inline manifest、iOS meta 和安装中心；service worker、离线缓存和原生壳仍待做。", "poc")}
        ${processingBoundary("原生移交", "v32 PoC", "Native Handoff Ledger 已拆出 iOS、backend、App Store Connect、release 四类任务；真实 SwiftUI/TestFlight 仍待做。", "poc")}
        ${processingBoundary("上线闭环", "v32 PoC", "Launch Readiness 已串起预检、导出校验、删除回执和审核包；真实签名、法务和原生流水线仍待做。", "poc")}
      </div>
    </section>
  `;
}

function qaMetric(label, value, copy) {
  return `<div class="qa-metric"><strong>${escapeHtml(String(value))}</strong><span>${escapeHtml(label)}</span><em>${escapeHtml(copy)}</em></div>`;
}

function qaState(label, value, unit) {
  return `<div class="qa-state"><span>${escapeHtml(label)}</span><strong>${escapeHtml(String(value))}</strong><em>${escapeHtml(unit)}</em></div>`;
}

function qaCheckRow(item) {
  return `<div class="qa-check ${item.status}">
    <span>${escapeHtml(item.status.toUpperCase())}</span>
    <strong>${escapeHtml(item.area)}</strong>
    <em>${escapeHtml(item.route)}</em>
    <small>${escapeHtml(item.evidence)}</small>
  </div>`;
}

function qaRouteStep(num, title, copy, view) {
  return `<button class="qa-route-step" data-view="${view}">
    <span>${num}</span>
    <strong>${escapeHtml(title)}</strong>
    <em>${escapeHtml(copy)}</em>
  </button>`;
}

function lifecycleStep(num, title, copy) {
  return `<div class="lifecycle-step"><span>${num}</span><strong>${title}</strong><em>${copy}</em></div>`;
}

function permissionLadder(title, status, copy) {
  return `<div class="permission-ladder-item"><strong>${title}</strong><span>${status}</span><em>${copy}</em></div>`;
}

function processingBoundary(title, status, copy, tone) {
  return `<div class="processing-boundary ${tone}"><span>${title}</span><strong>${status}</strong><em>${copy}</em></div>`;
}

function permissionCard(title, status, copy) {
  return `<div class="permission-card"><span>${title}</span><strong>${status}</strong><em>${copy}</em></div>`;
}

function nutritionItem(title, value, tone) {
  return `<div class="nutrition-item ${tone}"><strong>${title}</strong><span>${value}</span></div>`;
}

function faqItem(question, answer) {
  return `<details class="faq-item" open><summary>${question}</summary><p>${answer}</p></details>`;
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
  return `<article class="claim-card-shell ${active ? "active" : ""}">
    <button class="claim-card" data-claim="${escapeHtml(moment.id)}">
      <span class="claim-check">${active ? "✓" : "+"}</span>
      <span><strong>${escapeHtml(moment.title)}</strong><em>${escapeHtml(moment.text)}</em><small>${escapeHtml(moment.tags.join(" · "))} · ${moment.media ? `${mediaKindLabel(moment.media.kind)}锚点 · ` : "尚未绑定影像 · "}source: ${escapeHtml(moment.id)}</small></span>
    </button>
    ${mediaBlock(moment.media)}
    ${mediaAttachActions(moment, true)}
  </article>`;
}

function aiTaskSheet() {
  const claimed = getClaimedMoments().slice(0, 3);
  const safeTitles = claimed.map(moment => `${moment.date} · ${moment.title}`);
  return {
    title: "本周章节忠实编译",
    purpose: "把用户已经认领的 3 个瞬间整理成可编辑草稿。",
    route: state.aiMode === "deepseek" ? "L2 DeepSeek V4 Flash（Demo 仅模拟）" : "L0 本地规则层",
    allowed: [
      `${claimed.length} 个被认领切片标题与日期`,
      "用户确认过的切片正文",
      "来源 ID 与标签",
      "当前任务目的：周章节编译"
    ],
    blocked: [
      "完整人生档案",
      "未认领的敏感记忆",
      "原始照片文件与位置轨迹",
      "联系人、设备通讯录或社交账号"
    ],
    fallback: "模型失败或用户关闭云 AI 时，退回本地模板，不中断记录。",
    rights: ["查看发送内容", "复制任务单", "撤销 AI 草稿", "导出/删除本地数据"],
    samples: safeTitles
  };
}

function aiView() {
  const selected = goldenSamples.find(sample => sample.id === state.selectedGolden) || goldenSamples[0];
  const sheet = aiTaskSheet();
  const gateway = gatewaySnapshot();
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
      <h2 class="section-title">AI 任务单 <span class="micro">v12 · 离机前确认</span></h2>
      <div class="task-sheet">
        <div class="task-head">
          <span>模拟请求</span>
          <strong>${sheet.title}</strong>
          <em>${sheet.route}</em>
        </div>
        <div class="task-grid">
          ${taskColumn("允许发送", sheet.allowed, "ok")}
          ${taskColumn("禁止发送", sheet.blocked, "warn")}
        </div>
        <div class="task-purpose"><strong>任务目的</strong><span>${sheet.purpose}</span></div>
        <div class="sample-strip">${sheet.samples.map(item => `<span>${escapeHtml(item)}</span>`).join("")}</div>
        <div class="rights-strip">
          ${sheet.rights.map(item => `<span>${escapeHtml(item)}</span>`).join("")}
        </div>
        <div class="action-row">
          <button class="primary" data-simulate-ai-task>模拟一次 AI 请求</button>
          <button class="secondary" data-copy-ai-task>复制任务单</button>
          <button class="ghost danger" data-revoke-ai-draft>撤销 AI 草稿</button>
        </div>
      </div>
      <p class="source-line">这不是弹一个吓人的合规窗，而是把“数据离机前发生了什么”做成用户能读懂、能撤销、能带走的任务单。</p>
      ${state.toast ? `<p class="toast">${state.toast}</p>` : ""}
    </section>
    <section class="ai-card gateway-card">
      <h2 class="section-title">模型网关控制台 <span class="micro">v21 · DeepSeek PoC</span></h2>
      <div class="gateway-console">
        <div class="gateway-head">
          <div><span>Provider</span><strong>${gateway.provider}</strong><em>${gateway.region}</em></div>
          <div><span>状态</span><strong>${gatewayStatusLabel(gateway.status)}</strong><em>${state.aiMode === "deepseek" ? "云 PoC 路径" : "本地优先路径"}</em></div>
        </div>
        <div class="gateway-stats">
          ${gatewayStat("预算", `${gateway.budgetUsed}/${gateway.budgetCap}¢`, "单次 PoC 上限")}
          ${gatewayStat("队列", gateway.queue.length, "可审计任务")}
          ${gatewayStat("授权", state.gatewayConsentAt ? "已记" : "未授权", "每次任务单独确认")}
        </div>
        <div class="gateway-budget"><i style="width:${Math.min(100, Math.round((gateway.budgetUsed / gateway.budgetCap) * 100))}%"></i></div>
        <div class="gateway-queue">
          ${gateway.queue.map(gatewayQueueRow).join("")}
        </div>
        <div class="gateway-ledger">
          ${gateway.ledger.map(([label, value]) => gatewayLedgerRow(label, value)).join("")}
        </div>
        <div class="action-row">
          <button class="primary" data-gateway-run>授权并模拟发送</button>
          <button class="secondary" data-gateway-fallback>模拟失败降级</button>
          <button class="secondary" data-copy-gateway>复制网关报告</button>
          <button class="ghost danger" data-gateway-revoke>撤销模型授权</button>
        </div>
      </div>
      <p class="source-line">v21 不伪装真实 API 调用；它把未来真实 DeepSeek 网关的 provider、预算、队列、授权、降级和撤销做成可审计界面。</p>
    </section>
    <section class="ai-card">
      <h2 class="section-title">模型路由与降级 <span class="micro">v12 生产边界</span></h2>
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
      <p class="source-line">v12 不伪装真实 API 调用。DeepSeek V4 Flash 仍是首发 PoC 目标，但当前公网 Demo 只展示路由、任务单、门禁和降级策略。</p>
    </section>
  `;
}

function gatewayStatusLabel(status = state.gatewayStatus) {
  if (status === "sent") return "已模拟发送";
  if (status === "fallback") return "已降级";
  if (status === "revoked") return "已撤销";
  return "待授权";
}

function gatewayStat(label, value, copy) {
  return `<div class="gateway-stat"><strong>${escapeHtml(value)}</strong><span>${escapeHtml(label)}</span><em>${escapeHtml(copy)}</em></div>`;
}

function gatewayQueueRow(item) {
  return `<div class="gateway-queue-row">
    <span>${escapeHtml(item.id)}</span>
    <strong>${escapeHtml(item.label)}</strong>
    <em>${escapeHtml(item.route)} · 风险 ${escapeHtml(item.risk)}</em>
    <small>${escapeHtml(item.status)}</small>
  </div>`;
}

function gatewayLedgerRow(label, value) {
  return `<div class="gateway-ledger-row"><span>${escapeHtml(label)}</span><strong>${escapeHtml(value)}</strong></div>`;
}

function evalRow(title, copy, value) {
  return `<div class="eval-row"><div><strong>${title}</strong><div class="micro">${copy}</div><div class="meter"><i style="width:${value}%"></i></div></div><div class="score">${value}%</div></div>`;
}

function taskColumn(title, items, tone) {
  return `<div class="task-column ${tone}"><strong>${title}</strong>${items.map(item => `<span>${escapeHtml(item)}</span>`).join("")}</div>`;
}

function routeStep(level, title, copy, status) {
  return `<div class="route-step"><span>${level}</span><strong>${title}</strong><em>${copy}</em><small>${status}</small></div>`;
}

function syncModeLabel() {
  if (state.syncMode === "encrypted-backup") return "加密备份演示";
  if (state.syncMode === "paused") return "同步已暂停";
  return "仅本机";
}

function accountModeLabel() {
  if (state.accountMode === "signed-in-demo") return "已登录演示";
  if (state.accountMode === "pass-demo") return "TSD 通行证演示";
  return "访客模式";
}

function subscriptionLabel() {
  if (state.subscriptionState === "plus-demo") return "Plus 演示";
  if (state.subscriptionState === "cancelled-demo") return "已退订演示";
  return "Free / 访客";
}

function accountView() {
  return `
    <div class="topline"><div><div class="brand">账户权利</div><div class="micro">账号是钥匙，不是牢笼。</div></div></div>
    <section class="guide-card account-hero">
      <div class="eyebrow">Account Rights Center · v32</div>
      <h1 class="hero-title">你的记忆，<br/>不该被账号或订阅扣住。</h1>
      <p class="hero-subtitle">TSD 的账户系统只应服务三件事：加密备份、多设备恢复、清楚的用户权利。不登录也能记录；退订后已有记忆仍可查看、编辑、导出和删除。</p>
      <div class="account-status-grid">
        ${syncStateCard("账户", accountModeLabel(), "访客也能完整记录；通行证只用于备份与恢复。")}
        ${syncStateCard("同步", syncModeLabel(), state.syncMode === "paused" ? "暂停后本机继续可用。" : "同步是增强，不是门槛。")}
        ${syncStateCard("设备", `${state.connectedDevices} 台`, "未来应可移除旧设备并查看最后活动。")}
        ${syncStateCard("订阅", subscriptionLabel(), "付费不能成为扣留人生资料的理由。")}
      </div>
      <div class="action-row"><button class="primary" data-create-pass>创建 TSD 通行证</button><button class="secondary" data-generate-recovery>生成恢复钥匙</button><button class="secondary" data-copy-account-rights>复制权利报告</button></div>
      ${state.toast ? `<p class="toast">${state.toast}</p>` : ""}
    </section>
    <section class="guide-card">
      <h2 class="section-title">账户路径 <span class="micro">guest → pass → vault</span></h2>
      <div class="account-flow">
        ${accountStep("01", "访客也能记录", "不注册、不登录，也能使用 Quick Mark、切片、媒体墙、导出和删除。", state.accountMode === "guest" ? "active" : "ready")}
        ${accountStep("02", "TSD 通行证", "当用户想换手机或多设备时，再解释账号、备份和恢复钥匙。", state.passCreatedAt || state.accountMode !== "guest" ? "ready" : "todo")}
        ${accountStep("03", "加密记忆盒", "服务端只保存密文盒；模型任务和同步任务必须有最小字段账本。", state.syncMode === "encrypted-backup" ? "ready" : "todo")}
        ${accountStep("04", "取回与退出", "退订、暂停同步、删除账户时，已有记忆仍可导出、查看和删除。", state.subscriptionState === "cancelled-demo" ? "active" : "todo")}
      </div>
    </section>
    <section class="guide-card">
      <h2 class="section-title">恢复与设备 <span class="micro">recovery / devices</span></h2>
      <div class="account-ledger">
        ${ledgerLine("通行证创建", state.passCreatedAt || "尚未创建", state.accountMode === "guest" ? "访客" : "已创建")}
        ${ledgerLine("恢复钥匙", state.recoveryKeyCreatedAt || "尚未生成", state.recoveryKeyCreatedAt ? "用户持有" : "待生成")}
        ${ledgerLine("设备复核", state.deviceReviewAt || "尚未复核", `${state.connectedDevices} 台`)}
        ${ledgerLine("最近同步", state.lastSyncAt || "尚未同步", state.syncMode === "encrypted-backup" ? "加密" : "本地")}
        ${ledgerLine("暂停时间", state.syncPausedAt || "未暂停", state.syncMode === "paused" ? "已暂停" : "无")}
        ${ledgerLine("取回窗口", state.recoveryUntil || "未开启", state.subscriptionState === "cancelled-demo" ? "30 天" : "可开启")}
      </div>
      <div class="action-row"><button class="secondary" data-simulate-backup>模拟加密备份</button><button class="secondary" data-review-devices>复核设备</button><button class="secondary" data-pause-sync>暂停同步</button><button class="secondary" data-resume-sync>恢复同步</button><button class="ghost danger" data-cancel-subscription>模拟退订</button></div>
      <p class="source-line">Demo 只写入当前浏览器状态；生产版需要真实账户、E2EE 密钥恢复、设备撤销、地区数据边界和删除回执。</p>
    </section>
    <section class="guide-card">
      <h2 class="section-title">不可妥协的用户权利 <span class="micro">non-hostage design</span></h2>
      <div class="account-rights-grid">
        ${accountRight("不登录可用", "核心记录不能被账号墙截断。")}
        ${accountRight("可导出", "JSON、媒体包、章节和可读说明都应能带走。")}
        ${accountRight("可暂停", "同步暂停后本机记录继续可用。")}
        ${accountRight("可退订", "Plus 结束后已有记忆不消失、不锁死。")}
        ${accountRight("可删除", "原文、原图、缩略图、云副本和模型缓存都要能删。")}
        ${accountRight("可恢复", "换手机时靠用户持有的恢复钥匙找回密文盒。")}
      </div>
      <div class="action-row"><button class="secondary" data-export-vault>导出 JSON</button><button class="secondary" data-view="library">媒体保险箱</button><button class="secondary" data-view="review">生产隐私中心</button><button class="secondary" data-view="qa">QA Console</button></div>
      <p class="source-line">上次账户报告：${escapeHtml(state.accountReportCopiedAt || "尚未复制")}。</p>
    </section>
  `;
}

function accountStep(num, title, copy, status) {
  return `<div class="account-step ${status}"><span>${num}</span><strong>${escapeHtml(title)}</strong><em>${escapeHtml(copy)}</em><small>${status}</small></div>`;
}

function accountRight(title, copy) {
  return `<div class="account-right"><strong>${escapeHtml(title)}</strong><span>${escapeHtml(copy)}</span></div>`;
}

function settingsView() {
  const stats = vaultStats();
  const sheet = aiTaskSheet();
  return `
    <div class="topline"><div><div class="brand">设置</div><div class="micro">隐私、付费和叙述偏好，都应该说人话。</div></div></div>
    <section class="settings-card">
      <h2 class="section-title">外部试用 <span class="micro">v32 · 公网导览</span></h2>
      <div class="chapter-list">
        <div class="chapter-line"><strong>公网地址</strong><span>${PUBLIC_DEMO_URL}</span></div>
        <div class="chapter-line"><strong>给新用户的说明</strong><span>如果你要推荐给朋友，建议让 TA 先走“试用指南”，再做 Quick Mark。</span></div>
      </div>
      <div class="action-row"><button class="primary" data-view="guide">打开试用指南</button><button class="secondary" data-view="qa">QA Console</button><button class="secondary" data-view="launch">上架就绪</button><button class="secondary" data-view="account">账户权利</button><button class="secondary" data-view="install">安装中心</button><button class="secondary" data-view="media">媒体记忆墙</button><button class="secondary" data-view="lens">人物地点镜头</button><button class="secondary" data-view="library">媒体库生产</button><button class="secondary" data-view="studio">分享工作室</button><button class="secondary" data-view="review">审核中心</button><button class="secondary" data-copy-demo-link>复制链接</button></div>
      ${state.toast ? `<p class="toast">${state.toast}</p>` : ""}
    </section>
    <section class="settings-card">
      <h2 class="section-title">记忆保险箱 <span class="micro">v14 · 本地优先</span></h2>
      <div class="vault-grid">
        ${vaultStat("切片", stats.moments, "条")}
        ${vaultStat("影像", stats.media, "个")}
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
      <div class="action-row"><button class="secondary" data-quiet>${state.quietMode ? "关闭安静期" : "进入安静期"}</button><button class="secondary" data-copy-privacy>复制隐私摘要</button><button class="secondary" data-copy-qa>复制 QA 报告</button><button class="ghost" data-reset>重置 Demo</button></div>
    </section>
    <section class="settings-card">
      <h2 class="section-title">同步控制台 <span class="micro">v32 · 多设备保险箱</span></h2>
      <div class="sync-console">
        ${syncStateCard("账户", accountModeLabel(), "不登录也能本地记录；登录只用于加密备份和多设备。")}
        ${syncStateCard("同步", syncModeLabel(), state.syncMode === "paused" ? "暂停后本机继续可用，云端不再接收新变化。" : "同步是可选增强，不是核心记录门槛。")}
        ${syncStateCard("设备", `${state.connectedDevices} 台`, "生产版应展示设备名、最后活动时间和移除入口。")}
        ${syncStateCard("订阅", subscriptionLabel(), "退订不能扣留已有记忆；导出、查看和本地记录继续可用。")}
      </div>
      <div class="sync-timeline">
        ${ledgerLine("最近同步", state.lastSyncAt || "尚未同步", state.syncMode === "encrypted-backup" ? "加密" : "本地")}
        ${ledgerLine("暂停时间", state.syncPausedAt || "未暂停", state.syncMode === "paused" ? "已暂停" : "无")}
        ${ledgerLine("取回窗口", state.recoveryUntil || "未开启", state.subscriptionState === "cancelled-demo" ? "30 天" : "待触发")}
      </div>
      <div class="action-row">
        <button class="primary" data-view="account">账户权利中心</button>
        <button class="secondary" data-simulate-backup>模拟加密备份</button>
        <button class="secondary" data-pause-sync>暂停同步</button>
        <button class="secondary" data-resume-sync>恢复同步</button>
        <button class="ghost danger" data-cancel-subscription>模拟退订</button>
      </div>
      <p class="source-line">这里验证的是商品级信任承诺：换手机可以找回，暂停同步不会丢本机记录，退订后仍能查看、编辑、导出已有记忆。</p>
      ${state.toast ? `<p class="toast">${state.toast}</p>` : ""}
    </section>
    <section class="settings-card">
      <h2 class="section-title">数据离机账本 <span class="micro">v12 · 可撤销</span></h2>
      <div class="ledger-panel">
        ${ledgerLine("最近 AI 任务", state.lastAiTaskAt || "尚未模拟", state.lastAiTaskAt ? "已记录" : "待触发")}
        ${ledgerLine("最近撤销", state.aiDraftRevokedAt || "尚未撤销", state.aiDraftRevokedAt ? "已撤销" : "无")}
        ${ledgerLine("当前任务路径", sheet.route, state.aiMode === "deepseek" ? "云 PoC" : "本地")}
      </div>
      <div class="task-grid compact">
        ${taskColumn("本次会离机", sheet.allowed.slice(0, 3), "ok")}
        ${taskColumn("本次不离机", sheet.blocked.slice(0, 3), "warn")}
      </div>
      <div class="action-row">
        <button class="secondary" data-view="ai">查看 AI 任务单</button>
        <button class="secondary" data-simulate-ai-task>模拟请求</button>
        <button class="ghost danger" data-revoke-ai-draft>撤销草稿</button>
      </div>
      <p class="source-line">生产版应把这里升级为真实审计日志：谁在什么时间、为了什么目的、处理了哪些最小字段，以及用户如何撤销和删除。</p>
      ${state.toast ? `<p class="toast">${state.toast}</p>` : ""}
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

function syncStateCard(title, value, copy) {
  return `<div class="sync-state-card"><span>${title}</span><strong>${escapeHtml(value)}</strong><em>${escapeHtml(copy)}</em></div>`;
}

function ledgerLine(title, value, status) {
  return `<div class="ledger-line"><span>${title}</span><strong>${escapeHtml(value)}</strong><em>${escapeHtml(status)}</em></div>`;
}

function plan(name, copy) {
  return `<div class="plan-card"><strong>${name}<span>›</span></strong><p>${copy}</p></div>`;
}

function bottomNav() {
  const items = [
    ["now", "此刻", "✦"],
    ["slice", "切片", "◉"],
    ["media", "影像", "▧"],
    ["meadow", "旷野", "♧"],
    ["chapter", "章节", "☰"],
    ["ai", "AI", "◇"],
    ["settings", "我的", "◎"]
  ];
  const activeView = state.view === "ritual" ? "chapter" : state.view === "lens" ? "meadow" : ["guide", "studio", "review", "library", "qa", "install", "launch", "account"].includes(state.view) ? "settings" : state.view;
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
      <p>当前 v32 已把媒体优先入口、移动端视觉质感、Bento 首页、Journal 时间轴、照片墙/地图切换、上架就绪路径和原生移交账本串起来：用户可以从顶部 Memory Camera、底部“＋影像”、首次进入、Quick Mark 或媒体墙直接选择影像；也可以进入 Launch Readiness 看到预检、导出校验、删除回执、App Store 审核包和 Native Handoff Ledger。</p>
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
