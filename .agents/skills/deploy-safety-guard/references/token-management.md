# LLM 토큰 관리 (Token Management) 가이드

LLM API 비용 통제와 안정적인 운영을 위한 토큰 카운팅, 입력 검증, 컨텍스트 압축, 비용 예산 관리, 모델 선택 전략, 스트리밍 응답 처리를 다룬다.

---

## 핵심 개념

### 토큰 비용 구조

| 모델 | 입력 (1M tokens) | 출력 (1M tokens) | 용도 |
|------|-----------------|-----------------|------|
| GPT-4o | $2.50 | $10.00 | 복잡한 추론 |
| GPT-4o-mini | $0.15 | $0.60 | 일반 대화 |
| Claude Sonnet 4.5 | $3.00 | $15.00 | 복잡한 추론 |
| Claude Haiku 4.5 | $0.80 | $4.00 | 빠른 응답 |

### 비용 폭주 시나리오

| 시나리오 | 예상 비용 | 예방 방법 |
|---------|----------|----------|
| max_tokens 미설정 | 건당 $0.10+ | max_tokens 명시 |
| 입력 검증 없음 | 건당 $1.00+ | 토큰 수 제한 |
| 무한 루프 호출 | 시간당 $100+ | Rate Limiting |
| 컨텍스트 누적 | 대화당 $5.00+ | 컨텍스트 압축 |

---

## 구현 패턴

### Before: 비용 통제 없는 LLM 호출

```typescript
// max_tokens 미설정 → 모델이 최대 길이까지 생성
// 입력 검증 없음 → 10만 토큰 입력도 허용
const response = await openai.chat.completions.create({
  model: "gpt-4o",
  messages: [{ role: "user", content: userInput }],
});
```

### After: 안전한 LLM 호출 래퍼

```typescript
// lib/llm-client.ts
import { encoding_for_model } from "tiktoken";

const encoder = encoding_for_model("gpt-4o");

// 모델별 설정
const MODEL_CONFIG = {
  "gpt-4o": { maxContext: 128000, maxOutput: 16384, costPerInputToken: 0.0000025, costPerOutputToken: 0.00001 },
  "gpt-4o-mini": { maxContext: 128000, maxOutput: 16384, costPerInputToken: 0.00000015, costPerOutputToken: 0.0000006 },
  "claude-sonnet-4-5-20250929": { maxContext: 200000, maxOutput: 8192, costPerInputToken: 0.000003, costPerOutputToken: 0.000015 },
  "claude-haiku-4-5-20251001": { maxContext: 200000, maxOutput: 8192, costPerInputToken: 0.0000008, costPerOutputToken: 0.000004 },
} as const;

type ModelId = keyof typeof MODEL_CONFIG;

interface LLMCallOptions {
  model: ModelId;
  messages: Array<{ role: string; content: string }>;
  maxOutputTokens?: number;
  maxInputTokens?: number;
  temperature?: number;
}

export function countTokens(text: string): number {
  return encoder.encode(text).length;
}

export function countMessagesTokens(
  messages: Array<{ role: string; content: string }>
): number {
  let total = 0;
  for (const msg of messages) {
    total += 4; // 메시지 오버헤드
    total += countTokens(msg.content);
    total += countTokens(msg.role);
  }
  total += 2; // 프라이밍
  return total;
}

export async function callLLM(options: LLMCallOptions) {
  const {
    model,
    messages,
    maxOutputTokens = 1000,
    maxInputTokens = 4000,
    temperature = 0.7,
  } = options;

  const config = MODEL_CONFIG[model];

  // 1. 입력 토큰 수 검증
  const inputTokens = countMessagesTokens(messages);
  if (inputTokens > maxInputTokens) {
    throw new Error(
      `Input too long: ${inputTokens} tokens (max: ${maxInputTokens})`
    );
  }

  // 2. 컨텍스트 윈도우 초과 방지
  if (inputTokens + maxOutputTokens > config.maxContext) {
    throw new Error(
      `Total tokens would exceed context window: ${inputTokens} + ${maxOutputTokens} > ${config.maxContext}`
    );
  }

  // 3. 예상 비용 계산
  const estimatedCost =
    inputTokens * config.costPerInputToken +
    maxOutputTokens * config.costPerOutputToken;

  // 4. API 호출
  const response = await openai.chat.completions.create({
    model,
    messages,
    max_tokens: maxOutputTokens,
    temperature,
  });

  // 5. 실제 사용량 로깅
  const usage = response.usage;
  if (usage) {
    const actualCost =
      usage.prompt_tokens * config.costPerInputToken +
      usage.completion_tokens * config.costPerOutputToken;

    console.log(
      `LLM Usage [${model}]: input=${usage.prompt_tokens} output=${usage.completion_tokens} total=${usage.total_tokens} cost=$${actualCost.toFixed(4)}`
    );

    // 비용 메트릭 기록 (Sentry/DataDog 등)
    trackLLMUsage({
      model,
      inputTokens: usage.prompt_tokens,
      outputTokens: usage.completion_tokens,
      cost: actualCost,
    });
  }

  return response;
}
```

### tiktoken으로 토큰 카운팅

```typescript
// lib/token-counter.ts
import { encoding_for_model, type TiktokenModel } from "tiktoken";

// 인코더 캐싱 (생성 비용 높음)
const encoderCache = new Map<string, ReturnType<typeof encoding_for_model>>();

function getEncoder(model: TiktokenModel) {
  if (!encoderCache.has(model)) {
    encoderCache.set(model, encoding_for_model(model));
  }
  return encoderCache.get(model)!;
}

export function countTokens(text: string, model: TiktokenModel = "gpt-4o"): number {
  const encoder = getEncoder(model);
  return encoder.encode(text).length;
}

// 입력 제한 검증 유틸
export function validateInput(
  text: string,
  maxTokens: number,
  model: TiktokenModel = "gpt-4o"
): { valid: boolean; tokenCount: number; error?: string } {
  const tokenCount = countTokens(text, model);
  if (tokenCount > maxTokens) {
    return {
      valid: false,
      tokenCount,
      error: `Input is ${tokenCount} tokens, exceeds limit of ${maxTokens}`,
    };
  }
  return { valid: true, tokenCount };
}
```

### 동적 max_tokens 설정

```typescript
// 남은 컨텍스트에 따라 max_tokens 동적 조정
function calculateMaxOutputTokens(
  inputTokens: number,
  modelMaxContext: number,
  desiredOutput: number = 2000
): number {
  const available = modelMaxContext - inputTokens - 100; // 여유분 100
  return Math.min(desiredOutput, Math.max(available, 100));
}

// 사용
const inputTokens = countMessagesTokens(messages);
const maxOutput = calculateMaxOutputTokens(inputTokens, 128000, 2000);

const response = await openai.chat.completions.create({
  model: "gpt-4o",
  messages,
  max_tokens: maxOutput,
});
```

### 컨텍스트 압축/요약 전략

```typescript
// lib/context-compressor.ts

// 전략 1: 오래된 메시지 요약
async function compressConversation(
  messages: Array<{ role: string; content: string }>,
  maxTokens: number = 4000
): Promise<Array<{ role: string; content: string }>> {
  const totalTokens = countMessagesTokens(messages);
  if (totalTokens <= maxTokens) return messages;

  // 시스템 메시지 + 최근 N개 보존
  const systemMessage = messages.find((m) => m.role === "system");
  const recentMessages = messages.slice(-6); // 최근 3턴 보존

  // 나머지 메시지 요약
  const oldMessages = messages.slice(
    systemMessage ? 1 : 0,
    -6
  );

  if (oldMessages.length === 0) return messages;

  const summary = await callLLM({
    model: "gpt-4o-mini", // 요약은 저렴한 모델 사용
    messages: [
      {
        role: "system",
        content: "Summarize the following conversation in 2-3 sentences, preserving key facts and decisions.",
      },
      {
        role: "user",
        content: oldMessages.map((m) => `${m.role}: ${m.content}`).join("\n"),
      },
    ],
    maxOutputTokens: 200,
  });

  const summaryText = summary.choices[0].message.content ?? "";

  return [
    ...(systemMessage ? [systemMessage] : []),
    { role: "system", content: `Previous conversation summary: ${summaryText}` },
    ...recentMessages,
  ];
}

// 전략 2: 슬라이딩 윈도우 (단순하지만 효과적)
function slidingWindowMessages(
  messages: Array<{ role: string; content: string }>,
  maxTokens: number
): Array<{ role: string; content: string }> {
  const systemMessage = messages.find((m) => m.role === "system");
  const nonSystemMessages = messages.filter((m) => m.role !== "system");

  const result: Array<{ role: string; content: string }> = [];
  let tokenCount = systemMessage ? countTokens(systemMessage.content) + 4 : 0;

  // 최신 메시지부터 역순으로 추가
  for (let i = nonSystemMessages.length - 1; i >= 0; i--) {
    const msg = nonSystemMessages[i];
    const msgTokens = countTokens(msg.content) + 4;
    if (tokenCount + msgTokens > maxTokens) break;
    result.unshift(msg);
    tokenCount += msgTokens;
  }

  if (systemMessage) result.unshift(systemMessage);
  return result;
}
```

### 월간 비용 예산 + 알림

```typescript
// lib/cost-tracker.ts
import { Redis } from "@upstash/redis";

const redis = Redis.fromEnv();
const MONTHLY_BUDGET_USD = 100;
const WARNING_THRESHOLD = 0.8; // 80%

export async function trackLLMUsage(usage: {
  model: string;
  inputTokens: number;
  outputTokens: number;
  cost: number;
}) {
  const monthKey = `llm-cost:${new Date().toISOString().slice(0, 7)}`; // e.g., llm-cost:2026-02

  // 월간 누적 비용 업데이트
  const totalCost = await redis.incrbyfloat(monthKey, usage.cost);

  // 월 초 TTL 설정 (최초 기록 시)
  if (totalCost === usage.cost) {
    await redis.expire(monthKey, 35 * 24 * 60 * 60); // 35일
  }

  // 예산 경고
  if (totalCost >= MONTHLY_BUDGET_USD) {
    console.error(
      `LLM BUDGET EXCEEDED: $${totalCost.toFixed(2)} / $${MONTHLY_BUDGET_USD}`
    );
    // Sentry 알림 또는 Slack 알림
    await sendAlert(`LLM 월간 예산 초과: $${totalCost.toFixed(2)}`);
  } else if (totalCost >= MONTHLY_BUDGET_USD * WARNING_THRESHOLD) {
    console.warn(
      `LLM budget warning: $${totalCost.toFixed(2)} / $${MONTHLY_BUDGET_USD} (${((totalCost / MONTHLY_BUDGET_USD) * 100).toFixed(0)}%)`
    );
  }

  return { totalCost, budget: MONTHLY_BUDGET_USD, remaining: MONTHLY_BUDGET_USD - totalCost };
}

// 예산 초과 시 API 차단
export async function checkBudget(): Promise<boolean> {
  const monthKey = `llm-cost:${new Date().toISOString().slice(0, 7)}`;
  const totalCost = (await redis.get<number>(monthKey)) ?? 0;
  return totalCost < MONTHLY_BUDGET_USD;
}
```

### 모델 선택 전략 (라우터)

```typescript
// lib/model-router.ts

interface TaskClassification {
  complexity: "simple" | "moderate" | "complex";
  requiresReasoning: boolean;
  maxInputTokens: number;
}

function classifyTask(prompt: string): TaskClassification {
  const tokenCount = countTokens(prompt);

  // 간단한 분류 (프로덕션에서는 더 정교하게)
  if (tokenCount < 500 && !prompt.includes("분석") && !prompt.includes("비교")) {
    return { complexity: "simple", requiresReasoning: false, maxInputTokens: tokenCount };
  }
  if (tokenCount > 5000 || prompt.includes("분석") || prompt.includes("비교")) {
    return { complexity: "complex", requiresReasoning: true, maxInputTokens: tokenCount };
  }
  return { complexity: "moderate", requiresReasoning: false, maxInputTokens: tokenCount };
}

function selectModel(task: TaskClassification): ModelId {
  // 비용 최적화: 작업 복잡도에 맞는 모델 선택
  if (task.complexity === "simple") return "gpt-4o-mini";
  if (task.complexity === "complex") return "gpt-4o";
  return "gpt-4o-mini"; // moderate도 mini로 충분한 경우가 많음
}
```

### 스트리밍 응답 + 에러 핸들링

```typescript
// app/api/chat/route.ts
import { OpenAIStream, StreamingTextResponse } from "ai";
import { callLLMStream } from "@/lib/llm-client";

export async function POST(request: Request) {
  const { messages } = await request.json();

  // 입력 검증
  const inputTokens = countMessagesTokens(messages);
  if (inputTokens > 8000) {
    return Response.json(
      { error: "Conversation too long. Please start a new chat." },
      { status: 400 }
    );
  }

  try {
    const response = await openai.chat.completions.create({
      model: "gpt-4o-mini",
      messages,
      max_tokens: 1000,
      stream: true,
    });

    const stream = OpenAIStream(response, {
      onFinal(completion) {
        // 스트리밍 완료 후 토큰 사용량 추정 로깅
        const estimatedOutputTokens = countTokens(completion);
        trackLLMUsage({
          model: "gpt-4o-mini",
          inputTokens,
          outputTokens: estimatedOutputTokens,
          cost:
            inputTokens * 0.00000015 +
            estimatedOutputTokens * 0.0000006,
        });
      },
    });

    return new StreamingTextResponse(stream);
  } catch (error) {
    // OpenAI API 에러 분류
    if (error instanceof Error) {
      if (error.message.includes("rate_limit")) {
        return Response.json(
          { error: "AI service is busy. Please try again in a moment." },
          { status: 429 }
        );
      }
      if (error.message.includes("context_length")) {
        return Response.json(
          { error: "Message too long. Please shorten your input." },
          { status: 400 }
        );
      }
    }
    return Response.json(
      { error: "AI service temporarily unavailable." },
      { status: 503 }
    );
  }
}
```

---

## 체크리스트

- [ ] `tiktoken` 패키지 설치 (토큰 카운팅)
- [ ] `max_tokens` 모든 LLM 호출에 명시적 설정
- [ ] 입력 길이 검증 (토큰 수 상한)
- [ ] 컨텍스트 윈도우 초과 방지 검증
- [ ] 동적 `max_tokens` 계산 (남은 컨텍스트 기반)
- [ ] 토큰 사용량 로깅 (모델, 입출력, 비용)
- [ ] 월간 비용 예산 설정 + 알림
- [ ] 예산 초과 시 API 차단 로직
- [ ] 모델 선택 전략 (작업 복잡도별)
- [ ] 스트리밍 응답 사용 (UX 개선 + 조기 중단 가능)
- [ ] 컨텍스트 압축 전략 (긴 대화용)
- [ ] LLM API 에러별 사용자 친화적 응답

---

## 일반적 실수 & 해결

### 1. max_tokens 미설정

**증상:** 간단한 질문에 불필요하게 긴 응답, 비용 급증
**원인:** `max_tokens` 미지정 시 모델이 최대 길이까지 생성
**해결:** 용도별 적절한 `max_tokens` 설정 (분류: 10, 요약: 200, 대화: 1000)

### 2. 입력 길이 무제한

**증상:** 거대한 텍스트 붙여넣기로 건당 $1+ 비용 발생
**원인:** 사용자 입력 토큰 수 검증 없음
**해결:** `countTokens()` + 상한 초과 시 에러 반환

### 3. 컨텍스트 무한 누적

**증상:** 대화가 길어질수록 비용 선형 증가, 응답 속도 저하
**원인:** 이전 메시지를 모두 포함하여 API 호출
**해결:** 슬라이딩 윈도우 또는 요약 기반 컨텍스트 압축

### 4. 모든 작업에 최상위 모델 사용

**증상:** 간단한 분류/추출 작업에도 GPT-4o 사용, 비용 20배 차이
**원인:** 작업 복잡도 구분 없이 단일 모델 사용
**해결:** 모델 라우터로 작업별 적정 모델 선택

### 5. 스트리밍 미사용

**증상:** 긴 응답 시 사용자가 빈 화면에서 오래 대기
**원인:** 전체 응답 완료 후 한 번에 반환
**해결:** `stream: true` + `StreamingTextResponse`로 점진적 표시

### 6. LLM API 에러를 그대로 노출

**증상:** 사용자에게 "rate_limit_exceeded" 같은 기술적 에러 메시지 표시
**원인:** API 에러를 변환 없이 그대로 반환
**해결:** 에러 타입별 사용자 친화적 메시지 매핑

---

## 검증 명령어

```bash
# 1. tiktoken 패키지 확인
grep -n "tiktoken" package.json

# 2. max_tokens 설정 확인 (LLM 호출마다 있어야 함)
grep -rn "max_tokens\|maxTokens" --include="*.ts" --include="*.tsx" | grep -v node_modules | head -10

# 3. 토큰 카운팅 구현 확인
grep -rn "countTokens\|tiktoken\|tokenCount\|encoding_for_model" --include="*.ts" --include="*.tsx" | grep -v node_modules | head -5

# 4. LLM 패키지 확인
grep -n "openai\|anthropic\|@ai-sdk\|langchain" package.json

# 5. 스트리밍 사용 확인
grep -rn "stream.*true\|StreamingTextResponse\|OpenAIStream" --include="*.ts" --include="*.tsx" | grep -v node_modules | head -5

# 6. 입력 길이 검증 확인
grep -rn "inputTokens\|input.*too.*long\|MAX_INPUT" --include="*.ts" --include="*.tsx" | grep -v node_modules | head -5

# 7. 비용 추적 확인
grep -rn "trackLLMUsage\|llm.*cost\|cost.*track\|MONTHLY_BUDGET" --include="*.ts" --include="*.tsx" | grep -v node_modules | head -5

# 8. 컨텍스트 압축 확인
grep -rn "compress\|sliding.*window\|summarize.*conversation" --include="*.ts" --include="*.tsx" | grep -v node_modules | head -5
```
