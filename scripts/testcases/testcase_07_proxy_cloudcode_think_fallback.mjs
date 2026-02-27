import {
  startConfiguredAntigravityProxy,
  stopProxyAndQuitApp,
  streamAnthropicMessages,
} from './_proxy_common.mjs';
import { startMockOpenAIUpstream } from './_mock_openai_upstream.mjs';

const PROVIDER_MODEL_ID = 'google-antigravity/gemini-3-flash';
const MOCK_PROJECT_ID = 'mock-project';
const MOCK_TOKEN = 'mock-token';

const run = async () => {
  const mockUpstream = await startMockOpenAIUpstream({
    acceptedTokens: [MOCK_TOKEN],
    expectedProjectId: MOCK_PROJECT_ID,
    cloudCodeParts: [
      { text: '<thi' },
      { text: 'nk>思考中' },
      { text: '</think>广州天气：晴，26C' },
    ],
  });

  try {
    const proxyBaseURL = await startConfiguredAntigravityProxy({
      accessToken: MOCK_TOKEN,
      projectId: MOCK_PROJECT_ID,
      providerModelId: PROVIDER_MODEL_ID,
      baseURL: mockUpstream.baseURL,
      endpointMode: 'cloudcode-sse',
    });

    const streamResult = await streamAnthropicMessages(proxyBaseURL, {
      model: PROVIDER_MODEL_ID,
      max_tokens: 128,
      messages: [{ role: 'user', content: '广州天气查询' }],
    });
    const firstPath = mockUpstream.requests[0]?.path || '(none)';

    if (!streamResult.hasMessageStop) {
      throw new Error('SSE 未收到 message_stop。');
    }
    if (!streamResult.thinking.includes('思考中')) {
      throw new Error(`未解析出 thinking 内容: thinking=${streamResult.thinking || '(empty)'} text=${streamResult.text || '(empty)'} upstreamPath=${firstPath}`);
    }
    if (!streamResult.text.includes('广州天气：晴，26C')) {
      throw new Error(`未解析出正文内容: ${streamResult.text || '(empty)'}`);
    }
    if (streamResult.text.includes('<think>') || streamResult.text.includes('</think>')) {
      throw new Error(`正文中仍包含 think 标签: ${streamResult.text}`);
    }

    console.log('[testcase_07] cloudcode think-tag fallback success');
    console.log(`  thinking: ${streamResult.thinking}`);
    console.log(`  text: ${streamResult.text}`);
  } finally {
    await mockUpstream.stop();
  }
};

let exitCode = 0;

run()
  .catch((error) => {
    exitCode = 1;
    console.error(`[testcase_07] FAIL: ${error instanceof Error ? error.message : String(error)}`);
  })
  .finally(async () => {
    await stopProxyAndQuitApp();
    process.exit(exitCode);
  });
