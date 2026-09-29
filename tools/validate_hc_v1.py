#!/usr/bin/env python3
"""G1 check for HC-V1. Regions are placed. The spine matches the atlas. Systems stay unauthored."""

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / "world" / "hc_v1"
SYSTEM_RE = re.compile(r"^HC-V1-R([1-8])-S([1-6])$")
BAD_NAME = re.compile(r"^(Planet \d+|Rock-\d+|Meteor Field [A-Z])$")

COORDS = {
    "R1": (0, 0),
    "R2": (2, 0),
    "R3": (4, 0),
    "R4": (4, -2),
    "R5": (2, 2),
    "R6": (0, 2),
    "R7": (2, 4),
    "R8": (2, 6),
}

FLAGSHIPS = {
    "R1": ("Aegis Prime", "city-orbital"),
    "R2": ("Tallyrock", "world"),
    "R3": ("Spindle", "city-world"),
    "R4": ("Ash Hymn", "world"),
    "R5": ("Green Wound", "shard"),
    "R6": ("The Swallow", "field"),
    "R7": ("Step", "rock"),
    "R8": ("Quay", "platform"),
}

LAWS = {
    "R1": "green heavy",
    "R2": "amber",
    "R3": "green at worlds, amber between",
    "R4": "green that shoots",
    "R5": "amber / claim country",
    "R6": "amber / red pockets",
    "R7": "red",
    "R8": "red",
}

SPINE = [
    ("spine-helion-brass", "HC-V1-R1-S1", "HC-V1-R1-S2", "green", "green spine"),
    ("spine-brass-lease", "HC-V1-R1-S2", "HC-V1-R2-S1", "green", "green spine"),
    ("spine-lease-towline", "HC-V1-R2-S1", "HC-V1-R2-S2", "green", "green spine"),
    ("spine-towline-haven", "HC-V1-R2-S2", "HC-V1-R3-S1", "green", "green spine"),
    ("spine-haven-choir", "HC-V1-R3-S1", "HC-V1-R4-S1", "green", "checkpoint"),
    ("spine-lease-first-soil", "HC-V1-R2-S1", "HC-V1-R5-S1", "amber", "homestead road"),
    ("spine-first-soil-perimeter", "HC-V1-R5-S1", "HC-V1-R5-S6", "amber", "homestead road"),
    ("spine-perimeter-marchport", "HC-V1-R5-S6", "HC-V1-R7-S1", "mixed", "red road"),
    ("spine-marchport-black-quay", "HC-V1-R7-S1", "HC-V1-R8-S1", "red", "red road"),
    ("spine-writ-gyre", "HC-V1-R1-S3", "HC-V1-R6-S1", "amber", "confiscated hulls"),
    ("spine-haven-not-ours", "HC-V1-R3-S1", "HC-V1-R3-S4", "green", "jurisdiction hole"),
    ("spine-not-ours-empty-tithe", "HC-V1-R3-S4", "HC-V1-R7-S3", "mixed", "jurisdiction hole"),
]

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

    check(schema.get("schema") == "hc_v1_g1", "schema id is hc_v1_g1")
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
        ("streams.json", "streams"),
        ("trash_origins.json", "origins"),
        ("claim_slots.json", "slots"),
    ):
        doc = load(catalog)
        check(doc.get("status") == "template" and doc.get(key) == [], f"{catalog} is an empty template")

    lanes = load("lanes.json")
    check(lanes.get("status") == "placed" and lanes.get("placed") is True, "spine map is placed")
    check(len(lanes["lanes"]) == len(SPINE), "spine has the atlas arrows and no extras")
    names = {row["id"]: row["name"] for row in ids["systems"]}
    seen_lanes = set()
    region_of = {}
    for row in ids["systems"]:
        region_of[row["id"]] = row["region"]
    touched = set()
    for expected, lane in zip(SPINE, lanes["lanes"]):
        lid, src, dst, color, traffic = expected
        seen_lanes.add(lane.get("id"))
        check(lane.get("id") == lid, f"lane id {lid}")
        check(lane.get("from") == src and lane.get("to") == dst, f"{lid} endpoints")
        check(names.get(src) and names.get(dst), f"{lid} uses locked systems")
        check(lane.get("rule_color") == color, f"{lid} keeps its rule color")
        check(lane.get("traffic") == traffic, f"{lid} keeps its atlas job")
        check(lane.get("pdo_response_time") == "", f"{lid} has no travel time yet")
        check("travel_time" not in lane and "market" not in lane, f"{lid} leaves markets for G11")
        touched.add(region_of[src])
        touched.add(region_of[dst])
    check(seen_lanes == {row[0] for row in SPINE}, "lane ids are the spine set")
    check(touched == set(LOCKED), "spine reaches all eight regions")

    positions = {row["id"]: (row["x"], row["y"]) for row in lanes["regions"]}
    palettes = set()
    for rid, (name, _systems) in LOCKED.items():
        region = load(f"regions/{rid}.json")
        check(region["region_id"] == rid and region["name"] == name, f"{rid} file keeps the atlas name")
        check(region["status"] == "placed" and region["map"]["placed"] is True, f"{rid} is placed")
        check((region["map"]["x"], region["map"]["y"]) == COORDS[rid], f"{rid} coordinates")
        check(positions.get(rid) == COORDS[rid], f"{rid} matches the lane map")
        check(region["system_ids"] == [row["id"] for row in by_region[rid]], f"{rid} file lists its systems")
        check((region["flagship"], region["flagship_kind"]) == FLAGSHIPS[rid], f"{rid} flagship stays locked")
        check(region["law"] == LAWS[rid], f"{rid} law phrase stays locked")
        check(region["palette"] not in palettes and region["palette"].startswith("#"), f"{rid} palette is its own color")
        palettes.add(region["palette"])

    authored = [
        path for path in (ROOT / "systems").glob("*.json")
        if path.name != "_template.json"
    ]
    check(authored == [], "no authored system files yet")
    check((ROOT / "HC_V1_FIRST_GALAXY_ATLAS.md").is_file(), "atlas file is in the folder")
    check((ROOT / "atlas.md").read_text() == (ROOT / "HC_V1_FIRST_GALAXY_ATLAS.md").read_text(), "atlas.md matches the locked atlas")

    if failed:
        print("HC-V1 G1 FAIL")
        return 1
    print("HC-V1 G1 PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
