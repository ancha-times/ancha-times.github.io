import json
import re
import sys

json_file=sys.argv[1]

# Open and read the JSON file
with open(json_file, 'r') as file:
    data = json.load(file)

pinned_comments = [
    comment
    for comment in data.get('comments', [])
    if comment.get('is_pinned')
]

separator = '<p>~ ~ ~ ~ ~</p>'
timestamp_pattern = re.compile(r'(\d\d?:)?\d\d?:\d\d')

def to_seconds(comment):
    match = timestamp_pattern.search(comment['text'])
    parts = list(map(int, match.group().split(':')))

    # If format is MM:SS
    if len(parts) == 2:
        minutes, seconds = parts
        return minutes * 60 + seconds

    # If format is H:MM:SS
    if len(parts) == 3:
        hours, minutes, seconds = parts
        return hours * 3600 + minutes * 60 + seconds


for pinned_comment in pinned_comments:
    if timestamp_pattern.search(pinned_comment.get('text', '')):
        print(separator + pinned_comment['text'])

    children = [
        c for c in data['comments']
        if c.get('parent') == pinned_comment['id']
        and timestamp_pattern.search(c.get('text', ''))
    ]

    children.sort(key=to_seconds)

    for child in children:
        print(separator + child['text'])
