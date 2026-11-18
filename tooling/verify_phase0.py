#!/usr/bin/env python3
"""Check the Phase 0 catalog, versioned evidence and offline design artifacts."""

import argparse
from collections import Counter
from hashlib import sha256
import json
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
CATEGORY_COUNTS = {
    "Text & content": 18, "Actions": 17, "Form & controls": 29,
    "Feedback": 19, "Data & visualization": 18, "Containers & navigation": 22,
    "Media & special": 17, "Developer & utilities": 19,
}
REQUIRED_TOKENS = set(
    "success warning danger info selection focus hover pressed disabled placeholder "
    "backdrop shadow accentOn onSurface onSelection onHover onPressed onDisabled "
    "raised overlay input header sidebar tooltip popup essentialStroke".split()
)


def verify(condition, error):
    if not condition:
        raise ValueError(error)


def read_json(path):
    return json.loads((ROOT / path).read_text(encoding="utf-8"))


def digest(path):
    return sha256(path.read_bytes()).hexdigest()


def luminance(color):
    verify(re.fullmatch(r"#[0-9A-F]{6}", color) is not None, f"Invalid color: {color}")
    rgb = [int(color[index:index + 2], 16) / 255 for index in (1, 3, 5)]
    linear = [channel / 12.92 if channel <= 0.04045 else
              ((channel + 0.055) / 1.055) ** 2.4 for channel in rgb]
    return sum(channel * weight for channel, weight in zip(linear, (0.2126, 0.7152, 0.0722)))


def contrast(foreground, background):
    low, high = sorted(map(luminance, (foreground, background)))
    return (high + 0.05) / (low + 0.05)


def catalog_checks(components, themes):
    ids = {row["id"] for row in components}
    verify(len(ids) == len(components) == 159, "Expected 159 unique component IDs")
    verify(Counter(row["category"] for row in components) == CATEGORY_COUNTS,
           "Component category counts changed")
    verify([row["ordinal"] for row in components] == list(range(1, 160)), "Unexpected component order")
    verify(len({row["specLabel"] for row in components}) == 159, "Duplicated component type label")
    for row in components:
        verify(re.fullmatch(r"[A-Z][A-Za-z0-9]*", row["id"]), f"Invalid identifier: {row['id']}")
        verify(row["base"] is None or row["base"] in ids - {row["id"]}, f"Invalid base: {row['id']}")
        verify(row["mobileAcceptance"] and row["status"] == "NOT_IMPLEMENTED", f"Missing acceptance: {row['id']}")
        verify(row["testId"] == f"COMP-{row['ordinal']:03}", f"Unexpected test ID: {row['id']}")
        if row["valueModel"] in ("action", "structure"):
            verify(set(("Set", "Get", "Reset")) <= set(row["unsupportedOperations"]), f"Missing unsupported method: {row['id']}")

    verify(len(themes) == len({row["id"] for row in themes}) == 40, "Expected 40 unique themes")
    verify(len({row["geometry"] for row in themes}) == 40, "Duplicate theme geometry")
    verify([row["themeNumber"] for row in themes] == list(range(1, 41)), "Unexpected theme order")
    verify([row["name"] for row in themes if row["signature"]] ==
           ["Cultivation 仙", "Memoir 忆", "Noir", "Cosmic ✦"], "Signature theme order changed")
    text_ratios, control_ratios = [], []
    for row in themes:
        palette, tokens = row["palette"], row["tokens"]
        verify(REQUIRED_TOKENS <= tokens.keys(), f"Missing semantic colors: {row['id']}")
        verify(row["typography"]["nativeFallback"] and row["touch"]["minimumHitTarget"] >= 44,
               f"Missing mobile fallback: {row['id']}")
        surface = palette["surface"]
        text_pairs = [
            (palette["text"], palette["background"]), (tokens["onSurface"], surface),
            (tokens["accentOn"], palette["accent"]), (tokens["placeholder"], tokens["input"]),
            *[(tokens["on" + key.title()], tokens[key]) for key in ("selection", "hover", "pressed", "disabled")],
            *[(tokens[key], surface) for key in ("success", "warning", "danger", "info")],
        ]
        for foreground, background in text_pairs:
            ratio = contrast(foreground, background)
            verify(ratio >= 4.5, f"Text contrast {row['id']} {foreground}/{background}: {ratio:.3f}")
            text_ratios.append(ratio)
        for state in ("focus", "essentialStroke"):
            ratio = contrast(tokens[state], surface)
            verify(ratio >= 3.0, f"Essential contrast {row['id']}/{state}: {ratio:.3f}")
            control_ratios.append(ratio)
    return {
        "components": len(components), "themes": len(themes),
        "textContrastPairs": len(text_ratios), "minTextContrast": round(min(text_ratios), 3),
        "essentialContrastPairs": len(control_ratios), "minEssentialContrast": round(min(control_ratios), 3),
    }


def evidence_checks(components, themes):
    entries = read_json("design/traceability.json")
    ids = [item["featureId"] for item in entries]
    verify(len(set(ids)) == len(ids), "Repeated traceability IDs")
    verify({f"component.{row['id']}" for row in components} == {key for key in ids if key.startswith("component.")},
           "Component traceability is incomplete")
    verify({f"theme.{row['id']}" for row in themes} == {key for key in ids if key.startswith("theme.")},
           "Theme traceability is incomplete")
    for entry in entries:
        verify((ROOT / entry["sourceEvidence"]).is_file(), f"Missing evidence: {entry['featureId']}")
        if entry["featureId"].startswith("core."):
            path = entry["implementationFile"]
            verify(path and (ROOT / path).is_file() and entry["testedEnvironments"]
                   and entry["status"] == "PASS" and entry["robloxStatus"] == "IMPLEMENTED_UNTESTED",
                   f"Missing core evidence: {entry['featureId']}")
        else:
            verify(entry["implementationFile"] is None and not entry["testedEnvironments"] and
                   entry["status"] in ("NOT_IMPLEMENTED", "BLOCKED"),
                   f"Unfounded runtime evidence: {entry['featureId']}")

    auth = read_json("design/auth-compatibility.json")
    providers = {item["id"] for item in auth["providers"]}
    gateways = {item["name"] for item in auth["gateways"]}
    verify(len(providers) == len(auth["providers"]) == 11, "Expected 11 unique provider entries")
    verify(len(gateways) == len(auth["gateways"]) == 17, "Expected 17 unique gateways")
    verify(auth["liveVerifiedPairs"] == 0, "Live proof was not captured")
    auth_doc = (ROOT / "docs/auth.md").read_text(encoding="utf-8")
    mobile_doc = (ROOT / "docs/mobile.md").read_text(encoding="utf-8")
    for gateway in auth["gateways"]:
        statuses = gateway["pairEvidence"]
        verify(set(statuses) == providers and set(statuses.values()) <= auth["legend"].keys(),
               f"Invalid auth matrix row: {gateway['name']}")
        prefix = "| " + " | ".join([gateway["name"], *statuses.values()]) + " |"
        verify(prefix in auth_doc, f"Auth matrix table drift: {gateway['name']}")
    mobile_ids = re.findall(r"^\| (MOB-\d{2}) ", mobile_doc, re.M)
    verify(mobile_ids == [f"MOB-{n:02}" for n in range(1, 29)], "Missing mobile test design")
    verify(set(mobile_ids) == {x["testCase"] for x in entries if x["featureId"].startswith("mobile.")},
           "Mobile traceability is incomplete")
    font = read_json("evidence/font-license-samples.json")
    verify(font["verifiedRenderedFamilies"] == 0, "Invalid font render count")
    families = {sample["family"] for sample in font["samples"]}
    verify(families == {"Archivo", "Open Sans", "Share"}, "License sample set changed")
    for sample in font["samples"]:
        verify(sample["license"] == "OFL" and sample["files"] and
               all(re.fullmatch(r"[0-9a-f]{40}", sample[k]) for k in ("metadataBlob", "noticeBlob")),
               f"Missing source provenance: {sample['family']}")
    return {
        "traceabilityRows": len(ids), "providers": len(providers), "gateways": len(gateways),
        "providerGatewayPairs": len(providers) * len(gateways), "mobileScenarios": len(mobile_ids),
        "sampledLicenseFamilies": len(families), "verifiedRenderedFamilies": font["verifiedRenderedFamilies"],
    }


def local_links():
    count = 0
    for doc in sorted(ROOT.rglob("*.md")):
        for target in re.findall(r"\]\(([^\s)]+)\)", doc.read_text(encoding="utf-8")):
            if re.match(r"[a-z]+:", target) or target.startswith("#"):
                continue
            file = doc.parent / target.split("#", 1)[0]
            verify(file.resolve().is_relative_to(ROOT) and file.is_file(),
                   f"Broken local link {target} in {doc.relative_to(ROOT)}")
            count += 1
    return count


def check_spec(spec, manifest, components, themes):
    verify(digest(spec) == manifest["specification"]["sha256"], "Source specification SHA-256 mismatch")
    text = spec.read_text(encoding="utf-8")
    expected_components = []
    for name, count in CATEGORY_COUNTS.items():
        pattern = r"^\*\*" + re.escape(name) + rf" \({count}\):\*\* (.*?)\.$"
        match = re.search(pattern, text, re.M)
        verify(match is not None, f"Missing spec category {name}")
        expected_components.extend(match[1].split(", "))
    verify([row["specLabel"] for row in components] == expected_components, "Spec component list drift")
    expected_palettes = re.findall(r"^\| (\d{2}) \| \*\*(.*?)\*\* \| `([^\x60]+)` \|", text, re.M)
    actual = [(f'{row["themeNumber"]:02}', row["name"], " / ".join(row["palette"].values())) for row in themes]
    verify(actual == expected_palettes, "Theme labels/order/base colors differ from spec")


def check_hashes(manifest, manifest_path):
    expected = {row["path"]: row for row in manifest["files"]}
    actual = {file.relative_to(ROOT).as_posix() for file in ROOT.rglob("*")
              if file.is_file() and ".git" not in file.relative_to(ROOT).parts
              and "__pycache__" not in file.relative_to(ROOT).parts
              and file != manifest_path}
    verify(expected.keys() == actual, "Untracked or missing phase artifacts")
    for path, row in expected.items():
        file = ROOT / path
        verify(file.stat().st_size == row["bytes"] and digest(file) == row["sha256"], f"Artifact hash drift: {path}")
    return len(expected)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--spec", type=Path, help="Compare the original spec bytes and catalog contents")
    args = parser.parse_args()
    candidates = (file for file in ROOT.glob("phase*-manifest.json")
                  if re.fullmatch(r"phase[0-9]+-manifest\.json", file.name))
    manifest_path = max(candidates, key=lambda file: int(file.name[5:].split("-", 1)[0]))
    manifest = read_json(manifest_path.name)
    components = read_json("design/components.json")
    themes = read_json("design/themes.json")
    report = {**catalog_checks(components, themes), **evidence_checks(components, themes)}
    report["checkedLocalLinks"] = local_links()
    report["checkedArtifactHashes"] = check_hashes(manifest, manifest_path)
    if args.spec:
        check_spec(args.spec, manifest, components, themes)
    print(json.dumps({"status": "PASS", "matchedOriginalSpec": bool(args.spec), **report}, indent=2))


if __name__ == "__main__":
    try:
        main()
    except (ValueError, OSError, KeyError, TypeError) as exc:
        print(f"FAIL: {exc}", file=sys.stderr)
        sys.exit(1)
