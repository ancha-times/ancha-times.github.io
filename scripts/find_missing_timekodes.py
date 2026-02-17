import json
import glob
import re

timestamp_pattern = re.compile(r'\d:\d\d')

for filename in glob.glob("data/*.comments.json"):
    with open(filename) as f:
        try:
            comments = json.load(f).get("comments", [])
        except Exception:
            continue

    pinned_comments = [
        c for c in comments
        if c.get("is_pinned")
    ]

    for pinned in pinned_comments:
        pid = pinned["id"]

        # Check if pinned comment has children
        has_child = any(
            c.get("parent") == pid
            for c in comments
        )

        if has_child:
            continue

        # Count timestamps in pinned comment text
        timestamps = timestamp_pattern.findall(
            pinned.get("text", "")
        )

        if len(timestamps) < 4:
            print(filename)
            break  # avoid duplicate prints per file

