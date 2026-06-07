#!/usr/bin/env python3
"""Convert Whisper JSON segments into stanza-separated lyrics with section hints."""

import argparse
import json
import re
from collections import Counter
from pathlib import Path


def clean_line(text: str) -> str:
    text = text.replace("\n", " ").strip()
    text = re.sub(r"\s+", " ", text)
    return text


def norm_text(text: str) -> str:
    text = text.lower()
    text = re.sub(r"[^a-z0-9\s]", "", text)
    text = re.sub(r"\s+", " ", text).strip()
    return text


def stanza_signature(lines: list[str]) -> str:
    joined = " ".join(lines)
    return norm_text(joined)


def build_stanzas(segments: list[dict], gap_seconds: float) -> list[dict]:
    stanzas = []
    current = []
    current_start = None
    prev_end = None

    for segment in segments:
        text = clean_line(segment.get("text", ""))
        if not text:
            continue

        start = float(segment.get("start", 0.0))
        end = float(segment.get("end", start))

        if prev_end is not None and (start - prev_end) >= gap_seconds and current:
            stanzas.append({"start": current_start, "end": prev_end, "lines": current})
            current = []
            current_start = None

        if current_start is None:
            current_start = start

        current.append(text)
        prev_end = end

    if current:
        stanzas.append({"start": current_start, "end": prev_end, "lines": current})

    return stanzas


def assign_labels(stanzas: list[dict]) -> list[dict]:
    signatures = [stanza_signature(s["lines"]) for s in stanzas]
    counts = Counter(signatures)

    verse_num = 1
    bridge_used = False

    for idx, stanza in enumerate(stanzas):
        sig = signatures[idx]
        line_count = len(stanza["lines"])

        if counts[sig] >= 2 and line_count <= 8:
            stanza["label"] = "Chorus"
            continue

        # Heuristic bridge: a short non-repeated stanza between larger sections.
        if (
            not bridge_used
            and 0 < idx < len(stanzas) - 1
            and line_count <= 3
            and len(stanzas[idx - 1]["lines"]) >= 4
            and len(stanzas[idx + 1]["lines"]) >= 4
        ):
            stanza["label"] = "Bridge"
            bridge_used = True
            continue

        stanza["label"] = f"Verse {verse_num}"
        verse_num += 1

    return stanzas


def write_outputs(stanzas: list[dict], plain_out: Path, tagged_out: Path) -> None:
    plain_chunks = []
    tagged_chunks = []

    for stanza in stanzas:
        block = "\n".join(stanza["lines"])
        plain_chunks.append(block)
        tagged_chunks.append(f"[{stanza['label']}]\n{block}")

    plain_out.write_text("\n\n".join(plain_chunks).strip() + "\n", encoding="utf-8")
    tagged_out.write_text("\n\n".join(tagged_chunks).strip() + "\n", encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Format Whisper transcript into stanza-separated lyrics with section hints."
    )
    parser.add_argument("--input", required=True, help="Whisper JSON transcript file")
    parser.add_argument("--plain-output", required=True, help="Output text with stanza separation")
    parser.add_argument("--tagged-output", required=True, help="Output text with [Verse]/[Chorus]/[Bridge]")
    parser.add_argument(
        "--gap-seconds",
        type=float,
        default=2.2,
        help="Silence gap threshold to split stanzas (default: 2.2)",
    )
    args = parser.parse_args()

    input_path = Path(args.input)
    plain_out = Path(args.plain_output)
    tagged_out = Path(args.tagged_output)

    payload = json.loads(input_path.read_text(encoding="utf-8"))
    segments = payload.get("segments", [])
    if not segments:
        raise SystemExit("No segments found in transcript JSON.")

    stanzas = build_stanzas(segments, args.gap_seconds)
    stanzas = assign_labels(stanzas)
    write_outputs(stanzas, plain_out, tagged_out)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
