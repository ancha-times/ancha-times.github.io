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

for f in `find -iname '*.description' | sort`; do
	fn="`echo "$f" | sed -r 's/^..//;s/.description$//'`"
	id="`echo "$fn" | cut -c 10-20`"
	url="https://www.youtube.com/watch?v=$id"
	date="`echo "$fn" | sed -r 's/^(....)(..)(..).*/\1-\2-\3/'`"
	type="`echo "$fn" | cut -c 22`"
	title="`echo "$fn" | cut -c 24-`"

	echo "$id / $date / $type / $title" >&2

	exec >>"$TIMES"

	echo "<details id='s$id' class='$type'><summary><h2><a href='$url'>$date</a> - $title</h2></summary>"
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
