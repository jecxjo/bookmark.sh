#!/bin/bash - 
#===============================================================================
# Copyright (c) 2015 Jeff Parent
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without modification,
# are permitted provided that the following conditions are met:
#
#  * Redistributions of source code must retain the above copyright notice, this
#    list of conditions and the following disclaimer.
#  * Redistributions in binary form must reproduce the above copyright notice,
#    this list of conditions and the following disclaimer in the documentation
#    and/or other materials provided with the distribution.
#  * Neither the name of the bookmark.sh authors nor the names of its contributors
#    may be used to endorse or promote products derived from this software without
#    specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
# ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
# ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
#          FILE: bookmark.sh
# 
#         USAGE: ./bookmark.sh 
# 
#   DESCRIPTION: A cgi script for managing bookmarks.
# 
#       OPTIONS: ---
#  REQUIREMENTS: ---
#          BUGS: ---
#         NOTES: ---
#        AUTHOR: Jeff Parent (jeff@commentedcode.org
#  ORGANIZATION: 
#       CREATED: 09/25/2015 11:39
#      REVISION: ---
#
# ACKNOWLEDGEMENTS:
# bash_cgi
# Created by Philippe Kehl
# http://oinkzwurgl.org/bash_cgi
#===============================================================================

# Setup

# Path to store database info
DB_DIR="/var/lib/bookmark.sh"

# Title of page
TITLE="Bookmark.sh"

# Faull URL path. This is used in the HTML generation, all forms will
# point to this path
URL="https://commentedcode.org/cgi-bin/bookmark.sh"

# List of users that are not allowed to use this service
BLACKLIST=(root http nobody)

# Login expiration (in seconds)
EXPIRATION=3600 # 1 hour

###############
# Global Vars #
###############
# LOGIN_DB - user;key;timeout
LOGIN_DB="${DB_DIR}/login.db"

# LINK_DB - shortid;url;date;user;comment;tags
LINK_DB="${DB_DIR}/links.db"

##################
# START bash_cgi #
##################
# Created by Philippe Kehl
# http://oinkzwurgl.org/bash_cgi
# (internal) routine to store POST data
function cgi_get_POST_vars()
{
  # check content type
  # FIXME: not sure if we could handle uploads with this..
  [ "${CONTENT_TYPE}" != "application/x-www-form-urlencoded" ] && \
    echo "bash.cgi warning: you should probably use MIME type "\
    "application/x-www-form-urlencoded!" 1>&2
  # save POST variables (only first time this is called)
  [ -z "$QUERY_STRING_POST" \
    -a "$REQUEST_METHOD" = "POST" -a ! -z "$CONTENT_LENGTH" ] && \
    read -n $CONTENT_LENGTH QUERY_STRING_POST
  # prevent shell execution
  local t
  t=${QUERY_STRING_POST//%60//} # %60 = `
  t=${t//\`//}
  t=${t//\$(//}
  t=${t//%24%28//} # %24 = $, %28 = (
  QUERY_STRING_POST=${t}
  return
}

# (internal) routine to decode urlencoded strings
function cgi_decodevar()
{
  [ $# -ne 1 ] && return
  local v t h
  # replace all + with whitespace and append %%
  t="${1//+/ }%%"
  while [ ${#t} -gt 0 -a "${t}" != "%" ]; do
    v="${v}${t%%\%*}" # digest up to the first %
    t="${t#*%}"       # remove digested part
    # decode if there is anything to decode and if not at end of string
    if [ ${#t} -gt 0 -a "${t}" != "%" ]; then
      h=${t:0:2} # save first two chars
      t="${t:2}" # remove these
      v="${v}"`echo -e \\\\x${h}` # convert hex to special char
    fi
  done
  # return decoded string
  echo "${v}"
  return
}

# routine to get variables from http requests
# usage: cgi_getvars method varname1 [.. varnameN]
# method is either GET or POST or BOTH
# the magic varible name ALL gets everything
function cgi_getvars()
{
  [ $# -lt 2 ] && return
  local q p k v s
  # prevent shell execution
  t=${QUERY_STRING//%60//} # %60 = `
  t=${t//\`//}
  t=${t//\$(//}
  t=${t//%24%28//} # %24 = $, %28 = (
  QUERY_STRING=${t}
  # get query
  case $1 in
    GET)
      [ ! -z "${QUERY_STRING}" ] && q="${QUERY_STRING}&"
      ;;
    POST)
      cgi_get_POST_vars
      [ ! -z "${QUERY_STRING_POST}" ] && q="${QUERY_STRING_POST}&"
      ;;
    BOTH)
      [ ! -z "${QUERY_STRING}" ] && q="${QUERY_STRING}&"
      cgi_get_POST_vars
      [ ! -z "${QUERY_STRING_POST}" ] && q="${q}${QUERY_STRING_POST}&"
      ;;
  esac
  shift
  s=" $* "
  # parse the query data
  while [ ! -z "$q" ]; do
    p="${q%%&*}"  # get first part of query string
    k="${p%%=*}"  # get the key (variable name) from it
    v="${p#*=}"   # get the value from it
    q="${q#$p&*}" # strip first part from query string
    # decode and evaluate var if requested
    [ "$1" = "ALL" -o "${s/ $k /}" != "$s" ] && \
      eval "$k=\"`cgi_decodevar \"$v\"`\""
  done
  return
}

#cgi_getvars BOTH ALL
# END of bash_cgi

##################
# Misc Functions #
##################
# Generate 32 character key
function GenerateKey () {
  dd if=/dev/random bs=1 count=32 2>/dev/null |
  base64 |
  tr -d '+/= '
}

# Increment a 62-bit Alphanumeric "number"
# 1->number
function Increment () {
  local S="0123456789abcdefghijklmnopqrstuvwxyz"
  local I F B
  local N=$(echo "$1" | tr '[:upper:]' '[:lower:]')
  F=${N%?}
  B=${N#$F}

  case "$B" in
    (z) [ -z "$F" ] && echo 10 || echo "$(inc "$F")0" ;;
    (*) echo "$F${S:1+36#$B:1}"
  esac
}

function ExtPath () {
  builtin echo "${REQUEST_URI}" | sed "s|${SCRIPT_NAME}||" | sed "s|\?.*$||"
}

function PathShortId () {
  echo "$1" | grep -e "^/[a-zA-Z0-9-]\+$" -e "^/[a-zA-Z0-9-]\+/[a-zA-Z0-9-]\+$" | sed "s|.*/\([a-zA-Z0-9-]\+\)$|\1|"
}

function PathShortUserId () {
  echo "$1" | grep "^/[a-zA-Z0-9-]\+/[a-zA-Z0-9-]\+$" | sed "s|^/\([a-zA-Z0-9-]\+\)/.*$|\1|"
}

#########
# Mutex #
#########
# Locks the LOGIN_DB file
function LockLoginMutex () {
  local count=5
  while [[ ${count} > 0 ]]
  do
    if mkdir /tmp/bookmark.sh.login.lock; then
      echo "LOCKED"
      return
    fi
    count=$(( count - 1))
    sleep 1
  done
}

# Unlock the LOGIN_DB file
function UnlockLoginMutex () {
  rm -rf /tmp/bookmark.sh.login.lock
}

# Locks the LINK_DB file
function LockLinkMutex () {
  local count=5
  while [[ ${count} > 0 ]]
  do
    if mkdir /tmp/bookmark.sh.link.lock; then
      echo "LOCKED"
      return
    fi
    count=$(( count - 1))
    sleep 1
  done
}

# Unlock the LINK_DB file
function UnlockLinkMutex () {
  rm -rf /tmp/bookmark.sh.link.lock
}

################
# Sanitization #
################
# Checks if username is a sane username
# 1->user
function IsSaneUser () {
  # Make sure user is only alpha-numeric and optionally contain a dash
  local user=$(echo "$1" | grep "^[0-9A-Za-z-]\+$")
  if [ ! -z "${user}" ]; then
    # run through blacklist to make sure user is ok on system
    local count=0
    while [ "x${BLACKLIST[count]}" != "x" ]
    do
      if [ "${user}" == "${BLACKLIST[count]}" ]; then
        return # In blacklist, exit
      fi
      count=$(( ${count} + 1 ))
    done
  fi

  # Check if user is actually on system
  grep -q "^${user};" /etc/passwd

  if [[ $? -eq 0 ]]; then
    echo "${user}" # Print user name since its valid
  fi
}

# Checks url for protocol and inserts if not there
# 1->url
function FixURL () {
  local url="$1"

  # if exit 0 no match was found, assume http
  if out=$(echo "${url}" | awk '/http:\/\// || /https:\/\// || /ftp:\/\// { exit 1; }'); then
    echo "http://${url}"
  else
    echo "${url}"
  fi
}


###########
# Shorten #
###########
# LINK_DB - shortid;longurl;date;user;comments;tags
# Shorten URL and return id
# 1->longurl, 2->user, 3->comments, 4->tags
function Shorten () {
  local longurl="$1" user="$2" comments="$3" tags="$4"
  local shortid=$(awk -v longurl="${longurl}" '
    BEGIN { FS = ";" }
    {
      if ( $2 == longurl ) {
        print $1;
        exit 0;
      }
    }' "${LINK_DB}")

  # check if link is already short
  if [[ -z "${shortid}" ]]; then
    if [[ "$(LockLinkMutex)" == "LOCKED" ]]; then
      # Find last used and then get the next
      local last=$(awk 'BEGIN { FS = ";" } { print $1 }' "${LINK_DB}" | sort -r | head -n1)
      local shortid=$(Increment "${last}")

      # Insert to db
      echo "${shortid};${longurl};$(date +%Y%m%d);${user};${comments};${tags}" >> "${LINK_DB}"

      UnlockLinkMutex
    fi
  fi

  # return link
  echo "${shortid}"
}

#########
# Pages #
#########
function GenerateMainShortenForm () {

  cat << EOF
  <form action="${URL}" method="POST">
    <center>
      <input type="hidden" name="cmd" id="cmd" value="shorten" />
      URL: <input type="text" name="longurl" id="longurl" class="textbox-600" /> <input type="submit" value="Shorten" />
    </center>
  </form>
EOF
}

function MainPage () {
  cat << EOF
$(Http)

<!DOCTYPE html>
<html>
$(Header)
<body>
  <h1>${TITLE}</h1>
$(GenerateMainShortenForm)
<br />
$(GenerateLoginLink)
</body>
</html>
EOF
}

function ShortenPage () {
 local longurl="$1"

 cat << EOF
$(Http)

<!DOCTYPE html>
<html>
  $(Header)
  <body>
    <h1>${TITLE}</h1>
    $(GenerateShorten "${longurl}")
  </body>
</html>
EOF
}

function ExpandPage () {
  local extPath="$1"
  cat << EOF
$(Http)

<!DOCTYPE html>
<html>
$(Header)
<body>
  <h1>${TITLE} - Expanding</h1>
  $(ExpandShort "${extPath}")
</body>
</html>
EOF
}

#function GenerateLoginLink () {
#
#}

# Generate short url and load the main form again
# 1->longurl
function GenerateShorten () {
  local longurl="$(FixURL "$1")"
  local shortid="$(Shorten "${longurl}")"

  if [[ -z "${shortid}" ]]; then
    cat << EOF
<center>
  <b>Error 06:</b> Problems shortening<br />
</center>
EOF
  else
    cat << EOF
<center>
  The url has been shortened to:<br />
  <a href="${URL}/${shortid}">${URL}/${shortid}</a><br /><br />
</center>
EOF
  fi

  GenerateMainShortenForm
}

# Expand id to long url
# 1->shortid
function ExpandShort () {
  local shortid="$(PathShortId "$1")"
  local longurl="$(awk -v shortid="${shortid}" '
    BEGIN { FS = ";" }
    {
      if ( $1 == shortid ) {
        print $2;
        exit 0;
      }
    }' "${LINK_DB}")"

  if [[ -z "${longurl}" ]]; then
    cat << EOF
<center>
  <b>Error 07:</b> Short URL not valid<br />
</center><br />
EOF
  else
    cat << EOF
<script>
  setTimeout( function () { window.location.href="${longurl}"; }, 5000);
</script>
<center>
  Loading your url...<br />
  <br />
  If not automatically redirected following <a href="${longurl}">this link</a>
</center><br />
EOF
  fi
}


###################
# HTML Generation #
###################
function Http () {
  local cookies="$1"

  echo "Content-type: text/html"

  if [[ ! -z "${cookies}" ]]; then
    echo "Set-Cookie: ${cookies}"
  fi
}

function Header() {
  cat << EOF
<head>
  <title>${TITLE}</title>
  <style>
    fieldset {
      width: 500px;
    }
    legend {
      font-size: 20px;
    }
    label.field {
      text-align: right;
      width: 200px;
      float: left;
      font-weight: bold;
    }
    label.textbox-300 {
      width: 300px;
      float: left;
    }
    fieldset p {
      clear: bloth;
      padding: 5px;
    }
  </style>
</head>
EOF
}


########
# Main #
########

extPath="$(ExtPath)"
case "${extPath}" in
  "")
    cgi_getvars POST cmd
    case "${cmd}" in
      "")
        MainPage
        ;;
      "shorten")
        cgi_getvars POST longurl
        ShortenPage "${longurl}"
        ;;
      *)
        MainPage
        ;;
    esac
    ;;
  "/user")
    # Handle user stuff
    ;;
  *)
    ExpandPage "${extPath}"
    ;;
esac
