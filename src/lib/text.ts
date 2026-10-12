/** Fullwidth digits and spaces to a compact halfwidth form. */
export function normalizeDigits(value: string): string {
  return value
    .replace(/[０-９]/g, (ch) => String.fromCharCode(ch.charCodeAt(0) - 0xfee0))
    .replace(/\u3000/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

export function compactRoute(value: string): string {
  return normalizeDigits(value)
    .replace(/<br\s*\/?>/gi, "・")
    .replace(/<[^>]+>/g, "")
    .replace(/\s+/g, "")
    .replace(/・+/g, "・")
    .replace(/^・|・$/g, "");
}

export function htmlToText(html: string): string {
  return html
    .replace(/<br\s*\/?>/gi, " ")
    .replace(/<[^>]+>/g, " ")
    .replace(/&nbsp;/gi, " ")
    .replace(/&amp;/gi, "&")
    .replace(/\s+/g, " ")
    .trim();
}
