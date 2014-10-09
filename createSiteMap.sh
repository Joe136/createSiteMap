#!/bin/bash
# See the file "license.terms" for information on usage and redistribution of
# this file, and for a DISCLAIMER OF ALL WARRANTIES.

unset USERNAME PASSWORD arg_rest cookies
unset wikiname baseurl xmlfile gvfile fdpfile dotfile twopifile depth from to fdpratio color

#wikiname=""
#baseurl=""

#xmlfile="$wikiname.xml"
#gvfile="$wikiname""_wiki.gv"
#fdpfile="$wikiname""_wiki.fdp.svg"
#dotfile="$wikiname""_wiki.dot.svg"
#twopifile="$wikiname""_wiki.twopi.svg"

depth=0
from=
to=

fdpratio=0.75
#fdpratio=0.562

color[1]="red"
color[2]="green"
color[3]="blue"
color[4]="yellow"
color[5]="violet"


##---------------------------Check Arguments---------------------------------------##
i=0
arg_rest_count=0

until test "$((i > -BASH_ARGC))" == "0"; do
   i=$((i - 1))
   curr_arg="${BASH_ARGV[$i]}"

   if [ "${curr_arg:0:2}" == "--" ]; then
      case "$curr_arg" in
      ##---------------------wikiname----------------------------------------------##
      --wikiname)
         i=$((i - 1))
         wikiname="${BASH_ARGV[$i]}"
      ;;
      ##---------------------depth-------------------------------------------------##
      --depth)
         i=$((i - 1))
         depth="${BASH_ARGV[$i]}"
      ;;
      ##---------------------from--------------------------------------------------##
      --from)
         i=$((i - 1))
         from="${BASH_ARGV[$i]}"
      ;;
      ##---------------------to----------------------------------------------------##
      --to)
         i=$((i - 1))
         to="${BASH_ARGV[$i]}"
      ;;
      ##---------------------fdpratio----------------------------------------------##
      --fdpratio)
         i=$((i - 1))
         fdpratio="${BASH_ARGV[$i]}"
      ;;
      ##---------------------update------------------------------------------------##
      --update)
         update=true
      ;;
      ##---------------------load-cookies------------------------------------------##
      --load-cookies)
         i=$((i - 1))
         cookies="${BASH_ARGV[$i]}"
      ;;
      ##---------------------xmlfile-----------------------------------------------##
      --xmlfile)
         i=$((i - 1))
         xmlfile="${BASH_ARGV[$i]}"
      ;;
      ##---------------------help--------------------------------------------------##
      --help)
         echo "createSiteMap V0.1.1"
         echo "Create visual (site)maps from MoinMoin-Wiki."
         echo ""
         echo "Options:"
         echo "   --help                 Show this help"
         echo "   --update               Update SiteMap-XML-File from Wiki (only public sites)"
         echo "   --load-cookies <file>  Define a Cookies-File to download form Wiki (see wget)"
         echo "   --load-cookies firefox Use Wiki-Login from Firefox"
         echo "   --wikiname <name>      The name of the Wiki"
         echo "   --depth <number>       Max page-depth"
         echo "   --from <char>          Only sites from this character"
         echo "   --to <char>            Only sites till this character"
         echo "   --fdpratio <number>    Image ratio for fdp sitemap"
         echo "   --xmlfile <file>       Use this file as SiteMap-XML-File"
         exit 0
      ;;
      esac
#   elif [ "$(echo -"$curr_arg" | head -c 2)" == "--" ]; then
#      args="$(echo -"$curr_arg" | awk 'BEGIN{FS=""}{ for (i = 3; i <= NF; ++i) print $i; }')"
#       for arg in `echo -e "$args"`; do
#         case "$arg" in
#         ##------------------System Name-------------------------------------------##
#         s)
#            arg_system="true"
#            i=$((i - 1))
#            system="${BASH_ARGV[$i]}"
#         ;;
#         esac
#      done
   else
      case "$curr_arg" in
      *)
         ##------------------Unknown Argument--------------------------------------##
         arg_rest[$arg_rest_count]="$curr_arg"
         ((++arg_rest_count))
      ;;
      esac
   fi
done


[[ -z "$wikiname" ]] && echo "error: no name defined" 1>&2 && exit 1


##---------------------------Set undefined values----------------------------------##
: ${xmlfile:="$wikiname.xml"}
: ${gvfile:="$wikiname""_wiki.gv"}
: ${fdpfile:="$wikiname""_wiki.fdp.svg"}
: ${dotfile:="$wikiname""_wiki.dot.svg"}
: ${twopifile:="$wikiname""_wiki.twopi.svg"}

[[ -n "$from" ]] && from="$(echo $from | tr '[:lower:]' '[:upper:]')" && from="$(printf '%d' "'$from")"
[[ -n "$to"   ]] && to="$(echo $to | tr '[:lower:]' '[:upper:]')"     && to="$(printf '%d' "'$to")"


# http://slacy.com/blog/2010/02/using-cookies-sqlite-in-wget-or-curl/
# This is the format of the sqlite database:
# CREATE TABLE moz_cookies (id INTEGER PRIMARY KEY, name TEXT, value TEXT, host TEXT, path TEXT,expiry INTEGER, lastAccessed INTEGER, isSecure INTEGER, isHttpOnly INTEGER);

# We have to copy cookies.sqlite, because FireFox has a lock on it
function extract_cookies_from_sqlite {
   cat "$1" > cookie-tmp.sqlite
   [[ -e "$1"-shm ]] && cat "$1"-shm > cookie-tmp.sqlite-shm
   [[ -e "$1"-wal ]] && cat "$1"-wal > cookie-tmp.sqlite-wal
   sqlite3 -separator ' ' cookie-tmp.sqlite << EOF
.mode tabs
.header off
select host,
case substr(host,1,1)='.' when 0 then 'FALSE' else 'TRUE' end, path,
case isSecure when 0 then 'FALSE' else 'TRUE' end, expiry, name, value from moz_cookies;
EOF
   rm -f cookie-tmp.sqlite
   rm -f cookie-tmp.sqlite-shm
   rm -f cookie-tmp.sqlite-wal
}


if [ "$update" == "true" ] || [ ! -e "$xmlfile" ]; then
   if [ -n "$cookies" ]; then
      # Use Cookie from Browser
      [[ "$cookies" == "firefox" ]] && ffpath="$(grep -Fe 'Path=' "$HOME/.mozilla/firefox/profiles.ini" | head -n 1)" && cookies="$HOME/.mozilla/firefox/${ffpath:5}/cookies.sqlite"

      # Use Cookie from Firefox-SQLite
      if [ "${cookies:((${#cookies}-7))}" == ".sqlite" ]; then
         extract_cookies_from_sqlite "$cookies" > cookie-tmp.txt
         cookies=cookie-tmp.txt
      fi

      wget --load-cookies "$cookies" "$baseurl$wikiname/?action=sitemap&underlay=0" -O "$xmlfile"

      [ -e cookie-tmp.txt ] && rm -f cookie-tmp.txt
   else
      #Only Public
      wget "$baseurl$wikiname/?action=sitemap&underlay=0" -O "$xmlfile"
   fi
fi


##---------------------------Get links from XML-Sitemap-File-----------------------##
list=$(grep --color -oEe "<loc>$baseurl$wikiname/[[:print:]]+</loc>" "$xmlfile")

echo -n "" > "$gvfile"
echo -n "" > "$gvfile-nodes"
echo -n "" > "$gvfile-edges"


##---------------------------Create GraphViz Edges---------------------------------##
tmpdepth=$depth
depth=1
for l in `echo -e "1\n2"`; do
   ((l == 2)) && depth=$tmpdepth

   for address in $list; do
      #echo ${address:34:-6} | sed 's/\//\" -> \"/g' | echo "   \""`cat -`\" >> "$gvfile"

      i=0
      oldnode=""
      href="${baseurl:0:-1}"

      for node in $(echo ${address:((${#baseurl}+5)):-6} | awk 'BEGIN{RS="/"}{print}'); do
         href="$href/$node"
         if ! grep -qFe "   \"$node\" [href=\"$href\"]" "$gvfile-nodes"; then
            echo "   \"$node\" [href=\"$href\"]" >>  "$gvfile-nodes"
         fi

         if ((i == 0)); then
            :
         elif ((i == 1)); then
            c="$(echo ${node:0:1} | tr '[:lower:]' '[:upper:]')"
            c="$(printf '%d' "'$c")"
            ( [[ -n "$from" ]] && ((c < from)) ) && break
            ( [[ -n "$to"   ]] && ((c > to)) ) && break

            if ! grep -qFe "   \"$oldnode\" -> \"$node\"" "$gvfile-edges"; then
               echo "   \"$oldnode\" -> \"$node\"" >> "$gvfile-edges"
            fi
         elif [ -n "${color[$i]}" ]; then
            if ! grep -qFe "   \"$oldnode\" -> \"$node\" [color=\"${color[$i]}\"]" "$gvfile-edges"; then
               echo "   \"$oldnode\" -> \"$node\" [color=\"${color[$i]}\"]" >> "$gvfile-edges"
            fi
         else
            if ! grep -qFe "   \"$oldnode\" -> \"$node\"" "$gvfile-edges"; then
               echo "   \"$oldnode\" -> \"$node\"" >> "$gvfile-edges"
            fi
         fi

         oldnode="$node"
         ((++i))

         ((depth != 0)) && ((i > depth)) && break
      done
   done
done


##---------------------------Convert HTML Special Characters-----------------------##
sed -i \
   -e 's/%C3%84/Ä/g' -e 's/%C3%A4/ä/g' -e 's/%C3%BC/ü/g' -e 's/%C3%9F/ß/g' \
   -e 's/%C3%96/Ö/g' -e 's/%C3%B6/ö/g' -e 's/%C3%9C/Ü/g' \
    -e 's/%3F/?/g' -e 's/%20/ /g' -e 's/%3A/:/g' \
   "$gvfile-nodes"

sed -i \
   -e 's/%C3%84/Ä/g' -e 's/%C3%A4/ä/g' -e 's/%C3%BC/ü/g' -e 's/%C3%9F/ß/g' \
   -e 's/%C3%96/Ö/g' -e 's/%C3%B6/ö/g' -e 's/%C3%9C/Ü/g' \
    -e 's/%3F/?/g' -e 's/%20/ /g' -e 's/%3A/:/g' \
   "$gvfile-edges"


##---------------------------Concatenate GraphViz File-----------------------------##
echo -e 'digraph "'"$(basename -s ".gv" "$gvfile")"'" {'"\n"\
'   graph [mindist=0.01,nodesep=0.01,ranksep=5,root="'$wikiname'"]'"\n"\
'   edge [color="'${color[1]}'"]'"\n"\
"\n"\
'   "'$wikiname'" [style=filled,shape=circle,fillcolor="blue"]'"\n"\
"\n"\
"`cat "$gvfile-nodes"`""\n"\
"\n"\
"`cat "$gvfile-edges"`""\n"\
'}' > "$gvfile"

rm "$gvfile-nodes" "$gvfile-edges"

#less "$gvfile" && exit


##---------------------------Build Graph Image-------------------------------------##
fdp   -Tsvg "-Gratio=$fdpratio" -o "$fdpfile"   "$gvfile"
dot   -Tsvg -o "$dotfile"   "$gvfile"
twopi -Tsvg -Granksep=8 -o "$twopifile" "$gvfile"

