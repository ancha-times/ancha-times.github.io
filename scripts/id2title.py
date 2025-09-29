import os
import pickle
import re
import sys

id2title_file=sys.argv[1]

id2title={}

files = os.listdir('.')
for filename in files:
    mm=re.match('.{8}-.{10}-(.{11})-.-(.*).description$', filename)
    if mm:
        id=mm.group(1)
        title=mm.group(2)
        id2title[id]=title

with open(id2title_file, "wb") as file:
        pickle.dump(id2title, file)

