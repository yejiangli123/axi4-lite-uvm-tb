#!/usr/bin/env python3
"""
URG 报表解析（dashboard.txt/html）

功能：从 URG 输出目录抽取 line/toggle/branch/fsm 等代码覆盖率百分比，
供 gen_closure_report.py（闭环 Markdown）与 trend_snapshot.py（CSV 趋势行）复用。
"""
import os
import re
from typing import Dict, List, Optional


def _load_urg_report_text(urg_report_dir: str) -> str:
    candidates = [
        os.path.join(urg_report_dir, "dashboard.txt"),
        os.path.join(urg_report_dir, "dashboard.html"),
        os.path.join(urg_report_dir, "urgReport", "dashboard.txt"),
        os.path.join(urg_report_dir, "urgReport", "dashboard.html"),
    ]
    for c in candidates:
        if os.path.exists(c):
            with open(c, "r", encoding="utf-8", errors="ignore") as f:
                return f.read()

    chunks: List[str] = []
    for root, _, files in os.walk(urg_report_dir):
        for name in files:
            low = name.lower()
            if low.endswith((".txt", ".html", ".htm")):
                path = os.path.join(root, name)
                try:
                    with open(path, "r", encoding="utf-8", errors="ignore") as f:
                        chunks.append(f.read())
                except OSError:
                    pass
    return "\n".join(chunks)


def parse_urg_metrics(urg_report_dir: str, keys: Optional[List[str]] = None) -> Dict[str, Optional[float]]:
    """Parse URG merged report for code coverage percentages."""
    default_keys = ["line", "toggle", "branch", "fsm"]
    use_keys = keys if keys is not None else default_keys
    metrics: Dict[str, Optional[float]] = {k: None for k in use_keys}
    if not urg_report_dir or not os.path.isdir(urg_report_dir):
        return metrics

    text = _load_urg_report_text(urg_report_dir)
    if not text:
        return metrics

    def try_extract(metric_key: str) -> Optional[float]:
        patterns = [
            rf"\b{metric_key}\b\s*[:=]?\s*([0-9]+(?:\.[0-9]+)?)\s*%",
            rf"{metric_key}\s+coverage\s*[:=]?\s*([0-9]+(?:\.[0-9]+)?)\s*%",
            rf"(?:Metric|Score)[^\n]*{metric_key}[^\n]*?([0-9]+(?:\.[0-9]+)?)\s*%",
        ]
        for pat in patterns:
            m = re.search(pat, text, re.IGNORECASE | re.DOTALL)
            if m:
                return float(m.group(1))
        return None

    for key in use_keys:
        v = try_extract(key)
        if v is not None:
            metrics[key] = v
    return metrics
