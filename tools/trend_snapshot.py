#!/usr/bin/env python3
"""
Append trend rows: timestamp, git, scope, pass_rate, avg_fcov,
plus code coverage (line/toggle/branch/fsm) from merged URG when available.
"""
import argparse
import csv
import datetime
import os
import subprocess
import sys
from typing import List, Optional, Tuple

# Allow importing sibling modules when run as script
_TOOLS_DIR = os.path.dirname(os.path.abspath(__file__))
if _TOOLS_DIR not in sys.path:
    sys.path.insert(0, _TOOLS_DIR)

from coverage_metrics import parse_urg_metrics  # noqa: E402


def _avg_fcov_from_csv(path: str) -> str:
    if not os.path.exists(path):
        return ""
    vals: List[float] = []
    with open(path, "r", encoding="utf-8", newline="") as f:
        reader = csv.DictReader(f)
        for row in reader:
            raw = (row.get("fcov_percent") or "").strip()
            if raw and raw.upper() != "NA":
                try:
                    vals.append(float(raw))
                except ValueError:
                    pass
    if not vals:
        return "NA"
    return f"{sum(vals) / len(vals):.2f}"


def _read_pass_rate(path: str) -> Optional[str]:
    if not os.path.exists(path):
        return None
    with open(path, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if "," in line:
                return line.split(",", 1)[1].strip()
    return None


def _git_short() -> str:
    try:
        out = subprocess.run(
            ["git", "rev-parse", "--short", "HEAD"],
            capture_output=True,
            text=True,
            timeout=5,
        )
        if out.returncode == 0 and out.stdout.strip():
            return out.stdout.strip()
    except (OSError, subprocess.TimeoutExpired):
        pass
    return "NA"


NEW_HEADER = (
    "timestamp,git_commit,scope,pass_rate_percent,avg_fcov_percent,"
    "line_pct,toggle_pct,branch_pct,fsm_pct\n"
)


def _migrate_old_trend(path: str) -> None:
    """Pad legacy 5-column rows with NA for code coverage."""
    with open(path, "r", encoding="utf-8") as f:
        lines = f.readlines()
    if not lines:
        return
    hdr = lines[0].strip().split(",")
    if len(hdr) >= 9 and "line_pct" in lines[0]:
        return
    out_lines = [NEW_HEADER]
    for line in lines[1:]:
        parts = [p.strip() for p in line.strip().split(",")]
        if len(parts) == 5:
            parts.extend(["NA", "NA", "NA", "NA"])
            out_lines.append(",".join(parts) + "\n")
        elif len(parts) > 5:
            out_lines.append(line if line.endswith("\n") else line + "\n")
    with open(path, "w", encoding="utf-8") as f:
        f.writelines(out_lines)


def main() -> None:
    parser = argparse.ArgumentParser(description="Append smoke/regression trend rows with optional URG code cov.")
    parser.add_argument("--report-dir", default="reports", help="Reports root (smoke/, regression/, trend.csv)")
    parser.add_argument(
        "--urg-report",
        default="",
        help="Merged URG directory (default: <report-dir>/coverage/merged_urg)",
    )
    args = parser.parse_args()

    report_dir = args.report_dir
    urg_dir = args.urg_report or os.path.join(report_dir, "coverage", "merged_urg")

    trend_path = os.path.join(report_dir, "trend.csv")
    os.makedirs(report_dir, exist_ok=True)

    if not os.path.exists(trend_path):
        with open(trend_path, "w", encoding="utf-8", newline="") as f:
            f.write(NEW_HEADER)
    else:
        _migrate_old_trend(trend_path)

    ts = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    commit = _git_short()
    code = parse_urg_metrics(urg_dir)
    lp = f"{code['line']:.2f}" if code.get("line") is not None else "NA"
    tp = f"{code['toggle']:.2f}" if code.get("toggle") is not None else "NA"
    bp = f"{code['branch']:.2f}" if code.get("branch") is not None else "NA"
    fp = f"{code['fsm']:.2f}" if code.get("fsm") is not None else "NA"

    smoke_rate = _read_pass_rate(os.path.join(report_dir, "smoke", "smoke_pass_rate.txt"))
    reg_rate = _read_pass_rate(os.path.join(report_dir, "regression", "regression_pass_rate.txt"))
    smoke_fcov = _avg_fcov_from_csv(os.path.join(report_dir, "smoke", "smoke_summary.csv"))
    reg_fcov = _avg_fcov_from_csv(os.path.join(report_dir, "regression", "regression_summary.csv"))

    rows: List[Tuple[str, str, str]] = []
    if smoke_rate:
        rows.append(("smoke", smoke_rate, smoke_fcov or "NA"))
    if reg_rate:
        rows.append(("regression", reg_rate, reg_fcov or "NA"))

    with open(trend_path, "a", encoding="utf-8", newline="") as f:
        for scope, pr, fc in rows:
            f.write(f"{ts},{commit},{scope},{pr},{fc},{lp},{tp},{bp},{fp}\n")

    if not rows:
        print(
            "[trend_snapshot] No smoke/regression pass_rate files found; "
            "run make smoke / make regression first.",
            file=sys.stderr,
        )


if __name__ == "__main__":
    main()
