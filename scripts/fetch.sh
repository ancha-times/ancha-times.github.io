#!/bin/bash

BIN="$(dirname "$(realpath $0)")"
TOP="$(dirname "$BIN")"
DATA="$TOP/data"

cd "$TOP"

cd "$DATA"

# delete duplicate description files
ls *.description | cut -c21-31 | sort | uniq -c | awk '$1=='2' {print $2}' | xargs -I % sh -c 'rm *%*'

# create new da file
ls *.description | sed -r 's_^.{8}-.{10}-(.{11})-.*_youtube \1_' >da.txt.new

# delete last 12 entries, to force their refresh
head -n -12 da.txt.new >da.txt

# download yt-dlp
YT_DLP=$TOP/tmp/yt-dlp
test -f $YT_DLP && $YT_DLP -U || curl -L https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp >$YT_DLP
chmod a+x $YT_DLP

# fetch comments for 4 latest live/videos without them
# (should move into the past starting at 20250620)
comm -23 --check-order <(ls *-v-*.description *-l-*.description | sed 's/.description$//') <(ls *-v-*.comments.json *-l-*.comments.json | sed 's/.comments.json$//') | tail -n3 | while read -r fn; do
  id="`echo "$fn" | cut -c 21-31`"
  $YT_DLP --write-comments --extractor-args "youtube:lang=ru;max_comments=all,1,100,all" --skip-download "https://www.youtube.com/watch?v=$id" -o "$fn"
done

set -ex

$YT_DLP --ignore-errors --write-auto-sub --sub-lang ru --sub-format srv1 --skip-download --write-description --extractor-args "youtube:lang=ru;max_comments=all,1,100,all" --write-comments -o '%(upload_date)s-%(timestamp)s-%(id)s-v-%(title)s.%(ext)s' --download-archive da.txt 'https://www.youtube.com/channel/UCXJYy66gIOEsT04ndBUBFPw/videos' -U || echo 'ignoring errors...'
$YT_DLP --ignore-errors --write-auto-sub --sub-lang ru --sub-format srv1 --skip-download --write-description --extractor-args "youtube:lang=ru;max_comments=all,1,100,all" --write-comments -o '%(upload_date)s-%(timestamp)s-%(id)s-l-%(title)s.%(ext)s' --download-archive da.txt 'https://www.youtube.com/channel/UCXJYy66gIOEsT04ndBUBFPw/streams'   || echo 'ignoring errors...'
$YT_DLP --ignore-errors --write-auto-sub --sub-lang ru --sub-format srv1 --skip-download --write-description --extractor-args "youtube:lang=ru" -o '%(upload_date)s-%(timestamp)s-%(id)s-s-%(title)s.%(ext)s' --download-archive da.txt 'https://www.youtube.com/channel/UCXJYy66gIOEsT04ndBUBFPw/shorts' || echo 'ignoring errors...'

# rm channel description
rm -f NA-NA-UCXJYy66gIOEsT04ndBUBFPw*

rm -f da.txt da.txt.new

export IFS='
'

for f in `find -iname '*.info.json'`; do
	fn="`echo "$f" | sed -r 's/^..//;s/.info.json$//'`"
	jq '.comments | map(del(._time_text, .timestamp, .like_count)) | {comments: .}' "$fn.info.json" >"$fn.comments.json"
	grep -q '^\s*"is_pinned": true,\?$' "$fn.comments.json" || echo '{comments: []}' >"$fn.comments.json"
	rm $f
done

cd "$TOP"

test "$(git status --porcelain data)" = "" && exit 0 || true

git add data
git commit -m "$(date +%F) update"
git push
