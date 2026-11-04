(() => {
  async function request(baseUrl, path, method, bodyJson, timeoutMs, grant) {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), Number(timeoutMs) || 5000);
    try {
      const normalizedBase = String(baseUrl || '').replace(/\/$/, '');
      const url = `${normalizedBase}${String(path || '')}`;
      const body = bodyJson ? JSON.parse(String(bodyJson)) : null;
      const init = {
        method: String(method || 'GET').toUpperCase(),
        mode: 'cors',
        cache: 'no-store',
        signal: controller.signal,
        targetAddressSpace: 'local',
        headers: {
          'Accept': 'application/json',
          'X-PharmaFlow-Bridge': '1',
          ...(grant ? { 'X-PharmaFlow-Grant': String(grant) } : {}),
        },
      };
      if (init.method !== 'GET' && body !== null) {
        init.headers['Content-Type'] = 'application/json';
        init.body = JSON.stringify(body);
      }

      const response = await fetch(new Request(url, init));
      const text = await response.text();
      let data;
      try {
        data = text ? JSON.parse(text) : {};
      } catch (_) {
        data = { ok: false, code: 'INVALID_JSON', error: text || `HTTP ${response.status}` };
      }
      if (!response.ok && data.ok !== false) data.ok = false;
      return JSON.stringify(data);
    } catch (error) {
      const aborted = error && error.name === 'AbortError';
      return JSON.stringify({
        ok: false,
        code: aborted ? 'BRIDGE_TIMEOUT' : 'BRIDGE_OFFLINE',
        error: aborted ? 'POS Bridge در زمان مقرر پاسخ نداد.' : 'به شبکه داروخانه متصل نیستید.',
      });
    } finally {
      clearTimeout(timer);
    }
  }

  window.PharmaFlowPosBridge = { request };
})();
