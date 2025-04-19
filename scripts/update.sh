#!/bin/sh

BIN="$(dirname "$(realpath $0)")"
TOP="$(dirname "$BIN")"
DATA="$TOP/data"
TEMPLATES="$TOP/templates"
OUT="$TOP/html"
TIMES="$OUT/times.html"
SUBS="$OUT/subs.txt"

cd "$DATA"

# delete duplicate description files
ls *.description | cut -c10-20 | uniq -c | awk '$1=='2' {print $2}' | xargs -I % sh -c 'rm *%*'

set -ex

# delete last 12 entries, to force their refresh
head -n -12 da.txt >da.txt.new
mv da.txt.new da.txt

# download yt-dlp
#python3 -c 'import urllib.request; urllib.request.urlretrieve("https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp", "asd")'
curl -L https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp >yt-dlp
chmod a+x ./yt-dlp

./yt-dlp --ignore-errors --write-auto-sub --sub-lang ru --sub-format srv1 --skip-download --write-description -o '%(upload_date)s-%(id)s-%(title)s.%(ext)s' --download-archive da.txt --force-write-archive 'https://www.youtube.com/channel/UCXJYy66gIOEsT04ndBUBFPw' || echo 'ignoring errors...'

# rm channel description
rm -f NA-UCXJYy66gIOEsT04ndBUBFPw*

rm -f yt-dlp

cp "$TEMPLATES/subs.txt" "$SUBS"

sed '/HERE/,$d' "$TEMPLATES/times.html" >"$TIMES"

set +x

export IFS='
'

for f in `ls -1 *.description`; do
	fn="`echo "$f" | sed -r 's/.description$//'`"
	id="`echo "$fn" | cut -c 10-20`"
	url="https://www.youtube.com/watch?v=$id"
	date="`echo "$fn" | sed -r 's/^(....)(..)(..).*/\1-\2-\3/'`"
	title="`echo "$fn" | cut -c 22-`"

	echo "$id / $date / $title" >&2

	exec >>"$TIMES"

	echo "<details id="s$id"><summary><h2><a href='$url'>$date</a> - $title</h2></summary>"
	cat $fn.description | python3 "$BIN/linkify.py" "$url&t=" | sed 's/$/<br>/'
	echo '</details>'

	test -f $fn.ru.srv1 || continue

	exec >>"$SUBS"

	echo "$date - $title"
	echo "$url"
	echo "$url" | sed 's/./=/g'
	cat $fn.description
	echo
	echo "$url" | sed 's/./-/g'
	# TI:ME only
	# cat $fn.ru.ttml | sed -r '/^<p/!d;s!<p begin="([0-9:]*)[^>]*>(.*)</p>$!\1 \2!'
	# youtube://URL
	cat $fn.ru.srv1 | sed 's/<text start="/\n/g' | sed -r "1d;s!^([0-9]*)[^>]*>(.*)</text>.*!$url\&t=\1s \2!"
	echo
	echo
	
done

exec >/dev/null

set -x

sed '1,/HERE/d' "$TEMPLATES/times.html" >>"$TIMES"

cd "$OUT"

zip -l subs.zip subs.txt
gzip -f subs.txt
