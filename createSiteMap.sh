#!/bin/bash
# See the file "license.terms" for information on usage and redistribution of
# this file, and for a DISCLAIMER OF ALL WARRANTIES.

unset USERNAME PASSWORD arg_rest cookies
unset wikiname urlname baseurl xmlfile gvfile fdpfile dotfile twopifile depth from to
unset fdpratio color exclude regexclude excludesub verbose unique update prefix xmlcontent
unset sitemapurl no_check_certificate user options dlurl is_index graphname addresslisttmp
unset sitemapxmllist vca vco

depth=0
fdpratio=0.75     # 4:3
#fdpratio=0.562   # 16:9

color[1]="red"
color[2]="green"
color[3]="blue"
color[4]="yellow"
color[5]="violet"
vca=""
vco=""


##---------------------------Check Arguments---------------------------------------##
function function_arguments {
   [[ "$verbose" == "true" ]] && echo -e "${vca}CreateSiteMap: verbose: read Arguments${vco}"

   i=0
   arg_rest_count=0

   until test "$((i > -BASH_ARGC))" == "0"; do
      i=$((i - 1))
      curr_arg="${BASH_ARGV[$i]}"

      if [ "${curr_arg:0:2}" == "--" ]; then
         case "$curr_arg" in
         --baseurl)       i=$((i - 1)); baseurl="${BASH_ARGV[$i]}" ;;
         --depth)         i=$((i - 1)); depth="${BASH_ARGV[$i]}" ;;
         --exclude)       i=$((i - 1)); exclude="$exclude,${BASH_ARGV[$i]}" ;;
         --regexclude)    i=$((i - 1)); regexclude="$regexclude,${BASH_ARGV[$i]}" ;;
         --excludesub)    i=$((i - 1)); excludesub="$excludesub,${BASH_ARGV[$i]}" ;;
         --fdpratio)      i=$((i - 1)); fdpratio="${BASH_ARGV[$i]}" ;;
         --from)          i=$((i - 1)); from="${BASH_ARGV[$i]}" ;;
         --graphname)     i=$((i - 1)); graphname="${BASH_ARGV[$i]}" ;;
         --load-cookies)  i=$((i - 1)); cookies="${BASH_ARGV[$i]}" ;;
         --no-check-certificate) no_check_certificate=true ;;
         --prefix)        i=$((i - 1)); prefix="${BASH_ARGV[$i]}" ;;
         --sitemapurl)    i=$((i - 1)); sitemapurl="${BASH_ARGV[$i]}" ;;
         --to)            i=$((i - 1)); to="${BASH_ARGV[$i]}" ;;
         --unique)        unique=true ;;
         --update)        update=true ;;
         --urlname)       i=$((i - 1)); urlname="${BASH_ARGV[$i]}"; setun=true ;;
         --user)          i=$((i - 1)); user="${BASH_ARGV[$i]}" ;;
         --verbose)       verbose=true ;;
         --verbosec)      verbose=true; vca='\033[01;31m'; vco='\033[00m' ;;
         --wikiname)      i=$((i - 1)); wikiname="${BASH_ARGV[$i]}" ;;
         --xmlfile)       i=$((i - 1)); xmlfile="${BASH_ARGV[$i]}" ;;
         --help)
            echo "CreateSiteMap V0.1.8"
            echo "Create visual (site)maps from MoinMoin-Wiki."
            echo ""
            echo "Options:"
            echo "   --help                  Show this help"
            echo "   --verbose               Print more info"
            echo "   --verbosec              Print more info (with color ;) )"
            echo "   --wikiname <name>       The name of the Wiki"
            echo "   --graphname <name>      The name for the resulting Graphs"
            echo "   --baseurl <name>        The domain of the URL"
            echo "   --urlname <name>        The postfix of the URL"
            echo "   --sitemapurl <name>     The postfix URL where to download the SiteMap-XML-File"
            echo "   --exclude <site>,...    Sites to exclude from creation"
            echo "   --regexclude <site>,... Sites to exclude from creation (RegEx Search)"
            echo "   --excludesub <site>,... Sites to exclude their subpages from creation"
            echo "   --unique                Prevent collisions of identical page names"
            echo "   --depth <number>        Max page-depth"
            echo "   --from <char>           Only sites from this character"
            echo "   --to <char>             Only sites till this character"
            echo "   --fdpratio <number>     Image ratio for fdp sitemap"
            echo "   --prefix <path>         Define the target directory"
            echo "   --xmlfile <file>        Use this file as SiteMap-XML-File"
            echo "Download-directions:"
            echo "   --update                Update SiteMap-XML-File from Wiki (only public sites)"
            echo "   --load-cookies <file>   Define a Cookies-File to download form Wiki (see wget)"
            echo "   --load-cookies firefox  Use Wiki-Login from Firefox"
            echo "   --no-check-certificate  Don't check untrusted Certificates"
            echo "   --user <user>           Use Basic-Auth for connection"
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


   [[ -z "$baseurl" ]] && echo "error: no baseurl defined" 1>&2 && exit 1
   [[ -z "$wikiname" ]] && echo "error: no wikiname defined" 1>&2 && exit 1


   ##---------------------------Set undefined values----------------------------------##
   : ${xmlfile:="${wikiname}.xml"}
   : ${gvfile:="${wikiname}_wiki.gv"}
   : ${fdpfile:="${wikiname}_wiki.fdp.svg"}
   : ${dotfile:="${wikiname}_wiki.dot.svg"}
   : ${twopifile:="${wikiname}_wiki.twopi.svg"}
   : ${graphname:="$(basename -s ".gv" "$gvfile")"}
#   : ${sitemapurl:="$urlname?action=sitemap&underlay=0}

   [[ -z "$setun"      ]] && urlname="$wikiname"
   [[ -n "$exclude"    ]] && exclude=",$exclude,"
   [[ -n "$regexclude" ]] && regexclude=",$regexclude,"
   [[ -n "$excludesub" ]] && excludesub=",$excludesub,"
   [[ -n "$from"       ]] && from="$(echo $from | tr '[:lower:]' '[:upper:]')" && from="$(printf '%d' "'$from")"
   [[ -n "$to"         ]] && to="$(echo $to | tr '[:lower:]' '[:upper:]')"     && to="$(printf '%d' "'$to")"
   [[ "${baseurl:${#baseurl}-1}" != "/" ]] && baseurl="$baseurl/"
   [[ -n "$urlname" ]] && [[ "${urlname:${#urlname}-1}" != "/" ]] && urlname="$urlname/"

   : ${sitemapurl:=${urlname}sitemap.xml}
} #end Fct



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



function function_download {
   [[ "$verbose" == "true" ]] && echo -e "${vca}CreateSiteMap: verbose: download SiteMap-XML-File${vco}"

   local xmlfile="$1"
   local sitemapurl="$2"
   local options=""
   [[ "$no_check_certificate" == true ]] && options="$options --no-check-certificate"
   #[[ -n "$user" ]] && options="$options --user \"$user\" --ask-password"
   [[ -n "$user" ]] && options="$options --user $user --ask-password"

   if [ -n "$cookies" ]; then
      # Use Cookie from Browser
      [[ "$cookies" == "firefox" ]] && local ffpath="$(grep -Fe 'Path=' "$HOME/.mozilla/firefox/profiles.ini" | head -n 1)" && cookies="$HOME/.mozilla/firefox/${ffpath:5}/cookies.sqlite"

      # Use Cookie from Firefox-SQLite
      if [ "${cookies:((${#cookies}-7))}" == ".sqlite" ]; then
         extract_cookies_from_sqlite "$cookies" > cookie-tmp.txt
         local cookies=cookie-tmp.txt
      fi

      wget $options --load-cookies "$cookies" "$sitemapurl" -O "$xmlfile"

      [ -e cookie-tmp.txt ] && rm -f cookie-tmp.txt
   else
      #Only Public
      wget $options "$sitemapurl" -O "$xmlfile"
   fi
} #end Fct



##---------------------------Get links from XML-Sitemap-File-----------------------##
function function_load_xml_file {
   [[ "$verbose" == "true" ]] && echo -e "${vca}CreateSiteMap: verbose: Load SiteMap-XML-File \"$1\" (\"$2\")${vco}"

   local xmlfile="$1"
   local sitemapurl="$2"
   local is_index=false
   local xmlcontent=""

   # Load data
   if [ "$update" == "true" ] || [ ! -e "$xmlfile" ]; then
      function_download "$xmlfile" "$sitemapurl"
   fi

   # Read data
   if file "$xmlfile" | grep -q -e "gzip compressed data"; then
      local xmlcontent="$(gzip -cd "$xmlfile")"
   else
      local xmlcontent="$(cat "$xmlfile")"
   fi

   # Check if it is an index file
   (echo "$xmlcontent" | grep -qlFe "<sitemapindex") && local is_index=true

   if [ "$is_index" == true ]; then
      local sitemapxmllist=$(echo "$xmlcontent" | grep -oEe "<loc>[[:print:]]+</loc>")

      for sitemapxml in $sitemapxmllist; do
         function_load_xml_file "${sitemapxml:5:-6}" "$(dirname "$sitemapurl")/${sitemapxml:5:-6}"
      done
   else
      local addresslisttmp=$(echo "$xmlcontent" | grep -oEe "<loc>$baseurl$urlname[[:print:]]+</loc>")

      if [ -z "$addresslist" ]; then
         addresslist="$addresslisttmp"
      else
         addresslist="$addresslist"$'\n'"$addresslisttmp"
      fi
   fi
} #end Fct



##---------------------------Create GraphViz Edges/Nodes---------------------------##
function function_create_sitemap {
   [[ "$verbose" == "true" ]] && echo -e "${vca}CreateSiteMap: verbose: parse graph from SiteMap-XML-File${vco}"

   echo -n "" > "$gvfile"
   echo -n "" > "$gvfile-nodes"
   echo -n "" > "$gvfile-edges"

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
         nodecount="$(echo ${address:((${#baseurl}+5)):-6} | awk 'BEGIN{FS="/"}{print NF}')"
         [[ -z "$urlname" ]] && nodelist="$wikiname"$IFS"$nodelist"

         for node in $nodelist; do
            [[ -n "$exclude" ]] && echo "$exclude" | grep -qFe ",$node," && break
            [[ -n "$excludesub" ]] && ((i > 1)) && echo "$excludesub" | grep -qFe ",$oldlabel," && break
            label="$node"

            if [ -z "$urlname" ] && ((i == 0)) && [ "$label" == "$wikiname" ]; then :; else href="$href/$label"; fi
            label="$(echo "$label" | echo -e $(sed 's/%/\\x/g') )"
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
} #end Fct



##---------------------------Convert HTML Special Characters-----------------------##
function function_rework {
   [[ "$verbose" == "true" ]] && echo -e "${vca}CreateSiteMap: verbose: rework graph${vco}"

#   sed -i \
#      -e 's/%C3%84/Ä/g' -e 's/%C3%A4/ä/g' -e 's/%C3%BC/ü/g' -e 's/%C3%9F/ß/g' \
#      -e 's/%C3%96/Ö/g' -e 's/%C3%B6/ö/g' -e 's/%C3%9C/Ü/g' \
#       -e 's/%3F/?/g' -e 's/%20/ /g' -e 's/%3A/:/g' \
#      "$gvfile-nodes"

#   sed -i \
#      -e 's/%C3%84/Ä/g' -e 's/%C3%A4/ä/g' -e 's/%C3%BC/ü/g' -e 's/%C3%9F/ß/g' \
#      -e 's/%C3%96/Ö/g' -e 's/%C3%B6/ö/g' -e 's/%C3%9C/Ü/g' \
#       -e 's/%3F/?/g' -e 's/%20/ /g' -e 's/%3A/:/g' \
#      "$gvfile-edges"

   #sed -i -e 's/%/\\x/g' "$gvfile-nodes"
   #sed -i -e 's/%/\\x/g' "$gvfile-edges"
} #end Fct



##---------------------------Concatenate GraphViz File-----------------------------##
function function_concatenate {
   [[ "$verbose" == "true" ]] && echo -e "${vca}CreateSiteMap: verbose: concatenate parts to graph${vco}"

   [[ -n "$unique" ]] && wikiname="_$wikiname"
   echo -e "digraph \"$graphname\" {\n"\
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
} #end Fct



##---------------------------Build Graph Image-------------------------------------##
function function_build {
   [[ "$verbose" == "true" ]] && echo -e "${vca}CreateSiteMap: verbose: create visual graphs${vco}"

   fdp   -Tsvg -o "$fdpfile"   "$gvfile" "-Gratio=$fdpratio"
   dot   -Tsvg -o "$dotfile"   "$gvfile" -Grankdir=LR
   twopi -Tsvg -o "$twopifile" "$gvfile" -Granksep=8

   #rm -f "$gvfile"
} #end Fct



function function_main {
   function_arguments

   if [ -n "$prefix" ]; then
      mkdir -p "$prefix" && cd "$prefix"
   fi

   function_load_xml_file "$xmlfile" "$baseurl$sitemapurl"

   function_create_sitemap

   function_rework
   function_concatenate
   function_build
} #end Main

function_main

