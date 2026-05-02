import type { ExtensionAPI, ExtensionContext } from "@mariozechner/pi-coding-agent";

const POLL_INTERVAL_MS = 60_000;
const MIN_EVENT_REFRESH_MS = 15_000;
const STALE_THRESHOLD_MS = 15 * 60_000;
const OPENAI_CODEX_PROVIDER = "openai-codex";
const DEFAULT_CHATGPT_BASE_URL = "https://chatgpt.com/backend-api/";

type UsageWindow = {
  label: string;
  remainingPercent: number;
  resetsAtMs?: number;
};

type LimitsSnapshot = {
  source: "live" | "cached";
  capturedAtMs: number;
  planType?: string;
  primary?: UsageWindow;
  secondary?: UsageWindow;
  stale: boolean;
  error?: string;
};

type PiOpenAICodexOAuthCredential = {
  type: "oauth";
  access?: string;
  refresh?: string;
  expires?: number;
  accountId?: string;
};

type UsagePayloadWindow = {
  used_percent?: number;
  limit_window_seconds?: number;
  reset_at?: number;
};

type UsagePayload = {
  plan_type?: string;
  rate_limit?: {
    primary_window?: UsagePayloadWindow | null;
    secondary_window?: UsagePayloadWindow | null;
  } | null;
};

export default function codexPlanLimitsExtension(pi: ExtensionAPI) {
  let latestSnapshot: LimitsSnapshot | undefined;
  let refreshInFlight: Promise<void> | undefined;
  let pollTimer: ReturnType<typeof setInterval> | undefined;
  let activeCtx: ExtensionContext | undefined;
  let lastRefreshStartedAt = 0;

  async function refresh(ctx: ExtensionContext, options?: { notify?: boolean; force?: boolean }): Promise<void> {
    if (!shouldShowForModel(ctx)) {
      clearStatus(ctx);
      return;
    }

    const now = Date.now();
    if (!options?.force && now - lastRefreshStartedAt < 2_000) {
      return refreshInFlight;
    }
    if (refreshInFlight) {
      return refreshInFlight;
    }

    lastRefreshStartedAt = now;
    refreshInFlight = (async () => {
      try {
        const snapshot = await loadBestSnapshot(ctx, latestSnapshot);
        latestSnapshot = snapshot;
        render(ctx);
        if (options?.notify && ctx.hasUI) {
          ctx.ui.notify(snapshotNotification(snapshot), snapshot.stale ? "warning" : "info");
        }
      } catch (error) {
        const message = error instanceof Error ? error.message : "Unknown error";
        latestSnapshot = latestSnapshot
          ? {
              ...latestSnapshot,
              source: "cached",
              stale: true,
              error: message,
            }
          : {
              source: "cached",
              capturedAtMs: Date.now(),
              stale: true,
              error: message,
            };
        render(ctx);
        if (options?.notify && ctx.hasUI) {
          ctx.ui.notify(`Codex limits unavailable: ${message}`, "warning");
        }
      } finally {
        refreshInFlight = undefined;
      }
    })();

    return refreshInFlight;
  }

  function render(ctx: ExtensionContext): void {
    activeCtx = ctx;
    if (!shouldShowForModel(ctx)) {
      clearStatus(ctx);
      return;
    }
    setStatus(ctx, latestSnapshot);
  }

  function setStatus(ctx: ExtensionContext, snapshot: LimitsSnapshot | undefined): void {
    if (!ctx.hasUI) {
      return;
    }
    ctx.ui.setStatus("codex-limits", buildStatusText(ctx, snapshot, pi.getThinkingLevel()));
  }

  function clearStatus(ctx: ExtensionContext): void {
    if (!ctx.hasUI) {
      return;
    }
    ctx.ui.setStatus("codex-limits", undefined);
  }

  function snapshotNotification(snapshot: LimitsSnapshot): string {
    const source = snapshot.source === "live" ? "live" : "cached";
    const parts: string[] = [];
    if (snapshot.primary) {
      parts.push(`${snapshot.primary.label} ${formatPercent(snapshot.primary.remainingPercent)} left`);
    }
    if (snapshot.secondary) {
      parts.push(`${snapshot.secondary.label} ${formatPercent(snapshot.secondary.remainingPercent)} left`);
    }
    return parts.length > 0
      ? `Codex limits refreshed (${source}): ${parts.join(" · ")}`
      : `Codex limits refreshed (${source})`;
  }

  function startPolling(ctx: ExtensionContext): void {
    stopPolling();
    pollTimer = setInterval(() => {
      void refresh(ctx);
    }, POLL_INTERVAL_MS);
  }

  function stopPolling(): void {
    if (pollTimer) {
      clearInterval(pollTimer);
      pollTimer = undefined;
    }
  }

  async function refreshIfDue(ctx: ExtensionContext): Promise<void> {
    if (!shouldShowForModel(ctx)) {
      clearStatus(ctx);
      return;
    }
    if (Date.now() - lastRefreshStartedAt < MIN_EVENT_REFRESH_MS) {
      render(ctx);
      return;
    }
    await refresh(ctx);
  }

  pi.on("session_start", async (_event, ctx) => {
    activeCtx = ctx;
    startPolling(ctx);
    if (shouldShowForModel(ctx)) {
      await refresh(ctx, { force: true });
    } else {
      clearStatus(ctx);
    }
  });

  pi.on("model_select", async (_event, ctx) => {
    activeCtx = ctx;
    if (!shouldShowForModel(ctx)) {
      clearStatus(ctx);
      return;
    }
    await refresh(ctx, { force: true });
  });

  pi.on("turn_end", async (_event, ctx) => {
    activeCtx = ctx;
    await refreshIfDue(ctx);
  });

  pi.on("session_shutdown", async () => {
    stopPolling();
    if (activeCtx?.hasUI) {
      activeCtx.ui.setStatus("codex-limits", undefined);
    }
    activeCtx = undefined;
  });
}

async function loadBestSnapshot(
  ctx: ExtensionContext,
  previousSnapshot: LimitsSnapshot | undefined,
): Promise<LimitsSnapshot> {
  try {
    return await fetchLiveSnapshotFromPiAuth(ctx);
  } catch (error) {
    if (!previousSnapshot) {
      throw error;
    }
    const message = error instanceof Error ? error.message : String(error);
    return {
      ...previousSnapshot,
      source: "cached",
      stale: Date.now() - previousSnapshot.capturedAtMs > STALE_THRESHOLD_MS,
      error: message,
    };
  }
}

async function fetchLiveSnapshotFromPiAuth(ctx: ExtensionContext): Promise<LimitsSnapshot> {
  if (!ctx.model || ctx.model.provider !== OPENAI_CODEX_PROVIDER) {
    throw new Error("Active Pi model is not an OpenAI Codex subscription model");
  }

  const authResult = await ctx.modelRegistry.getApiKeyAndHeaders(ctx.model);
  if (!authResult.ok) {
    throw new Error(authResult.error);
  }

  const credential = ctx.modelRegistry.authStorage.get(OPENAI_CODEX_PROVIDER) as PiOpenAICodexOAuthCredential | undefined;
  const accessToken = credential?.access;
  const accountId = credential?.accountId;
  if (!accessToken || !accountId) {
    throw new Error("Missing Pi OpenAI Codex OAuth credentials. Run /login and select OpenAI Codex.");
  }

  const baseUrl = ensureTrailingSlash(process.env.PI_CODEX_CHATGPT_BASE_URL ?? DEFAULT_CHATGPT_BASE_URL);
  const usageUrl = new URL("wham/usage", baseUrl).toString();
  const response = await fetch(usageUrl, {
    method: "GET",
    headers: {
      Authorization: `Bearer ${accessToken}`,
      "chatgpt-account-id": accountId,
      "Content-Type": "application/json",
    },
    signal: AbortSignal.timeout(15_000),
  });

  if (!response.ok) {
    const body = await safeReadText(response);
    throw new Error(`Usage request failed (${response.status}): ${truncateInline(body, 200)}`);
  }

  const payload = (await response.json()) as UsagePayload;
  const snapshot: LimitsSnapshot = {
    source: "live",
    capturedAtMs: Date.now(),
    planType: normalizePlanType(payload.plan_type),
    primary: mapWindow(payload.rate_limit?.primary_window, "5h"),
    secondary: mapWindow(payload.rate_limit?.secondary_window, "Weekly"),
    stale: false,
  };

  if (!snapshot.primary && !snapshot.secondary) {
    throw new Error("Usage response did not contain 5h/weekly windows");
  }

  return snapshot;
}

function shouldShowForModel(ctx: ExtensionContext): boolean {
  return Boolean(ctx.hasUI && ctx.model?.provider === OPENAI_CODEX_PROVIDER && ctx.modelRegistry.isUsingOAuth(ctx.model));
}

function mapWindow(window: UsagePayloadWindow | null | undefined, fallbackLabel: string): UsageWindow | undefined {
  if (!window) {
    return undefined;
  }
  const usedPercent = sanitizeNumber(window.used_percent);
  const resetsAtMs = secondsToMs(window.reset_at);
  const windowMinutes = secondsToMinutes(window.limit_window_seconds);
  if (usedPercent === undefined && resetsAtMs === undefined && windowMinutes === undefined) {
    return undefined;
  }
  const remainingPercent = clamp(100 - (usedPercent ?? 0), 0, 100);
  return {
    label: labelForWindow(windowMinutes, fallbackLabel),
    remainingPercent,
    resetsAtMs,
  };
}

function buildStatusText(
  ctx: ExtensionContext,
  snapshot: LimitsSnapshot | undefined,
  thinkingLevel: string,
): string {
  const theme = ctx.ui.theme;
  const dotColor = snapshot?.stale ? "warning" : "accent";
  const dot = theme.fg(dotColor, "●");
  const label = theme.fg("dim", " codex ");

  const parts = [
    formatStatusWindow(theme, snapshot?.primary?.label ?? "5h", snapshot?.primary?.remainingPercent ?? 0, snapshot?.primary?.resetsAtMs),
    formatStatusWindow(theme, snapshot?.secondary?.label ?? "W", snapshot?.secondary?.remainingPercent ?? 0, snapshot?.secondary?.resetsAtMs),
  ];

  const source = snapshot?.source === "cached" ? theme.fg("warning", " cached") : "";
  const mode = ctx.model?.reasoning ? theme.fg("dim", ` ${thinkingLevel === "off" ? "thinking off" : thinkingLevel}`) : "";
  return `${dot}${label}${parts.join(theme.fg("dim", " · "))}${source}${mode}`;
}

function formatStatusWindow(
  theme: ExtensionContext["ui"]["theme"],
  label: string,
  remainingPercent: number,
  resetsAtMs: number | undefined,
): string {
  const resetText = resetsAtMs ? formatResetTime(label, resetsAtMs) : "--:--";
  const percentColor = remainingPercent <= 10 ? "error" : remainingPercent <= 25 ? "warning" : "success";
  return `${theme.fg("dim", `${label} `)}${theme.fg(percentColor, formatPercent(remainingPercent))}${theme.fg("dim", ` ↺${resetText}`)}`;
}

function formatResetTime(label: string, timestampMs: number): string {
  const date = new Date(timestampMs);
  const now = new Date();
  if (label === "Weekly" || label === "W") {
    return `${formatMonth(date)} ${pad2(date.getDate())} ${formatTime(date)}`;
  }
  const dayDiff = differenceInCalendarDays(now, date);
  if (dayDiff === 0) {
    return formatTime(date);
  }
  if (dayDiff > 0 && dayDiff < 7) {
    return `${formatWeekday(date)} ${formatTime(date)}`;
  }
  return `${formatMonth(date)} ${pad2(date.getDate())} ${formatTime(date)}`;
}

function differenceInCalendarDays(from: Date, to: Date): number {
  const fromStart = new Date(from.getFullYear(), from.getMonth(), from.getDate()).getTime();
  const toStart = new Date(to.getFullYear(), to.getMonth(), to.getDate()).getTime();
  return Math.round((toStart - fromStart) / 86_400_000);
}

function formatWeekday(date: Date): string {
  return ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"][date.getDay()] ?? "";
}

function formatMonth(date: Date): string {
  return ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"][date.getMonth()] ?? "";
}

function formatTime(date: Date): string {
  return `${pad2(date.getHours())}:${pad2(date.getMinutes())}`;
}

function pad2(value: number): string {
  return value.toString().padStart(2, "0");
}

function formatPercent(value: number): string {
  return `${Math.round(value)}%`;
}

function labelForWindow(windowMinutes: number | undefined, fallbackLabel: string): string {
  if (windowMinutes === 300) {
    return "5h";
  }
  if (windowMinutes === 10_080) {
    return "Weekly";
  }
  if (windowMinutes === undefined) {
    return fallbackLabel;
  }
  if (windowMinutes >= 60 && windowMinutes % 60 === 0) {
    return `${windowMinutes / 60}h`;
  }
  return `${windowMinutes}m`;
}

function sanitizeNumber(value: number | undefined): number | undefined {
  if (typeof value !== "number" || !Number.isFinite(value)) {
    return undefined;
  }
  return value;
}

function secondsToMinutes(value: number | undefined): number | undefined {
  const seconds = sanitizeNumber(value);
  if (seconds === undefined || seconds <= 0) {
    return undefined;
  }
  return Math.ceil(seconds / 60);
}

function secondsToMs(value: number | undefined): number | undefined {
  const seconds = sanitizeNumber(value);
  if (seconds === undefined || seconds <= 0) {
    return undefined;
  }
  return seconds * 1000;
}

function clamp(value: number, min: number, max: number): number {
  return Math.min(Math.max(value, min), max);
}

function normalizePlanType(value: string | undefined): string | undefined {
  if (!value) {
    return undefined;
  }
  return value.replace(/_/g, " ");
}

function ensureTrailingSlash(value: string): string {
  return value.endsWith("/") ? value : `${value}/`;
}

function truncateInline(value: string, limit: number): string {
  const normalized = value.replace(/\s+/g, " ").trim();
  if (normalized.length <= limit) {
    return normalized;
  }
  return `${normalized.slice(0, limit - 1)}…`;
}

async function safeReadText(response: Response): Promise<string> {
  try {
    return await response.text();
  } catch {
    return "";
  }
}
