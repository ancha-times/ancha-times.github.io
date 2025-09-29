import os
import pickle
import re
import sys

my_id=sys.argv[1]
base_url=sys.argv[2]
base_dir='.'
id2title_file=sys.argv[3]

text=sys.stdin.read()

text=text.replace('https://www.youtube.com/edit?o=U&video_id=', 'https://www.youtube.com/watch?v=')

with open(id2title_file, 'rb') as file:
    id2title = pickle.load(file)

def http2link(m):
    url=title=m.group(0)
    rest=''

    # cut trailing dots and commas, if any
    mm=re.search('[,.)]*$', url)
    if mm.group(0):
        url=title=url[:-len(mm.group(0))]
        rest=mm.group(0)

    # fancy formatting for known youtube videos
    for prefix in ['https://www.youtube.com/watch?v=', 'https://www.youtube.com/live/', 'https://youtube.com/live/', 'https://youtu.be/']:
        if url.startswith(prefix):
            id=url[len(prefix):]
            id=id[:11]
            if id in id2title:
                title=id2title[id]
                return '<a href="{}" data-id="{}">{}</a>{}<sup><a href="#s{}">[#]</a></sup>'.format(url,id,title,rest,id)

    return '<a href="{}">{}</a>{}'.format(url,title,rest)

text=re.sub('https?://[^\\s<>]*',http2link,text)

def time2link(m):
	hms=m.group(0).split(':')
	if len(hms)==2:
		hms.insert(0,'0')
	hms=list(map(lambda x: int(x), hms))
	sec=hms[0]*60*60 + hms[1]*60 + hms[2]
	url=base_url+str(sec)
	return '<a href="{}" data-id="{}" data-sec="{}">{}</a>'.format(url,my_id,sec,m.group(0))

print(re.sub('(\\d\\d?:)?\\d\\d?:\\d\\d',time2link,text))

