#!/usr/bin/env bun
import { createHash, randomUUID } from 'node:crypto';
import { mkdir } from 'node:fs/promises';
import { basename, dirname, join, resolve } from 'node:path';

interface RpcMessage {
  id?: number;
  method?: string;
  result?: Record<string, unknown>;
  error?: unknown;
  params?: Record<string, unknown>;
}

interface TokenUsageEvent {
  inputTokens: number;
  cachedInputTokens: number;
  cacheWriteInputTokens: number;
  outputTokens: number;
}

const binary = valueAfter('--binary');
const evidencePath = valueAfter('--evidence');
const requireAcknowledgement = process.argv.includes('--require-ack');
if (!binary || !evidencePath) {
  console.error(
    'usage: bun run adoption/codex/e2e/same-process-reclaim.ts ' +
      '--binary <codex> --evidence <json> [--require-ack]'
  );
  process.exit(2);
}

const resolvedBinary = resolve(binary);
const resolvedEvidence = resolve(evidencePath);
const nonce = randomUUID().replaceAll('-', '').slice(0, 16).toUpperCase();
const rows = Number(process.env.CB_RECLAIM_PAYLOAD_ROWS ?? '1200');
const runDirectory = join(dirname(resolvedEvidence), `${basename(resolvedEvidence, '.json')}-cwd`);
await mkdir(runDirectory, { recursive: true });

const fromPattern = `BEGIN_CODEX_ARCHIVE_${nonce}`;
const toPattern = `END_CODEX_ARCHIVE_${[...nonce].reverse().join('')}`;
const payload = Array.from({ length: rows }, (_, index) => {
  const digest = createHash('sha256').update(`${nonce}:${index}`).digest('hex');
  return `codex-payload-row-${String(index).padStart(5, '0')} ${digest} ` +
    'completed synthetic history that must disappear from the next provider request';
}).join('\n');

const child = Bun.spawn([resolvedBinary, 'app-server', '--listen', 'stdio://'], {
  cwd: runDirectory,
  stdin: 'pipe',
  stdout: 'pipe',
  stderr: 'pipe',
  env: process.env,
});
const iterator = jsonLines(child.stdout)[Symbol.asyncIterator]();
const pending = new Map<number, {
  resolve: (message: RpcMessage) => void;
  reject: (error: Error) => void;
}>();
const notifications: RpcMessage[] = [];
let requestId = 0;
let readError: Error | undefined;

const reader = (async () => {
  try {
    while (true) {
      const next = await iterator.next();
      if (next.done) break;
      const message = next.value;
      if (typeof message.id === 'number' && pending.has(message.id)) {
        const waiter = pending.get(message.id)!;
        pending.delete(message.id);
        if (message.error !== undefined) {
          waiter.reject(new Error(`app-server RPC ${message.id} failed: ${JSON.stringify(message.error)}`));
        } else {
          waiter.resolve(message);
        }
      } else if (message.method) {
        notifications.push(message);
      }
    }
  } catch (error) {
    readError = error instanceof Error ? error : new Error(String(error));
  }
})();

let threadId = '';
let pruneTurnId = '';
try {
  await request('initialize', {
    clientInfo: {
      name: 'context_bonsai_reclaim_test',
      title: 'Context Bonsai same-process reclaim test',
      version: '1.0.0',
    },
    capabilities: {
      experimentalApi: true,
    },
  });
  notify('initialized');

  const start = await request('thread/start', {
    model: process.env.CB_CODEX_RECLAIM_MODEL ?? 'gpt-5.6-sol',
    experimentalRawEvents: true,
  });
  threadId = stringAt(start.result, ['thread', 'id']);
  if (!threadId) throw new Error(`thread/start returned no thread id: ${JSON.stringify(start)}`);

  await request('thread/inject_items', {
    threadId,
    items: [
      responseMessage('user', `${fromPattern}\n${payload}`),
      responseMessage(
        'assistant',
        `Synthetic payload ${nonce} was fully processed; this historical assistant message is archivable.`
      ),
      responseMessage(
        'user',
        `${toPattern}\nThe synthetic historical block ends at this exact marker.`
      ),
    ],
  });

  const turn = await request('turn/start', {
    threadId,
    input: [
      {
        type: 'text',
        text:
          `This is an authorized Context Bonsai integration test. Use context-bonsai-prune now. ` +
          `Set from_pattern to "${fromPattern}" and to_pattern to "${toPattern}". ` +
          `Set summary to "Completed Codex same-process reclaim payload ${nonce}; safe to archive.", ` +
          `index_terms to ["same-process-reclaim","${nonce}"], and reason to ` +
          `"provider-token accounting test". Do not use any other tool. After it completes, copy the ` +
          `exact host-generated [CONTEXT BONSAI ...] acknowledgement into your final reply. ` +
          `If there is no such acknowledgement, reply exactly NO_HOST_ACK_${nonce}.`,
      },
    ],
  });
  pruneTurnId = stringAt(turn.result, ['turn', 'id']);
  if (!pruneTurnId) throw new Error(`turn/start returned no turn id: ${JSON.stringify(turn)}`);
  await waitForNotification(
    (message) =>
      message.method === 'turn/completed' &&
      stringAt(message.params, ['turn', 'id']) === pruneTurnId,
    240_000,
    'Codex prune turn completion'
  );
} finally {
  child.stdin.end();
}

await withTimeout(reader, 15_000, 'app-server output reader');
const exitCode = await withTimeout(child.exited, 15_000, 'app-server exit');
const stderr = await new Response(child.stderr).text();
if (readError) throw readError;

const rawUsageEvents = notifications
  .filter(
    (message) =>
      message.method === 'rawResponse/completed' &&
      stringAt(message.params, ['turnId']) === pruneTurnId
  )
  .map((message) => tokenUsageAt(message.params, ['usage']))
  .filter((usage): usage is TokenUsageEvent => usage !== null && usage.inputTokens > 0);
const accumulatedUsageEvents = notifications
  .filter(
    (message) =>
      message.method === 'thread/tokenUsage/updated' &&
      stringAt(message.params, ['turnId']) === pruneTurnId
  )
  .map((message) => tokenUsageAt(message.params, ['tokenUsage', 'last']))
  .filter((usage): usage is TokenUsageEvent => usage !== null && usage.inputTokens > 0);
const beforeUsage = rawUsageEvents[0];
const afterUsage = rawUsageEvents.at(-1);
const beforeTokens = beforeUsage?.inputTokens ?? 0;
const afterTokens = rawUsageEvents.length >= 2 ? afterUsage?.inputTokens ?? 0 : 0;
const tokenDrop = beforeTokens - afterTokens;

const transcriptText = notifications
  .filter(
    (message) =>
      stringAt(message.params, ['threadId']) === threadId ||
      stringAt(message.params, ['item', 'threadId']) === threadId
  )
  .map((message) => JSON.stringify(message))
  .join('\n');
const acknowledgement =
  transcriptText.match(/\[CONTEXT BONSAI (?:ENFORCED|PENDING)[^\]]+\]/)?.[0] ?? null;
const acknowledgementFields = acknowledgement
  ? Object.fromEntries(
      [...acknowledgement.matchAll(/\b([a-z_]+)=([^\s\]]+)/g)].map((match) => [
        match[1],
        match[2],
      ])
    )
  : {};
const excludedMessages = Number(acknowledgementFields.excluded_messages ?? '0');
const pruneToolObserved = notifications.some(
  (message) =>
    message.method === 'item/completed' &&
    stringAt(message.params, ['turnId']) === pruneTurnId &&
    JSON.stringify(message.params).includes('context-bonsai-prune')
);
const tokenReclaimPassed =
  exitCode === 0 &&
  pruneToolObserved &&
  rawUsageEvents.length >= 2 &&
  beforeTokens > 0 &&
  afterTokens > 0 &&
  tokenDrop >= 10_000 &&
  afterTokens <= beforeTokens * 0.85;
const acknowledgementPassed =
  acknowledgement?.includes('[CONTEXT BONSAI ENFORCED ') === true &&
  acknowledgementFields.pid !== undefined &&
  acknowledgementFields.build_id !== undefined &&
  acknowledgementFields.archive_id !== undefined &&
  excludedMessages >= 1;
const passed = tokenReclaimPassed && (!requireAcknowledgement || acknowledgementPassed);

const evidence = {
  schema: 'context-bonsai-codex-same-process-reclaim/v1',
  timestamp: new Date().toISOString(),
  binary: resolvedBinary,
  binary_sha256: await sha256File(resolvedBinary),
  app_server_pid: child.pid,
  thread_id: threadId,
  prune_turn_id: pruneTurnId,
  nonce,
  payload_rows: rows,
  payload_characters: payload.length,
  exact_provider_usage_events: rawUsageEvents,
  accumulated_usage_events: accumulatedUsageEvents,
  provider_input_tokens_before_prune: beforeTokens,
  provider_input_tokens_after_prune: afterTokens,
  provider_input_token_drop: tokenDrop,
  provider_input_drop_percent:
    beforeTokens > 0 ? Number(((tokenDrop / beforeTokens) * 100).toFixed(2)) : 0,
  prune_tool_observed: pruneToolObserved,
  token_reclaim_passed: tokenReclaimPassed,
  acknowledgement_required: requireAcknowledgement,
  acknowledgement,
  acknowledgement_fields: acknowledgementFields,
  excluded_messages: excludedMessages,
  acknowledgement_passed: acknowledgementPassed,
  app_server_exit_code: exitCode,
  stderr: stderr.slice(0, 10_000),
  notification_methods: notifications.map((message) => message.method),
  passed,
};

await Bun.write(resolvedEvidence, `${JSON.stringify(evidence, null, 2)}\n`);
console.log(JSON.stringify(evidence, null, 2));
if (!passed) process.exit(1);

function request(method: string, params?: Record<string, unknown>): Promise<RpcMessage> {
  const id = ++requestId;
  const response = new Promise<RpcMessage>((resolveRequest, reject) => {
    pending.set(id, { resolve: resolveRequest, reject });
  });
  child.stdin.write(`${JSON.stringify({ method, id, ...(params ? { params } : {}) })}\n`);
  child.stdin.flush();
  return withTimeout(
    response,
    60_000,
    `${method} response`
  );
}

function notify(method: string, params?: Record<string, unknown>): void {
  child.stdin.write(`${JSON.stringify({ method, ...(params ? { params } : {}) })}\n`);
  child.stdin.flush();
}

async function waitForNotification(
  predicate: (message: RpcMessage) => boolean,
  milliseconds: number,
  label: string
): Promise<RpcMessage> {
  const started = Date.now();
  while (Date.now() - started < milliseconds) {
    const found = notifications.find(predicate);
    if (found) return found;
    if (readError) throw readError;
    await Bun.sleep(50);
  }
  child.kill();
  throw new Error(`${label} timed out after ${milliseconds}ms`);
}

function responseMessage(role: 'user' | 'assistant', text: string): Record<string, unknown> {
  return {
    type: 'message',
    role,
    content: [
      {
        type: role === 'user' ? 'input_text' : 'output_text',
        text,
      },
    ],
  };
}

function stringAt(value: unknown, path: string[]): string {
  let current = value;
  for (const key of path) {
    if (!current || typeof current !== 'object' || Array.isArray(current)) return '';
    current = (current as Record<string, unknown>)[key];
  }
  return typeof current === 'string' ? current : '';
}

function tokenUsageAt(value: unknown, path: string[]): TokenUsageEvent | null {
  let current = value;
  for (const key of path) {
    if (!current || typeof current !== 'object' || Array.isArray(current)) return null;
    current = (current as Record<string, unknown>)[key];
  }
  if (!current || typeof current !== 'object' || Array.isArray(current)) return null;
  const usage = current as Record<string, unknown>;
  return {
    inputTokens: numeric(usage.inputTokens),
    cachedInputTokens: numeric(usage.cachedInputTokens),
    cacheWriteInputTokens: numeric(usage.cacheWriteInputTokens),
    outputTokens: numeric(usage.outputTokens),
  };
}

function numeric(value: unknown): number {
  return typeof value === 'number' && Number.isFinite(value) ? value : 0;
}

async function* jsonLines(stream: ReadableStream<Uint8Array>): AsyncGenerator<RpcMessage> {
  const reader = stream.getReader();
  const decoder = new TextDecoder();
  let buffer = '';
  while (true) {
    const { value, done } = await reader.read();
    if (done) break;
    buffer += decoder.decode(value, { stream: true });
    let newline = buffer.indexOf('\n');
    while (newline >= 0) {
      const line = buffer.slice(0, newline).trim();
      buffer = buffer.slice(newline + 1);
      if (line) yield JSON.parse(line) as RpcMessage;
      newline = buffer.indexOf('\n');
    }
  }
  const tail = buffer.trim();
  if (tail) yield JSON.parse(tail) as RpcMessage;
}

async function sha256File(path: string): Promise<string> {
  const hasher = new Bun.CryptoHasher('sha256');
  const stream = Bun.file(path).stream();
  for await (const chunk of stream) hasher.update(chunk);
  return hasher.digest('hex');
}

function valueAfter(flag: string): string | undefined {
  const index = process.argv.indexOf(flag);
  return index >= 0 ? process.argv[index + 1] : undefined;
}

async function withTimeout<T>(
  promise: Promise<T>,
  milliseconds: number,
  label: string
): Promise<T> {
  return await new Promise<T>((resolvePromise, reject) => {
    const timer = setTimeout(() => {
      child.kill();
      reject(new Error(`${label} timed out after ${milliseconds}ms`));
    }, milliseconds);
    promise.then(
      (value) => {
        clearTimeout(timer);
        resolvePromise(value);
      },
      (error) => {
        clearTimeout(timer);
        reject(error);
      }
    );
  });
}
