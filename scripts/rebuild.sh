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

cp "$TEMPLATES/subs.txt" "$SUBS"

sed '/HERE/,$d' "$TEMPLATES/times.html" >"$TIMES"

set -e

export IFS='
'

cd "$DATA"

python3 "$BIN/id2title.py" "$TMP/id2title.dat"

for f in `find -iname '*.description' | sort -r`; do
	fn="`echo "$f" | sed -r 's/^..//;s/.description$//'`"
	id="`echo "$fn" | cut -c 21-31`"
	url="https://www.youtube.com/watch?v=$id"
	date="`echo "$fn" | sed -r 's/^(....)(..)(..).*/\1-\2-\3/'`"
	type="`echo "$fn" | cut -c 33`"
	title="`echo "$fn" | cut -c 35-`"

	echo "$id / $date / $type / $title" >&2

	exec >>"$TIMES"

	echo "<details id='s$id' class='$type'><summary><h2><a href='$url' data-id='$id'>$date</a> <span class='type'></span> $title</h2></summary>"
	{
		cat $fn.description
		test -f $fn.comments.json && python3 "$BIN/com2descr.py" $fn.comments.json || true
	} | python3 "$BIN/linkify.py" "$id" "$url&t=" "$TMP/id2title.dat" | sed 's/$/<br>/'
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
