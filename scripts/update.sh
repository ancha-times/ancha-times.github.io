#!/bin/sh

BIN="$(dirname "$(realpath $0)")"
TOP="$(dirname "$BIN")"
DATA="$TOP/data"
TEMPLATES="$TOP/templates"
OUT="$TOP/html"
TMP="$TOP/tmp"
TIMES="$OUT/times.html"
SUBS="$TMP/subs.nix.txt"
DOSUBS="$TMP/subs.dos.txt"

mkdir -p "$TMP"

cd "$TOP"

git fetch
git reset --hard origin/main

cd "$DATA"

# delete duplicate description files
ls *.description | cut -c10-20 | sort | uniq -c | awk '$1=='2' {print $2}' | xargs -I % sh -c 'rm *%*'

# create new da file
ls *.description | sed -r 's_^[^-]*-(.{11})-.*_youtube \1_' >da.txt.new

# delete last 12 entries, to force their refresh
head -n -12 da.txt.new >da.txt

set -ex

# download yt-dlp
curl -L https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp >yt-dlp
chmod a+x ./yt-dlp

./yt-dlp --ignore-errors --write-auto-sub --sub-lang ru --sub-format srv1 --skip-download --write-description -o '%(upload_date)s-%(id)s-%(title)s.%(ext)s' --download-archive da.txt 'https://www.youtube.com/channel/UCXJYy66gIOEsT04ndBUBFPw' || echo 'ignoring errors...'

# rm channel description
rm -f NA-UCXJYy66gIOEsT04ndBUBFPw*

rm -f da.txt da.txt.new

rm -f yt-dlp

cp "$TEMPLATES/subs.txt" "$SUBS"

sed '/HERE/,$d' "$TEMPLATES/times.html" >"$TIMES"

set +x

export IFS='
'

for f in `find -iname '*.description' | sort`; do
	fn="`echo "$f" | sed -r 's/^..//;s/.description$//'`"
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
sed '/\r/! s/$/\r/' "$SUBS" >"$DOSUBS"

cd -

test "$(git status --porcelain data html)" = "" && exit 0 || true


git add data html
git commit -m "$(date +%F) update"
git push

gh release delete subs --cleanup-tag --yes
gh release create subs "$SUBS" "$DOSUBS" --generate-notes
