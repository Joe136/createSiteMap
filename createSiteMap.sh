#!/bin/bash
# See the file "license.terms" for information on usage and redistribution of
# this file, and for a DISCLAIMER OF ALL WARRANTIES.

unset USERNAME PASSWORD arg_rest cookies
unset wikiname urlname baseurl xmlfile gvfile fdpfile dotfile twopifile depth from to
unset fdpratio color exclude excludesub verbose unique update

#wikiname=""
#baseurl=""

depth=0

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
      --baseurl)      i=$((i - 1)); baseurl="${BASH_ARGV[$i]}" ;;
      --depth)        i=$((i - 1)); depth="${BASH_ARGV[$i]}" ;;
      --exclude)      i=$((i - 1)); exclude="$exclude,${BASH_ARGV[$i]}" ;;
      --excludesub)   i=$((i - 1)); excludesub="$excludesub,${BASH_ARGV[$i]}" ;;
      --fdpratio)     i=$((i - 1)); fdpratio="${BASH_ARGV[$i]}" ;;
      --from)         i=$((i - 1)); from="${BASH_ARGV[$i]}" ;;
      --load-cookies) i=$((i - 1)); cookies="${BASH_ARGV[$i]}" ;;
      --to)           i=$((i - 1)); to="${BASH_ARGV[$i]}" ;;
      --unique)       unique=true ;;
      --update)       update=true ;;
      --urlname)      i=$((i - 1)); urlname="${BASH_ARGV[$i]}"; setun=true ;;
      --verbose)      verbose=true ;;
      --wikiname)     i=$((i - 1)); wikiname="${BASH_ARGV[$i]}" ;;
      --xmlfile)      i=$((i - 1)); xmlfile="${BASH_ARGV[$i]}" ;;
      --help)
         echo "CreateSiteMap V0.1.5"
         echo "Create visual (site)maps from MoinMoin-Wiki."
         echo ""
         echo "Options:"
         echo "   --help                  Show this help"
         echo "   --verbose               Print more info"
         echo "   --update                Update SiteMap-XML-File from Wiki (only public sites)"
         echo "   --load-cookies <file>   Define a Cookies-File to download form Wiki (see wget)"
         echo "   --load-cookies firefox  Use Wiki-Login from Firefox"
         echo "   --wikiname <name>       The name of the Wiki"
         echo "   --urlname <name>        The postfix of the URL"
         echo "   --exclude <site>,...    Sites to exclude from creation"
         echo "   --excludesub <site>,... Sites to exclude the subpages from creation"
         echo "   --unique                Prevent collisions of identical page names"
         echo "   --depth <number>        Max page-depth"
         echo "   --from <char>           Only sites from this character"
         echo "   --to <char>             Only sites till this character"
         echo "   --fdpratio <number>     Image ratio for fdp sitemap"
         echo "   --xmlfile <file>        Use this file as SiteMap-XML-File"
         exit 0
      ;;
      esac
#   elif [ "$(echo -"$curr_arg" | head -c 2)" == "--" ]; then
#      args="$(echo -"$curr_arg" | awk 'BEGIN{FS=""}{ for (i = 3; i <= NF; ++i) print $i; }')"
#       for arg in `echo -e "$args"`; do
#         case "$arg" in
#         s) arg_system="true"; i=$((i - 1)); system="${BASH_ARGV[$i]}" ;;
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

[[ -z "$setun"      ]] && urlname="$wikiname"
[[ -n "$exclude"    ]] && exclude=",$exclude,"
[[ -n "$excludesub" ]] && excludesub=",$excludesub,"
[[ -n "$from"       ]] && from="$(echo $from | tr '[:lower:]' '[:upper:]')" && from="$(printf '%d' "'$from")"
[[ -n "$to"         ]] && to="$(echo $to | tr '[:lower:]' '[:upper:]')"     && to="$(printf '%d' "'$to")"


##---------------------------Download Sitemap from page----------------------------##
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
   [[ "$verbose" == "true" ]] && echo "CreateSiteMap: verbose: download SiteMap-XML-File"

   if [ -n "$cookies" ]; then
      # Use Cookie from Browser
      [[ "$cookies" == "firefox" ]] && ffpath="$(grep -Fe 'Path=' "$HOME/.mozilla/firefox/profiles.ini" | head -n 1)" && cookies="$HOME/.mozilla/firefox/${ffpath:5}/cookies.sqlite"

      # Use Cookie from Firefox-SQLite
      if [ "${cookies:((${#cookies}-7))}" == ".sqlite" ]; then
         extract_cookies_from_sqlite "$cookies" > cookie-tmp.txt
         cookies=cookie-tmp.txt
      fi

      wget --load-cookies "$cookies" "$baseurl$urlname/?action=sitemap&underlay=0" -O "$xmlfile"

      [ -e cookie-tmp.txt ] && rm -f cookie-tmp.txt
   else
      #Only Public
      wget "$baseurl$urlname/?action=sitemap&underlay=0" -O "$xmlfile"
   fi
fi


##---------------------------Get links from XML-Sitemap-File-----------------------##
addresslist=$(grep --color -oEe "<loc>$baseurl$urlname/[[:print:]]+</loc>" "$xmlfile")

echo -n "" > "$gvfile"
echo -n "" > "$gvfile-nodes"
echo -n "" > "$gvfile-edges"


##---------------------------Create GraphViz Edges---------------------------------##
[[ "$verbose" == "true" ]] && echo "CreateSiteMap: verbose: parse graph from SiteMap-XML-File"
tmpdepth=$depth
depth=1
if [ "${baseurl:((${#baseurl}-1))}" == "/" ]; then basehref="${baseurl:0:-1}"; else basehref="$baseurl"; fi

for l in `echo -e "1\n2"`; do
   ((l == 2)) && depth=$tmpdepth

   IFS=$'\n'
   for address in $addresslist; do
      #echo ${address:34:-6} | sed 's/\//\" -> \"/g' | echo "   \""`cat -`\" >> "$gvfile"

      i=0
      oldnode=""
      label=""
      oldlabel=""
      uniquenode=""
      href="$basehref"
      nodelist="$(echo ${address:((${#baseurl}+5)):-6} | awk 'BEGIN{RS="/"}{print}')"
      [[ -z "$urlname" ]] && nodelist="$wikiname $nodelist"

      for node in $nodelist; do
         [[ -n "$exclude" ]] && echo "$exclude" | grep -qFe ",$node," && break
         [[ -n "$excludesub" ]] && ((i > 1)) && echo "$excludesub" | grep -qFe ",$oldlabel," && break
         label="$node"

         if [ -z "$urlname" ] && ((i == 0)) && [ "$label" == "$wikiname" ]; then :; else href="$href/$label"; fi
         nodeentry="   \"$label\" [href=\"$href\"]"
         [[ -n "$unique" ]] && uniquenode="$uniquenode""_$label" && nodeentry="   \"$uniquenode\" [label=\"$label\",href=\"$href\"]" && node="$uniquenode"
         if ! grep -qFe "$nodeentry" "$gvfile-nodes"; then
            if ((i == 1)); then
               c="$(echo ${label:0:1} | tr '[:lower:]' '[:upper:]')"
               c="$(printf '%d' "'$c")"
               ( [[ -n "$from" ]] && ((c < from)) ) && break
               ( [[ -n "$to"   ]] && ((c > to)) ) && break
            fi
            echo "$nodeentry" >>  "$gvfile-nodes"
         fi

         if ((i == 0)); then
            :
         elif ((i == 1)); then
            c="$(echo ${label:0:1} | tr '[:lower:]' '[:upper:]')"
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
         oldlabel="$label"
         ((++i))

         ((depth != 0)) && ((i > depth)) && break
      done
   done
done


##---------------------------Convert HTML Special Characters-----------------------##
[[ "$verbose" == "true" ]] && echo "CreateSiteMap: verbose: rework graph"
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
[[ -n "$unique" ]] && wikiname="_$wikiname"
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
[[ "$verbose" == "true" ]] && echo "CreateSiteMap: verbose: create visual graphs"
fdp   -Tsvg -o "$fdpfile"   "$gvfile" "-Gratio=$fdpratio"
dot   -Tsvg -o "$dotfile"   "$gvfile" -Grankdir=LR
twopi -Tsvg -o "$twopifile" "$gvfile" -Granksep=8

#rm -f "$gvfile"

