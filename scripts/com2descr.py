import sys
import json

json_file=sys.argv[1]

# Open and read the JSON file
with open(json_file, 'r') as file:
    data = json.load(file)

pinned_comments=[]

for comment in data['comments']:
    if comment['is_pinned']:
        pinned_comments.append(comment['id'])
    if comment['is_pinned'] or comment['parent'] in pinned_comments:
        print('<hr>'+comment['text'])
