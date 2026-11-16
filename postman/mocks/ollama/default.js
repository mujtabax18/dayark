const provider = "ollama";
// Contract-derived fixtures; synthetic models and credentials, no real API calls.
const http = require('http');
http.createServer(async (req, res) => {
  const send = (code, value) => {
    res.writeHead(code, {'Content-Type': 'application/json'});
    res.end(JSON.stringify(value));
  };
  const url = new URL(req.url, 'http://localhost');
  if (req.method === 'GET' && (url.pathname.endsWith('/models') || url.pathname.endsWith('/tags'))) {
    if (provider === 'gemini') return send(200, {models: [
      {name: 'models/test-chat', displayName: 'Test chat', supportedGenerationMethods: ['generateContent'], inputTokenLimit: 4096, outputTokenLimit: 1024},
      {name: 'models/test-embed', supportedGenerationMethods: ['embedContent']}
    ]});
    if (provider === 'ollama') return send(200, {models: [{name: 'test-chat:latest'}]});
    return send(200, {data: [{id: 'test-chat', display_name: 'Test chat'}], has_more: false});
  }
  const generationPath = {openai: '/v1/chat/completions', compatible: '/v1/chat/completions',
    gemini: '/v1beta/models/test-chat:generateContent', anthropic: '/v1/messages', ollama: '/api/chat'}[provider];
  if (req.method !== 'POST' || url.pathname !== generationPath) return send(501, {error: 'Endpoint not modeled'});
  let body;
  try {
    if (req.body !== undefined) {
      body = typeof req.body === 'string' ? JSON.parse(req.body) : req.body;
    } else {
      let raw = '';
      for await (const chunk of req) raw += chunk;
      body = JSON.parse(raw);
    }
  } catch (_) { return send(400, {error: 'Invalid JSON'}); }
  const messages = body.messages || body.contents;
  if (!Array.isArray(messages) || messages.length === 0) return send(400, {error: 'Missing conversation'});
  if (provider === 'anthropic' && (!body.max_tokens || messages.some(m => m.role === 'system'))) return send(400, {error: 'Invalid Messages shape'});
  if (provider === 'gemini' && (!body.systemInstruction || !messages.every(m => ['user', 'model'].includes(m.role)))) return send(400, {error: 'Invalid Gemini shape'});
  if (provider !== 'gemini' && (body.stream !== false || body.model !== 'test-chat')) return send(400, {error: 'Invalid generation shape'});
  const text = 'Hello — اردو جواب';
  if (provider === 'gemini') return send(200, {candidates: [{content: {role: 'model', parts: [{text}]}, finishReason: 'STOP'}], usageMetadata: {promptTokenCount: 12, candidatesTokenCount: 5}});
  if (provider === 'anthropic') return send(200, {role: 'assistant', content: [{type: 'text', text}], stop_reason: 'end_turn', usage: {input_tokens: 12, output_tokens: 5}});
  if (provider === 'ollama') return send(200, {message: {role: 'assistant', content: text}, done: true, done_reason: 'stop', prompt_eval_count: 12, eval_count: 5});
  return send(200, {choices: [{message: {role: 'assistant', content: text}, finish_reason: 'stop'}], usage: {prompt_tokens: 12, completion_tokens: 5}});
}).listen(process.env.PORT || 4011, '127.0.0.1');
