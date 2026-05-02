#!/usr/bin/env python3
"""生成覆盖率闭环 Markdown（单文件可拷贝到 VM，无需同目录 coverage_metrics.py）。"""
import argparse
import csv
import datetime
import os
import re
from typing import Dict, List, Optional, Tuple


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


FCOV_TARGET = 95.0
CODE_TARGETS = {
    "line": 95.0,
    "toggle": 90.0,
    "branch": 90.0,
    "fsm": 95.0,
}


def load_csv_stats(path: str) -> Tuple[Optional[float], Optional[float], int, int]:
    if not path or not os.path.exists(path):
        return None, None, 0, 0

    total = 0
    passed = 0
    fcov_values = []
    with open(path, "r", encoding="utf-8", newline="") as f:
        reader = csv.DictReader(f)
        for row in reader:
            total += 1
            if row.get("status", "").strip().upper() == "PASS":
                passed += 1
            fcov = row.get("fcov_percent", "").strip()
            try:
                fcov_values.append(float(fcov))
            except Exception:
                pass

    pass_rate = (100.0 * passed / total) if total > 0 else None
    avg_fcov = (sum(fcov_values) / len(fcov_values)) if fcov_values else None
    return pass_rate, avg_fcov, passed, total


def status_mark(value: Optional[float], target: float) -> str:
    if value is None:
        return "N/A"
    return "PASS" if value >= target else "GAP"


def gap_reason(metric: str, value: Optional[float], target: float) -> str:
    if value is None:
        return "未检测到可解析覆盖率结果（请先执行 cov_merge/urg 报告生成）"
    if value >= target:
        return "已达标"
    if metric == "toggle":
        return "通常由未翻转寄存器位或错误路径激励不足导致"
    if metric == "branch":
        return "通常由错误分支/异常分支未充分触发导致"
    if metric == "fsm":
        return "通常由状态机错误恢复/边界状态未覆盖导致"
    return "通常由未触发代码路径导致"


def write_report(
    output: str,
    smoke_stats: Tuple[Optional[float], Optional[float], int, int],
    reg_stats: Tuple[Optional[float], Optional[float], int, int],
    code_metrics: Dict[str, Optional[float]],
) -> None:
    os.makedirs(os.path.dirname(output), exist_ok=True)
    now = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")

    smoke_rate, smoke_fcov, smoke_pass, smoke_total = smoke_stats
    reg_rate, reg_fcov, reg_pass, reg_total = reg_stats

    lines = []
    lines.append("# AXI4-Lite 覆盖率闭环报告")
    lines.append("")
    lines.append(f"- 生成时间：`{now}`")
    lines.append(f"- Functional Coverage 目标：`>= {FCOV_TARGET:.2f}%`")
    lines.append(
        f"- Code Coverage 目标：`line>={CODE_TARGETS['line']:.0f}%` / "
        f"`toggle>={CODE_TARGETS['toggle']:.0f}%` / "
        f"`branch>={CODE_TARGETS['branch']:.0f}%` / "
        f"`fsm>={CODE_TARGETS['fsm']:.0f}%`"
    )
    lines.append("")
    lines.append("## 回归统计")
    lines.append("")
    lines.append(
        f"- Smoke：`{smoke_pass}/{smoke_total}`，通过率 "
        f"`{smoke_rate:.2f}%`" if smoke_rate is not None else "- Smoke：未发现结果"
    )
    lines.append(
        f"- Regression：`{reg_pass}/{reg_total}`，通过率 "
        f"`{reg_rate:.2f}%`" if reg_rate is not None else "- Regression：未发现结果"
    )
    lines.append(
        f"- 平均 Functional Coverage（Smoke）：`{smoke_fcov:.2f}%`"
        if smoke_fcov is not None else "- 平均 Functional Coverage（Smoke）：N/A"
    )
    lines.append(
        f"- 平均 Functional Coverage（Regression）：`{reg_fcov:.2f}%`"
        if reg_fcov is not None else "- 平均 Functional Coverage（Regression）：N/A"
    )
    lines.append("")
    lines.append("## 功能覆盖维度（Scoreboard `cg_axi4_lite_trans`）")
    lines.append("")
    lines.append("- **WSTRB**：按字节使能分类（单字节/双字节/三字节/四字节/非法全 0）。 ")
    lines.append("- **RESP**：写通道 `bresp` / 读通道 `rresp` 的 OKAY、SLVERR、DECERR。 ")
    lines.append("- **地址类**：低/高边界、越界、非对齐地址区间。 ")
    lines.append("- **交叉**：写事务下 `WSTRB kind × 地址边界`（`cross_wstrb_boundary`）。 ")
    lines.append("- **汇总指标**：`report_phase` 打印整体 **Functional Coverage**（inst coverage），闭环中与目标 `95%` 对比。")
    lines.append("")
    lines.append("## 覆盖率目标对比")
    lines.append("")

    func_status = status_mark(reg_fcov, FCOV_TARGET)
    func_value = f"{reg_fcov:.2f}%" if reg_fcov is not None else "N/A"
    lines.append(f"- Functional：当前 `{func_value}`，目标 `{FCOV_TARGET:.2f}%`，状态 `{func_status}`")

    for metric, target in CODE_TARGETS.items():
        value = code_metrics.get(metric)
        value_str = f"{value:.2f}%" if value is not None else "N/A"
        state = status_mark(value, target)
        lines.append(f"- {metric.upper()}：当前 `{value_str}`，目标 `{target:.2f}%`，状态 `{state}`")

    lines.append("")
    lines.append("## 未达标项解释与补测计划")
    lines.append("")
    if func_status == "GAP":
        lines.append(
            "- Functional Coverage 未达标：建议增加随机 backpressure 与错误响应混合激励，"
            "补充 `WSTRB x 地址边界` 交叉场景的随机化样本。"
        )
    for metric, target in CODE_TARGETS.items():
        value = code_metrics.get(metric)
        if status_mark(value, target) == "GAP" or value is None:
            lines.append(
                f"- {metric.upper()}：{gap_reason(metric, value, target)}；"
                f"补测计划：补充针对 `{metric}` 未覆盖路径的 directed+random 用例，并纳入 nightly regression。"
            )
    if func_status != "GAP" and all(status_mark(code_metrics.get(m), CODE_TARGETS[m]) == "PASS" for m in CODE_TARGETS):
        lines.append("- 当前各项指标均达标，建议维持趋势回归并监控波动。")

    lines.append("")
    lines.append("## 说明")
    lines.append("")
    lines.append("- 本报告由脚本自动生成，依赖 `smoke/regression` 汇总 CSV 和 URG 输出。")
    lines.append("- 若 code coverage 显示 N/A，请先执行 `make cov_merge`。")

    with open(output, "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")


def main():
    parser = argparse.ArgumentParser(description="Generate AXI4-Lite coverage closure report.")
    parser.add_argument("--smoke", default="", help="Path to smoke summary CSV")
    parser.add_argument("--regression", default="", help="Path to regression summary CSV")
    parser.add_argument("--urg-report", default="", help="Path to merged URG report dir")
    parser.add_argument("--output", required=True, help="Output markdown path")
    args = parser.parse_args()

    smoke_stats = load_csv_stats(args.smoke)
    reg_stats = load_csv_stats(args.regression)
    code_metrics = parse_urg_metrics(args.urg_report)
    write_report(args.output, smoke_stats, reg_stats, code_metrics)


if __name__ == "__main__":
    main()
