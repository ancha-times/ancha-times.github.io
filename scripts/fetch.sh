#!/bin/sh

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

set -ex

# download yt-dlp
test -f yt-dlp || curl -L https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp >yt-dlp
chmod a+x ./yt-dlp

./yt-dlp -U --ignore-errors --write-auto-sub --sub-lang ru --sub-format srv1 --skip-download --write-description --write-comments --extractor-args "youtube:max_comments=all,2,100,all" -o '%(upload_date)s-%(timestamp)s-%(id)s-v-%(title)s.%(ext)s' --download-archive da.txt 'https://www.youtube.com/channel/UCXJYy66gIOEsT04ndBUBFPw/videos' || echo 'ignoring errors...'
./yt-dlp    --ignore-errors --write-auto-sub --sub-lang ru --sub-format srv1 --skip-download --write-description --write-comments --extractor-args "youtube:max_comments=all,2,100,all" -o '%(upload_date)s-%(timestamp)s-%(id)s-l-%(title)s.%(ext)s' --download-archive da.txt 'https://www.youtube.com/channel/UCXJYy66gIOEsT04ndBUBFPw/streams' || echo 'ignoring errors...'
./yt-dlp    --ignore-errors --write-auto-sub --sub-lang ru --sub-format srv1 --skip-download --write-description -o '%(upload_date)s-%(timestamp)s-%(id)s-s-%(title)s.%(ext)s' --download-archive da.txt 'https://www.youtube.com/channel/UCXJYy66gIOEsT04ndBUBFPw/shorts' || echo 'ignoring errors...'

# rm channel description
rm -f NA-NA-UCXJYy66gIOEsT04ndBUBFPw*

rm -f da.txt da.txt.new

export IFS='
'

for f in `find -iname '*.info.json'`; do
	fn="`echo "$f" | sed -r 's/^..//;s/.info.json$//'`"
	jq '.comments | map(del(._time_text, .timestamp)) | {comments: .}' "$fn.info.json" >"$fn.comments.json"
	rm $f
done

cd "$TOP"

test "$(git status --porcelain data)" = "" && exit 0 || true

git add data
git commit -m "$(date +%F) update"
git push
