import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { Type } from "@sinclair/typebox";

const DEFAULT_MCP_URL = "http://localhost:4000/tidewave/mcp";
const MCP_PROTOCOL_VERSION = "2025-03-26";

let nextId = 1;
let initialized = false;
let initializePromise: Promise<void> | null = null;

function getMcpUrl() {
  return process.env.TIDEWAVE_MCP_URL ?? DEFAULT_MCP_URL;
}

async function mcpRequest(method: string, params: Record<string, unknown>, signal?: AbortSignal) {
  const response = await fetch(getMcpUrl(), {
    method: "POST",
    headers: {
      "content-type": "application/json",
    },
    body: JSON.stringify({
      jsonrpc: "2.0",
      id: nextId++,
      method,
      params,
    }),
    signal,
  });

  if (!response.ok) {
    throw new Error(`Tidewave MCP request failed with HTTP ${response.status}`);
  }

  const payload = (await response.json()) as {
    result?: Record<string, unknown>;
    error?: { message?: string; data?: unknown };
  };

  if (payload.error) {
    const details = payload.error.data ? `\n${JSON.stringify(payload.error.data, null, 2)}` : "";
    throw new Error(`${payload.error.message ?? "Unknown MCP error"}${details}`);
  }

  return payload.result ?? {};
}

async function ensureInitialized(signal?: AbortSignal) {
  if (initialized) return;
  if (initializePromise) return initializePromise;

  initializePromise = (async () => {
    await mcpRequest(
      "initialize",
      {
        protocolVersion: MCP_PROTOCOL_VERSION,
        capabilities: {},
        clientInfo: {
          name: "pi-tidewave-extension",
          version: "0.1.0",
        },
      },
      signal,
    );

    await mcpRequest("notifications/initialized", {}, signal);
    initialized = true;
  })();

  try {
    await initializePromise;
  } finally {
    initializePromise = null;
  }
}

type McpContentItem = { type?: string; text?: string };

type McpToolResult = {
  content?: McpContentItem[];
  isError?: boolean;
  _meta?: Record<string, unknown>;
};

function resultText(result: McpToolResult) {
  const text =
    result.content
      ?.filter((item) => item.type === "text" && typeof item.text === "string")
      .map((item) => item.text?.trimEnd())
      .filter(Boolean)
      .join("\n\n") ?? "";

  return text || "No output";
}

async function callTidewaveTool(
  name: string,
  args: Record<string, unknown>,
  signal?: AbortSignal,
): Promise<{ text: string; details: McpToolResult }> {
  await ensureInitialized(signal);

  const result = (await mcpRequest(
    "tools/call",
    {
      name,
      arguments: args,
    },
    signal,
  )) as McpToolResult;

  const text = resultText(result);

  if (result.isError) {
    throw new Error(text);
  }

  return { text, details: result };
}

export default function tidewaveExtension(pi: ExtensionAPI) {
  pi.on("session_start", async (_event, ctx) => {
    try {
      await ensureInitialized();
      if (ctx.hasUI) {
        ctx.ui.setStatus("tidewave", ctx.ui.theme.fg("accent", "🌊 Tidewave MCP connected"));
      }
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      if (ctx.hasUI) {
        ctx.ui.setStatus("tidewave", ctx.ui.theme.fg("warning", "🌊 Tidewave MCP unavailable"));
        ctx.ui.notify(`Tidewave MCP unavailable: ${message}`, "warning");
      }
    }
  });

  pi.registerTool({
    name: "project_eval",
    label: "Project Eval",
    description: "Evaluate Elixir code inside the running application via Tidewave.",
    promptSnippet: "Evaluate Elixir code in the running Phoenix app context",
    promptGuidelines: [
      "Use this tool whenever you need to evaluate Elixir code, test runtime behavior, or inspect in-memory application state.",
      "Prefer this over shelling out to iex, mix run, or other bash-based Elixir execution.",
      "IEx helpers are available in the evaluation context, such as exports(Module).",
    ],
    parameters: Type.Object({
      code: Type.String({ description: "The Elixir code to evaluate" }),
      arguments: Type.Optional(
        Type.Array(Type.Any(), {
          description: "Optional arguments exposed inside the evaluation as `arguments`",
        }),
      ),
      timeout: Type.Optional(
        Type.Integer({ description: "Optional timeout in milliseconds. Defaults to 30000" }),
      ),
    }),
    async execute(_toolCallId, params, signal) {
      const { text, details } = await callTidewaveTool("project_eval", params, signal);
      return {
        content: [{ type: "text", text }],
        details,
      };
    },
  });

  pi.registerTool({
    name: "get_logs",
    label: "Get Logs",
    description: "Read recent application logs captured by Tidewave.",
    promptSnippet: "Read recent application logs from the running Phoenix app",
    promptGuidelines: [
      "Use this after reproducing issues or after project_eval calls when you need fresh logs.",
      "Prefer grep and level filters when you are looking for a specific error or event.",
    ],
    parameters: Type.Object({
      tail: Type.Integer({ description: "The number of log entries to return from the end of the log" }),
      grep: Type.Optional(
        Type.String({ description: "Optional case-insensitive regex to filter logs" }),
      ),
      level: Type.Optional(
        Type.String({
          description: "Optional log level filter",
          enum: ["emergency", "alert", "critical", "error", "warning", "notice", "info", "debug"],
        }),
      ),
    }),
    async execute(_toolCallId, params, signal) {
      const { text, details } = await callTidewaveTool("get_logs", params, signal);
      return {
        content: [{ type: "text", text }],
        details,
      };
    },
  });

  pi.registerTool({
    name: "get_docs",
    label: "Get Docs",
    description: "Get docs for a module, function, or callback from the running project and dependencies.",
    promptSnippet: "Fetch documentation for a known Elixir module or function",
    promptGuidelines: [
      "Use this when you already know the module or function reference.",
      "Prefer this over grepping dependency source when the reference is known.",
    ],
    parameters: Type.Object({
      reference: Type.String({
        description: "Module, Module.function, Module.function/arity, or c:Module.callback/arity",
      }),
    }),
    async execute(_toolCallId, params, signal) {
      const { text, details } = await callTidewaveTool("get_docs", params, signal);
      return {
        content: [{ type: "text", text }],
        details,
      };
    },
  });

  pi.registerTool({
    name: "get_source_location",
    label: "Get Source Location",
    description: "Find the source file for a module, function, callback, or dependency package.",
    promptSnippet: "Find the source file for a known Elixir module, function, or dependency",
    promptGuidelines: [
      "Use this when you know the reference and want to jump directly to source.",
      "Prefer this over broad filesystem search when the target module or function is known.",
    ],
    parameters: Type.Object({
      reference: Type.String({
        description: "Module, Module.function, Module.function/arity, callback, or dep:package_name",
      }),
    }),
    async execute(_toolCallId, params, signal) {
      const { text, details } = await callTidewaveTool("get_source_location", params, signal);
      return {
        content: [{ type: "text", text }],
        details,
      };
    },
  });

  pi.registerTool({
    name: "search_package_docs",
    label: "Search Package Docs",
    description: "Search HexDocs for the project dependencies or an explicit package list.",
    promptSnippet: "Search HexDocs across project dependencies or selected packages",
    promptGuidelines: [
      "Use this when you need package documentation but do not yet know the exact module or function reference.",
      "Use get_docs first when you already know the exact reference.",
    ],
    parameters: Type.Object({
      q: Type.String({ description: "The search query" }),
      packages: Type.Optional(
        Type.Array(Type.String(), {
          description: "Optional package names to restrict the search to",
        }),
      ),
    }),
    async execute(_toolCallId, params, signal) {
      const { text, details } = await callTidewaveTool("search_package_docs", params, signal);
      return {
        content: [{ type: "text", text }],
        details,
      };
    },
  });

  pi.registerTool({
    name: "execute_sql_query",
    label: "Execute SQL Query",
    description: "Execute SQL against the configured Ecto repo via Tidewave.",
    promptSnippet: "Execute SQL against the local development database",
    promptGuidelines: [
      "Use this to verify database state directly when debugging or validating changes.",
      "Cast UUIDs to text when needed, because low-level database output may return raw binaries.",
      "Use LIMIT and OFFSET for large result sets.",
    ],
    parameters: Type.Object({
      query: Type.String({ description: "The SQL query to execute" }),
      repo: Type.Optional(Type.String({ description: "Optional Ecto repo module name" })),
      arguments: Type.Optional(
        Type.Array(Type.Any(), {
          description: "Optional query parameters matching placeholders in the SQL query",
        }),
      ),
    }),
    async execute(_toolCallId, params, signal) {
      const { text, details } = await callTidewaveTool("execute_sql_query", params, signal);
      return {
        content: [{ type: "text", text }],
        details,
      };
    },
  });

  pi.registerTool({
    name: "get_ecto_schemas",
    label: "Get Ecto Schemas",
    description: "List Ecto schema modules available in the current project.",
    promptSnippet: "List available Ecto schema modules in the project",
    promptGuidelines: [
      "Use this when you need to discover available schemas before inspecting specific modules.",
    ],
    parameters: Type.Object({}),
    async execute(_toolCallId, params, signal) {
      const { text, details } = await callTidewaveTool("get_ecto_schemas", params, signal);
      return {
        content: [{ type: "text", text }],
        details,
      };
    },
  });
}
