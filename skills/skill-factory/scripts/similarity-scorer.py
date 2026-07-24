#!/usr/bin/env python3
"""
similarity-scorer.py - Compare candidate pattern against existing skill inventory.

Usage:
  python3 similarity-scorer.py --candidate "description text" --manifest manifest.json
  python3 similarity-scorer.py --candidate "description text" --manifest - < manifest.json
  echo '{"name":"x","description":"y"}' | python3 similarity-scorer.py --candidate "desc" --manifest -

Output: JSON array of {name, score, verdict, breakdown} sorted by score descending.

Thresholds:
  >= 0.8  SKIP   (near-duplicate exists)
  0.6-0.8 MERGE  (significant overlap, extend existing)
  0.3-0.6 UPDATE (partial overlap, consider updating)
  < 0.3   CREATE (novel, safe to create new)

No external dependencies - uses only stdlib difflib.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from difflib import SequenceMatcher

# Weights for 4-dimensional scoring
WEIGHTS = {
    "name": 0.20,
    "description": 0.40,
    "domain": 0.25,
    "keywords": 0.15,
}

THRESHOLDS = [
    (0.8, "SKIP"),
    (0.6, "MERGE"),
    (0.3, "UPDATE"),
    (0.0, "CREATE"),
]

# Domain classification keywords
DOMAIN_MAP = {
    "frontend": ["react", "vue", "svelte", "css", "tailwind", "component", "ui", "ux", "design", "responsive", "html", "dom", "browser"],
    "backend": ["api", "server", "database", "sql", "rest", "graphql", "auth", "middleware", "endpoint", "route", "express", "fastapi"],
    "devops": ["deploy", "ci", "cd", "docker", "kubernetes", "terraform", "pipeline", "build", "infrastructure", "monitoring"],
    "testing": ["test", "e2e", "unit", "integration", "coverage", "playwright", "jest", "vitest", "tdd", "assertion"],
    "security": ["security", "vulnerability", "owasp", "cwe", "encryption", "auth", "csrf", "xss", "injection", "compliance"],
    "content": ["content", "marketing", "seo", "copywriting", "social", "youtube", "video", "image", "media"],
    "data": ["data", "analytics", "visualization", "chart", "report", "metric", "dashboard", "insight"],
    "automation": ["automation", "workflow", "n8n", "webhook", "schedule", "cron", "pipeline", "trigger"],
    "documentation": ["docs", "documentation", "readme", "guide", "reference", "api-docs", "changelog"],
    "skill-meta": ["skill", "agent", "command", "plugin", "extension", "meta", "factory", "creator"],
    "file-processing": ["pdf", "docx", "csv", "json", "xml", "yaml", "file", "document", "edit", "convert", "transform", "parse", "extract", "merge", "split"],
    "media": ["image", "video", "audio", "thumbnail", "screenshot", "camera", "frame", "clip"],
}


def naive_stem(word: str) -> str:
    """Reduce word to approximate root form (no external deps)."""
    if len(word) <= 3:
        return word
    # Order matters: try longest suffixes first
    for suffix, min_len in [("ation", 5), ("ting", 4), ("sing", 4),
                            ("ment", 4), ("ness", 4), ("able", 4),
                            ("ible", 4), ("ings", 4), ("ized", 4),
                            ("ises", 4), ("izes", 4),
                            ("ing", 3), ("ies", 3), ("ion", 3),
                            ("ous", 3), ("ive", 3), ("ful", 3),
                            ("ted", 3), ("ers", 3), ("est", 3),
                            ("ed", 2), ("ly", 2), ("er", 4), ("es", 2), ("ts", 2), ("al", 5)]:
        if word.endswith(suffix) and len(word) - len(suffix) >= min_len:
            return word[:-len(suffix)]
    # Simple plural (protect Latin-like endings: -us, -is, -ss)
    if (word.endswith("s") and len(word) > 3
            and not word.endswith("ss")
            and not word.endswith("us")
            and not word.endswith("is")):
        return word[:-1]
    return word


def extract_keywords(text: str) -> set[str]:
    """Extract meaningful keywords from text, with naive stemming."""
    text = text.lower()
    stops = {"the", "a", "an", "is", "are", "was", "were", "be", "been", "being",
             "have", "has", "had", "do", "does", "did", "will", "would", "could",
             "should", "may", "might", "shall", "can", "need", "dare", "ought",
             "used", "to", "of", "in", "for", "on", "with", "at", "by", "from",
             "as", "into", "through", "during", "before", "after", "above", "below",
             "between", "out", "off", "over", "under", "again", "further", "then",
             "once", "this", "that", "these", "those", "and", "but", "or", "nor",
             "not", "so", "yet", "both", "either", "neither", "each", "every",
             "all", "any", "few", "more", "most", "other", "some", "such", "no",
             "only", "own", "same", "than", "too", "very", "just", "use", "when",
             "also", "it", "its", "using"}
    words = set(re.findall(r'[a-z][a-z0-9-]+', text))
    filtered = words - stops
    return {naive_stem(w) for w in filtered}


def classify_domain(text: str) -> set[str]:
    """Classify text into domain categories."""
    text_lower = text.lower()
    domains = set()
    for domain, keywords in DOMAIN_MAP.items():
        if any(re.search(r'\b' + re.escape(kw) + r'\b', text_lower) for kw in keywords):
            domains.add(domain)
    return domains if domains else {"general"}


def seq_ratio(a: str, b: str) -> float:
    """Sequence similarity ratio between two strings."""
    if not a and not b:
        return 1.0
    if not a or not b:
        return 0.0
    return SequenceMatcher(None, a.lower(), b.lower()).ratio()


def keyword_overlap(set_a: set[str], set_b: set[str]) -> float:
    """Jaccard similarity between keyword sets."""
    if not set_a or not set_b:
        return 0.0
    intersection = set_a & set_b
    union = set_a | set_b
    return len(intersection) / len(union)


def score_candidate(candidate_name: str, candidate_desc: str,
                    existing_name: str, existing_desc: str) -> dict:
    """Score similarity between candidate and existing item."""
    # 1. Name similarity
    name_score = seq_ratio(candidate_name, existing_name)

    # 2. Description similarity
    desc_score = seq_ratio(candidate_desc, existing_desc)

    # 3. Domain overlap
    cand_domains = classify_domain(f"{candidate_name} {candidate_desc}")
    exist_domains = classify_domain(f"{existing_name} {existing_desc}")
    domain_score = keyword_overlap(cand_domains, exist_domains)

    # 4. Keyword overlap
    cand_kw = extract_keywords(f"{candidate_name} {candidate_desc}")
    exist_kw = extract_keywords(f"{existing_name} {existing_desc}")
    kw_score = keyword_overlap(cand_kw, exist_kw)

    # Weighted total
    total = (
        WEIGHTS["name"] * name_score +
        WEIGHTS["description"] * desc_score +
        WEIGHTS["domain"] * domain_score +
        WEIGHTS["keywords"] * kw_score
    )

    # Determine verdict
    verdict = "CREATE"
    for threshold, v in THRESHOLDS:
        if total >= threshold:
            verdict = v
            break

    return {
        "score": round(total, 3),
        "verdict": verdict,
        "breakdown": {
            "name": round(name_score, 3),
            "description": round(desc_score, 3),
            "domain": round(domain_score, 3),
            "keywords": round(kw_score, 3),
        },
    }


def main():
    parser = argparse.ArgumentParser(description="Score similarity between candidate and existing skills")
    parser.add_argument("--candidate", required=True, help="Candidate pattern description")
    parser.add_argument("--candidate-name", default="", help="Candidate name (optional, extracted from description if omitted)")
    parser.add_argument("--manifest", required=True, help="Path to manifest JSON (use - for stdin)")
    parser.add_argument("--top", type=int, default=5, help="Show top N results (default: 5)")
    parser.add_argument("--threshold", type=float, default=0.0, help="Minimum score to include (default: 0.0)")
    args = parser.parse_args()

    # Load manifest
    try:
        if args.manifest == "-":
            manifest = json.load(sys.stdin)
        else:
            with open(args.manifest) as f:
                manifest = json.load(f)
    except FileNotFoundError:
        print(json.dumps({"error": f"Manifest file not found: {args.manifest}"}), file=sys.stderr)
        sys.exit(1)
    except json.JSONDecodeError as e:
        print(json.dumps({"error": f"Invalid JSON in manifest: {e}"}), file=sys.stderr)
        sys.exit(1)

    if not isinstance(manifest, list):
        print(json.dumps({"error": "Manifest must be a JSON array"}), file=sys.stderr)
        sys.exit(1)

    candidate_desc = args.candidate
    candidate_name = args.candidate_name or candidate_desc.split()[0] if candidate_desc else ""

    results = []
    for item in manifest:
        name = item.get("name", "")
        desc = item.get("description", "")
        score_result = score_candidate(candidate_name, candidate_desc, name, desc)
        if score_result["score"] >= args.threshold:
            results.append({
                "name": name,
                "type": item.get("type", "unknown"),
                "path": item.get("path", ""),
                **score_result,
            })

    results.sort(key=lambda x: x["score"], reverse=True)
    results = results[:args.top]

    print(json.dumps(results, indent=2, ensure_ascii=False))


if __name__ == "__main__":
    main()
