#!/usr/bin/env python3
"""G0 check for HC-V1. Templates must hold the schema. Authored systems are not this slice."""

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / "world" / "hc_v1"
SYSTEM_RE = re.compile(r"^HC-V1-R([1-8])-S([1-6])$")
BAD_NAME = re.compile(r"^(Planet \d+|Rock-\d+|Meteor Field [A-Z])$")

LOCKED = {
    "R1": ("Compact Core", ["Helion Dock", "Brass Lantern", "Writ", "White Wake", "Ledger", "Quiet Sun"]),
    "R2": ("Charter Belt", ["Lease", "Towline", "Ore Choir", "Stamped Ice", "Second Copy", "Fine Print"]),
    "R3": ("Municipal Skies", ["Haven Wheel", "Lower Stack", "Guest Lamp", "Not Ours", "Cinder Parish", "After Hours"]),
    "R4": ("Glass Quarantine", ["Choir Gate", "Sealed Orchard", "Sporefall", "Ash Hymn", "Clean Hands", "The Exception"]),
    "R5": ("Garden Shards", ["First Soil", "Two Weathers", "Pollinator Road", "Broken Charter", "Silo Dark", "Perimeter"]),
    "R6": ("Drift and Fall", ["Gyre", "Clockstream", "Nameless Chart", "Hullweather", "Iron Rain", "Last Beacon"]),
    "R7": ("Rimward Marches", ["Marchport", "Letter", "Empty Tithe", "Crossed Flags", "Claimwake", "No Witness"]),
    "R8": ("Black Sail Grounds", ["Black Quay", "False Choir", "Seedcut", "Twin Wake", "Deep Hold", "The Joke"]),
}


def load(name: str):
    path = ROOT / name
    with path.open() as handle:
        return json.load(handle)


def main() -> int:
    failed = False

    def check(ok: bool, label: str) -> None:
        nonlocal failed
        print(("ok: " if ok else "FAIL: ") + label)
        failed = failed or not ok

    schema = load("schema.json")
    ids = load("ids.json")
    system_template = load("systems/_template.json")
    region_template = load("regions/_template.json")

    check(schema.get("schema") == "hc_v1_g0", "schema id is hc_v1_g0")
    check(ids.get("catalog") == "HC-V1", "catalog is HC-V1")
    check(len(ids["regions"]) == 8, "eight regions")
    check(len(ids["systems"]) == 48, "forty-eight system ids")

    seen = set()
    by_region = {region: [] for region in LOCKED}
    for entry in ids["systems"]:
        sid = entry["id"]
        match = SYSTEM_RE.match(sid)
        check(match is not None, f"id grammar {sid}")
        check(sid not in seen, f"unique {sid}")
        seen.add(sid)
        check(not BAD_NAME.match(entry["name"]), f"name is not a clone label: {entry['name']}")
        if match:
            by_region[f"R{match.group(1)}"].append(entry)

    for region in ids["regions"]:
        rid = region["id"]
        locked_name, locked_systems = LOCKED[rid]
        check(region["name"] == locked_name, f"{rid} keeps the atlas name")
        check(region["system_ids"] == [row["id"] for row in by_region[rid]], f"{rid} id list matches systems")
        names = [row["name"] for row in by_region[rid]]
        check(names == locked_systems, f"{rid} system names stay locked")

    required = schema["system_required"]
    check(all(key in system_template for key in required), "system template has every required key")
    check(system_template["status"] == "template", "system template is not authored")
    check(system_template["why_visit"] == "", "template why_visit stays empty")
    check(system_template["bodies"] == [], "template has no invented bodies")
    check("map" in region_template and region_template["map"]["placed"] is False, "region map is unplaced")

    for catalog, key in (
        ("lanes.json", "lanes"),
        ("streams.json", "streams"),
        ("trash_origins.json", "origins"),
        ("claim_slots.json", "slots"),
    ):
        doc = load(catalog)
        check(doc.get("status") == "template" and doc.get(key) == [], f"{catalog} is an empty template")

    authored = [
        path for path in (ROOT / "systems").glob("*.json")
        if path.name != "_template.json"
    ]
    check(authored == [], "no authored system files in G0")
    check((ROOT / "HC_V1_FIRST_GALAXY_ATLAS.md").is_file(), "atlas file is in the folder")
    check((ROOT / "atlas.md").read_text() == (ROOT / "HC_V1_FIRST_GALAXY_ATLAS.md").read_text(), "atlas.md matches the locked atlas")

    if failed:
        print("HC-V1 G0 FAIL")
        return 1
    print("HC-V1 G0 PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
