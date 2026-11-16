const provider = "openai";
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
  if (req.method !== 'POST' || url.pathname !== generationPath && !(provider === 'gemini' && url.pathname === '/v1beta/models/test-chat:streamGenerateContent')) return send(501, {error: 'Endpoint not modeled'});
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
  if (provider !== 'gemini' && (typeof body.stream !== 'boolean' || (body.model !== 'test-chat' && !(provider === 'ollama' && body.model === 'test-chat:latest')))) return send(400, {error: 'Invalid generation shape'});
  const text = 'Hello — اردو جواب';
  if (body.stream === true || url.pathname.endsWith(':streamGenerateContent')) {
    res.writeHead(200, {'Content-Type': provider === 'ollama' ? 'application/x-ndjson' : 'text/event-stream'});
    const event = value => res.write('data: ' + JSON.stringify(value) + '\n\n');
    const chunks = ['Hello — ', 'اردو جواب'];
    if (provider === 'openai' || provider === 'compatible') {
      for (const content of chunks) event({choices: [{delta: {content}, finish_reason: null}]});
      event({choices: [{delta: {}, finish_reason: 'stop'}]});
      event({choices: [], usage: {prompt_tokens: 12, completion_tokens: 5}});
      res.write('data: [DONE]\n\n');
    } else if (provider === 'gemini') {
      event({candidates: [{content: {role: 'model', parts: [{text: chunks[0]}]}}]});
      event({candidates: [{content: {role: 'model', parts: [{text: chunks[1]}]}, finishReason: 'STOP'}], usageMetadata: {promptTokenCount: 12, candidatesTokenCount: 5}});
    } else if (provider === 'anthropic') {
      event({type: 'message_start', message: {role: 'assistant', usage: {input_tokens: 12}}});
      for (const text of chunks) event({type: 'content_block_delta', delta: {type: 'text_delta', text}});
      event({type: 'message_delta', delta: {stop_reason: 'end_turn'}, usage: {output_tokens: 5}});
      event({type: 'message_stop'});
    } else {
      res.write(JSON.stringify({message: {role: 'assistant', content: chunks[0]}, done: false}) + '\n');
      res.write(JSON.stringify({message: {role: 'assistant', content: chunks[1]}, done: true, done_reason: 'stop', prompt_eval_count: 12, eval_count: 5}) + '\n');
    }
    return res.end();
  }

  if (provider === 'gemini') return send(200, {candidates: [{content: {role: 'model', parts: [{text}]}, finishReason: 'STOP'}], usageMetadata: {promptTokenCount: 12, candidatesTokenCount: 5}});
  if (provider === 'anthropic') return send(200, {role: 'assistant', content: [{type: 'text', text}], stop_reason: 'end_turn', usage: {input_tokens: 12, output_tokens: 5}});
  if (provider === 'ollama') return send(200, {message: {role: 'assistant', content: text}, done: true, done_reason: 'stop', prompt_eval_count: 12, eval_count: 5});
  return send(200, {choices: [{message: {role: 'assistant', content: text}, finish_reason: 'stop'}], usage: {prompt_tokens: 12, completion_tokens: 5}});
}).listen(process.env.PORT || 4011, '127.0.0.1');
