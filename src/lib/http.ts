const USER_AGENT =
  "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36";

export async function fetchBuffer(
  url: string,
  init?: RequestInit,
): Promise<{ bytes: Uint8Array; contentType: string }> {
  const response = await fetch(url, {
    ...init,
    headers: {
      "User-Agent": USER_AGENT,
      Accept: "text/html,application/xhtml+xml,application/json;q=0.9,*/*;q=0.8",
      "Accept-Language": "ja,en;q=0.8",
      ...(init?.headers ?? {}),
    },
    cache: "no-store",
    signal: AbortSignal.timeout(15000),
  });
  if (!response.ok) {
    throw new Error(`HTTP ${response.status} ${url}`);
  }
  const bytes = new Uint8Array(await response.arrayBuffer());
  return {
    bytes,
    contentType: response.headers.get("content-type") ?? "",
  };
}

export function decodePage(bytes: Uint8Array): string {
  const head = new TextDecoder("ascii", { fatal: false }).decode(bytes.slice(0, 800));
  const charset = /shift_jis|x-sjis|windows-31j/i.test(head) ? "shift_jis" : "utf-8";
  const text = new TextDecoder(charset).decode(bytes);
  if (charset === "shift_jis" && !/[\u3040-\u30ff\u4e00-\u9fff]/.test(text.slice(0, 4000))) {
    return new TextDecoder("utf-8").decode(bytes);
  }
  return text;
}

export async function fetchText(url: string, init?: RequestInit): Promise<string> {
  const { bytes } = await fetchBuffer(url, init);
  return decodePage(bytes);
}

export async function fetchFormJson<T>(
  url: string,
  body: Record<string, string>,
): Promise<T> {
  const { bytes } = await fetchBuffer(url, {
    method: "POST",
    headers: {
      "Content-Type": "application/x-www-form-urlencoded; charset=UTF-8",
    },
    body: new URLSearchParams(body),
  });
  return JSON.parse(new TextDecoder("utf-8").decode(bytes)) as T;
}
