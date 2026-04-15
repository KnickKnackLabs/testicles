/**
 * ASCII box-drawing diagram helpers for README generation.
 */

export interface ChainItem {
  label: string;
  note?: string;
}

/**
 * Render a vertical chain of box-drawing boxes with optional annotations.
 * All boxes are the same width (derived from the longest label).
 * The last box has no downward connector.
 *
 * @param items  - Labels and optional right-side annotations
 * @param indent - Left padding (spaces)
 */
export function verticalChain(items: ChainItem[], indent = 8): string {
  const maxLabel = Math.max(...items.map((i) => i.label.length));
  // inner width: label + 1 space padding each side, must be odd for centered ┬
  let inner = maxLabel + 2;
  if (inner % 2 === 0) inner++;
  const mid = Math.floor(inner / 2);
  const pad = " ".repeat(indent);

  const lines: string[] = [];
  for (let i = 0; i < items.length; i++) {
    const { label, note } = items[i];
    const isLast = i === items.length - 1;

    // Top border: ┌─┴─┐ (with ┴ connector) or ┌───┐ (first item)
    const topBar = i === 0
      ? "─".repeat(inner)
      : "─".repeat(mid) + "┴" + "─".repeat(inner - mid - 1);
    lines.push(`${pad}┌${topBar}┐`);

    // Label row: │ centered label │   note
    const leftPad = Math.floor((inner - label.length) / 2);
    const rightPad = inner - label.length - leftPad;
    const labelLine = `${pad}│${" ".repeat(leftPad)}${label}${" ".repeat(rightPad)}│`;
    lines.push(note ? `${labelLine}   ${note}` : labelLine);

    // Bottom border: └─┬─┘ (with ┬ connector) or └───┘ (last item)
    const botBar = isLast
      ? "─".repeat(inner)
      : "─".repeat(mid) + "┬" + "─".repeat(inner - mid - 1);
    lines.push(`${pad}└${botBar}┘`);

    // Vertical connector between boxes
    if (!isLast) {
      lines.push(`${pad}${" ".repeat(mid + 1)}│`);
    }
  }

  return lines.join("\n");
}
