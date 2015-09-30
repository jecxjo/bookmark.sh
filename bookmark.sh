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
#      REVISION: 0.1
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
URL="https://example.com/cgi-bin/bookmark.sh"

# List of users that are not allowed to use this service
BLACKLIST=(root http nobody)

# Login expiration (in seconds)
EXPIRATION=3600 # 1 hour

# Expand delay (in seconds)
DELAY=3

###############
# Global Vars #
###############
# LOGIN_DB - user|key|timeout
LOGIN_DB="${DB_DIR}/login.db"
touch "${LOGIN_DB}"

# LINK_DB - shortid|url|date|user|comment|tags
LINK_DB="${DB_DIR}/links.db"
touch "${LINK_DB}"

# Version, releases are X.Y, dev are X.Y.Z
VERSION=0.1

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

function CookieToken () {
  echo "${HTTP_COOKIE}" | awk '
    BEGIN { RS = ";"; FS = "="; }
    {
      gsub(/^[ \t]+/, "", $1);
      gsub(/[ \t]+$/, "", $1);
      if ( $1 == "token" )
      {
        gsub(/^[ \t]+/, "", $2);
        gsub(/[ \t]+$/, "", $2);
        print $2;
        exit 0;
      }
    }'
}

function TokenUser () {
  echo "$1" | awk 'BEGIN { FS = ":" } { print $1 }'
}

function TokenKey () {
  echo "$1" | awk 'BEGIN { FS = ":" } { print $2 }'
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

function PathUserId () {
  echo "$1" | grep "^/u/[a-zA-Z0-9-]\+$" | sed "s|^/u/\([a-zA-Z0-9-]\+\)$|\1|"
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
  grep -q "^${user}:" /etc/passwd

  if [[ $? -eq 0 ]]; then
    echo "${user}" # Print user name since its valid
  fi
}

# Checks url for protocol and inserts if not there
# 1->url
function FixURL () {
  local url=$(echo "$1" | sed 's|^\(.*\)://\([a-zA-Z0-9.-]\+\)\(/.*\)|\L\1://\2\E\3|' | sed 's|^\([a-zA-Z0-9.-]\+\)\(/*\)|\L\1\E\2|')

  # if exit 0 no match was found, assume http
  if out=$(echo "${url}" | awk '/http:\/\// || /https:\/\// || /ftp:\/\// { exit 1; }'); then
    echo "http://${url}"
  else
    echo "${url}"
  fi
}

# Removes all characters that could cause a problem
# 1->string
function StripBadStuff () {
  builtin echo "$1" | tr -d '|'
}



###########
# Shorten #
###########
# LINK_DB - shortid|longurl|date|user|comments|tags
# Shorten URL and return id
# 1->longurl, 2->user, 3->comments, 4->tags
function Shorten () {
  local longurl="$(FixURL "$(StripBadStuff "$1")")" user="$(StripBadStuff "$2")" comments="$(StripBadStuff "$3")" tags="$(StripBadStuff "$4")"
  local shortid=$(awk -v longurl="${longurl}" -v user="${user}" '
    BEGIN { FS = "|" }
    {
      if ( $2 == longurl ) {
        if ( $4 == user ) {
          print $1;
          exit 0;
        }
      }
    }' "${LINK_DB}")

  # check if link is already short
  if [[ -z "${shortid}" ]]; then
    if [[ "$(LockLinkMutex)" == "LOCKED" ]]; then
      # Find last used and then get the next
      local last=$(awk 'BEGIN { FS = "|" } { print $1 }' "${LINK_DB}" | sort -r | head -n1)
      local shortid=$(Increment "${last}")

      # Insert to db
      echo "${shortid}|${longurl}|$(date +%Y%m%d)|${user}|${comments}|${tags}" >> "${LINK_DB}"

      UnlockLinkMutex
    fi
  fi

  # return link
  echo "${shortid}"
}

function Update () {
  local shortid="$1" longurl="$(FixURL "$(StripBadStuff "$2")")" user="$(StripBadStuff "$3")" comments="$(StripBadStuff "$4")" tags="$(StripBadStuff "$5")"

  # check if link is already short
  if [[ "$(LockLinkMutex)" == "LOCKED" ]]; then
    local t="$(mktemp /tmp/link.XXXXXX)"
    # Find last used and then get the next
    awk -v shortid="${shortid}" '
      BEGIN { FS = "|" }
      {
        if ( $1 != shortid )
        {
          print $0;
        }
      }' "${LINK_DB}" > "${t}"

    # Insert to db
    echo "${shortid}|${longurl}|$(date +%Y%m%d)|${user}|${comments}|${tags}" >> "${t}"

    cp --no-preserve=mode,ownership "${t}" "${LINK_DB}"
    rm "${t}"

    UnlockLinkMutex
  fi
}

##########
# Delete #
##########
# LINK_DB - shortid|longurl|date|user|comments|tags
# Delete ID
# 1->shortid, 2->user
function Delete () {
  local shortid="$1" user="$(IsSaneUser "$2")"

  if [[ -z "${user}" ]]; then
    echo "ERROR"
    return
  fi

  if [[ "$(LockLinkMutex)" == "LOCKED" ]]; then
    local t="$(mktemp /tmp/links.XXXXXX)"

    awk -v shortid="${shortid}" -v user="${user}" '
      BEGIN { FS = "|" }
      {
        if ( $1 != shortid )
        {
          print $0;
        }
        else
        {
          if ( $4 != user )
          {
            print $0;
          }
          else
          {
            print $1"|||||";
          }
        }

      }' "${LINK_DB}" > "${t}"

    cp --no-preserve=mode,ownership "${t}" "${LINK_DB}"
    rm "${t}"
    UnlockLinkMutex
  fi

  echo "DONE"
}

###########
# ShortTo #
###########

function ShortToURL () {
  awk -v short="$1" '
    BEGIN { FS = "|" }
    {
      if ( $1 == short )
      {
        print $2;
        exit 0;
      }
    }' "${LINK_DB}"
}

function ShortToName () {
  awk -v short="$1" '
    BEGIN { FS = "|" }
    {
      if ( $1 == short )
      {
        print $5;
        exit 0;
      }
    }' "${LINK_DB}"
}

function ShortToTag () {
  awk -v short="$1" '
    BEGIN { FS = "|" }
    {
      if ( $1 == short )
      {
        print $6;
        exit 0;
      }
    }' "${LINK_DB}"
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
$(Title)
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
    $(Title)
    $(GenerateShorten "${longurl}")
    <br />
    $(GenerateLoginLink)
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
  $(Title "Expanding")
  $(ExpandShort "${extPath}")
</body>
</html>
EOF
}

function LoginPage () {
  cat << EOF
$(Http)

<!DOCTYPE html>
<html>
  $(Title "Login")
  <form action="${URL}" method="POST">
    <input type="hidden" name="cmd" value="trylogin" />
    <p><label class="field" for="user">User:</label> <input type="text" name="user" class="textbox-300" /></p>
    <p><label class="field" for="password">Password:</label> <input type="password" name="password" class="textbox-300" /></p>
    <input type="submit" value="Login" />
  </form>
</html>
EOF
}

function GenerateLoginLink () {
  cat << EOF
<br />
<center>
<p>[ <a href="${URL}?cmd=login">Login</a> |
     <a href="javascript:location.href='${URL}/?cmd=shorten&longurl='+encodeURIComponent(location.href)">${TITLE} - shorten</a> ]</p>
</center>
<br />
EOF
}

# 1-> user
function UserBookmarklet () {
  local user="$(IsSaneUser $1)"

  if [[ ! -z "${user}" ]]; then
    cat << EOF
    <a href="javascript:(function()%7Bvar%20s%3Ddocument.title%3Bvar%20l%3Dlocation.href%3Bvar%20w%3Dwindow.open(''%2C'${TITLE}'%2C'height%3D200%2Cwidth%3D450')%3Bvar%20d%3Dw.document%3Bd.write('%3Cform%20action%3D%22${URL}%2Fu%2F${user}%22%20method%3D%22POST%22%3E')%3Bd.write('%3Cinput%20type%3D%22hidden%22%20name%3D%22cmd%22%20value%3D%22useraddlink%22%20%2F%3E')%3Bd.write('URL%3A%20%3Cinput%20type%3D%22text%22%20name%3D%22longurl%22%20size%3D%22400%22%20value%3D'%2Bl%2B'%20style%3D%22width%3A400%3B%22%20%2F%3E%3Cbr%20%2F%3E')%3Bd.write('NAME%3A%20%3Cinput%20type%3D%22text%22%20name%3D%22name%22%20size%3D%22400%22%20value%3D%22'%2Bs%2B'%22%20style%3D%22width%3A400%3B%22%20%2F%3E%3Cbr%20%2F%3E')%3Bd.write('TAG%3A%20%3Cinput%20type%3D%22text%22%20name%3D%22tag%22%20size%3D%22400%22%20style%3D%22width%3A400%3B%22%20%2F%3E%3Cbr%20%2F%3E')%3Bd.write('%3Cinput%20type%3D%22submit%22%20id%3D%22submit%22%20value%3D%22Submit%22%3E%3C%2Fform%3E')%3Bd.close()%7D)()">${TITLE} - ${user}</a>
EOF
  fi
}

function UserPage () {
  local user="$(IsSaneUser $1)" shortid="$2"
  local token="$(CookieToken)"
  local cookieUser=$(TokenUser "${token}")
  local cookieKey=$(TokenKey "${token}")
  local cmd="useraddlink"
  local url=""
  local name=""
  local tag=""

  if [[ -z "${user}" ]]; then
    ErrorRedirect "/?cmd=login" "Not logged in"
    return
  fi

  if [[ "${user}" != "${cookieUser}" ]]; then
    ErrorRedirect "/?cmd=login" "Not logged in"
    return
  fi

  if [[ -z "$(ValidateUserKey "${cookieUser}" "${cookieKey}")" ]]; then
    ErrorRedirect "/?cmd=login" "Not logged in"
    return
  fi

  if [[ ! -z "${shortid}" ]]; then
    cmd="userupdatelink"
    url="$(ShortToURL ${shortid})"
    name="$(ShortToName ${shortid})"
    tag="$(ShortToTag ${shortid})"
  fi

  cat << EOF
$(Http)

<!DOCTYPE html>
<html>
$(Header)
<body>
  $(Title)
  User: ${user}<br />
  <br />
  shortid: ${shortid}<br />
  <p>[ <a href="${URL}/u/${user}?cmd=logout">Logout</a> | $(UserBookmarklet "${user}") ]</p><br />
  <center>
    <form action="${URL}/u/${user}" method="POST">
      <input type="hidden" name="cmd" value="${cmd}" />
      <input type="hidden" name="shortid" value="${shortid}" />
      <p>URL: <input type="text" name="longurl" class="textbox-600" value="${url}" /></p>
      <p>NAME: <input type="text" name="name" class="textbox-600" value="${name}" /></p>
      <p>TAG: <input type="text" name="tag" class="textbox-600" value="${tag}" /></p>
      <input type="submit" value="Save" />
    </form>
  </center>
  <br />
  <!-- Tags -->
  <table>
    $(UserLinks "${cookieUser}")
  </table>
</body>
</html>
EOF
}

# user, url, name, tag
function UserAddLinkPage () {
  local user="$(IsSaneUser $1)" longurl="$2" name="$3" tag="$4"
  local token="$(CookieToken)"
  local cookieUser=$(TokenUser "${token}")
  local cookieKey=$(TokenKey "${token}")

  if [[ -z "${user}" ]]; then
    ErrorRedirect "/?cmd=login" "Not logged in"
    return
  fi

  if [[ "${user}" != "${cookieUser}" ]]; then
    ErrorRedirect "/?cmd=login" "Not logged in"
    return
  fi

  if [[ -z "$(ValidateUserKey "${cookieUser}" "${cookieKey}")" ]]; then
    ErrorRedirect "/?cmd=login" "Not logged in"
    return
  fi

  local out=$(Shorten "${longurl}" "${user}" "${name}" "${tag}")

  UserPage "${user}"
}

function UserUpdateLinkPage () {
  local user="$(IsSaneUser "$1")" shortid="$2" longurl="$3" name="$4" tag="$5"
  local token="$(CookieToken)"
  local cookieUser=$(TokenUser "${token}")
  local cookieKey=$(TokenKey "${token}")

  if [[ -z "${user}" ]]; then
    ErrorRedirect "/?cmd=login" "Not logged in"
    return
  fi

  if [[ "${user}" != "${cookieUser}" ]]; then
    ErrorRedirect "/?cmd=login" "Not logged in"
    return
  fi

  if [[ -z "$(ValidateUserKey "${cookieUser}" "${cookieKey}")" ]]; then
    ErrorRedirect "/?cmd=login" "Not logged in"
    return
  fi

  local out=$(Update "${shortid}" "${longurl}" "${user}" "${name}" "${tag}")

  UserPage "${user}"
}

# user, shortid
function UserDeleteLinkPage () {
  local user="$(IsSaneUser "$1")" shortid="$2"

  local token="$(CookieToken)"
  local cookieUser=$(TokenUser "${token}")
  local cookieKey=$(TokenKey "${token}")

  if [[ -z "${user}" ]]; then
    GenerateErrorMain "Invalid User" "token=; expires=Thu, 01 Jan 1970 00:00:00 GMT"
    return
  fi

  if [[ "${user}" != "${cookieUser}" ]]; then
    GenerateErrorMain "User Cookie Issue" "token=; expires=Thu, 01 Jan 1970 00:00:00 GMT"
    return
  fi

  if [[ -z "$(ValidateUserKey "${cookieUser}" "${cookieKey}")" ]]; then
    GenerateErrorMain "Cookie Error" "token=; expires=Thu, 01 Jan 1970 00:00:00 GMT"
    return
  fi

  local out=$(Delete "${shortid}" "${user}")

  UserPage "${user}"
}

function UserLinks () {
  local user="$(IsSaneUser "$1")"

  awk -v user="${user}" -v url="${URL}" '
    BEGIN { FS = "|" }
    {
      if ( $4 == user )
      {
        print "<tr>";
        print " <td bgcolor=CCCCCC>[<a href=\"" url "/u/" user "?cmd=updatelink&shortid=" $1 "\">+</a>]</td>";
        print " <td bgcolor=CCCCCC>[<a href=\"" url "/u/" user "?cmd=deletelink&shortid=" $1 "\">-</a>]</td>";
        print " <td bgcolor=CCCCCC>" url "/" $1 "</td>";
        print " <td bgcolor=CCCCCC>" $5 "</td>";
        print "</tr>";
      }
    }' < <(sort -r "${LINK_DB}")
}

# Generate short url and load the main form again
# 1->longurl
function GenerateShorten () {
  local shortid="$(Shorten "$1")"

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
  local jsdelay=$(( ${DELAY} * 1000 ))
  local shortid="$(PathShortId "$1")"
  local longurl="$(awk -v shortid="${shortid}" '
    BEGIN { FS = "|" }
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
  setTimeout( function () { window.location.href="${longurl}"; }, ${jsdelay});
</script>
<center>
  Loading your url...<br />
  <br />
  If not automatically redirected following <a href="${longurl}">this link</a>
</center><br />
EOF
  fi
}

function GenerateErrorMain () {
  cat << EOF
$(Http "$2")

<!DOCTYPE html>
<html>
$(Header)
<body>
  $(Title "Error")
  $1<br />
  <br />
  <p>[ <a href="${URL}">Back</a> ]</p>
  <br />
</body>
</html>
EOF
}

# 1-> path, 2->message
function ErrorRedirect () {
  local path="$1" msg="$2"
  cat << EOF
$(Http)

<!DOCTYPE html>
<html>
$(Header)
<body>
  $(Title "Error")
  ${msg}<br />
  <p> [ <a href="${URL}${path}">OK</a> ]</p>
  <script>
    setTimeout( function () { window.location.href="${URL}${path}"; }, 0);
  </script>
</body>
</html>
EOF
}

function TryLogin () {
  local user="$(IsSaneUser "$1")" pass="$2"

  if [[ -z "${user}" ]]; then
    GenerateErrorMain "Invalid User" "token=; expires=Thu, 01 Jan 1970 00:00:00 GMT"
    return
  fi

  local key=$(LoginUser "${user}" "${pass}")
  if [[ -z "${key}" ]]; then
    GenerateErrorMain "Invalid User/Password" "token=; expires=Thu, 01 Jan 1970 00:00:00 GMT"
    return
  fi

  cat << EOF
$(Http "token=${user}:${key};")

<!DOCTYPE html>
<html>
$(Header)
<body>
  <script>
    setTimeout( function () { window.location.href="${URL}/u/${user}"; }, 500);
  </script>
  <center>
    Login Successful <br /><br />
    If not automatically redirected click <a href="${URL}/u/${user}">this link</a>
  </center>
<//body>
</html>
EOF
}

function LogoutPage () {
  local token="$(CookieToken)"
  local user=$(TokenUser "${token}")
  local key=$(TokenKey "${token}")
  local res="$(LogoutUser "${user}" "${key}")"

  if [[ "${res}" != "LOGOUT" ]]; then
    GenerateErrorMain "Invalid Cookie" "token=; expires=Thu, 01 Jan 1970 00:00:00 GMT"
    return
  fi

  cat << EOF
$(Http "token=; expires=Thu, 01 Jan 1970 00:00:00 GMT")

<!DOCTYPE html>
<html>
$(Header)
<body>
  <script>
    setTimeout( function () { window.location.href="${URL}"; }, 500);
  </script>
  <center>
    Logout Successful <br /><br />
    If not automatically redirected click <a href="${URL}">this link</a>
  </center>
<//body>
</html>
EOF

}

###############
# Login Stuff #
###############
# Login as user, returns key if success and empty string
# if failure
# 1->user, 2->pass
function LoginUser () {
  local user="$(IsSaneUser "$1")" pass="$2"

  # Check if user and password work
  if out=$(builtin echo -e "${pass}\n" | su -c "true" - "${user}" 2>&1 1>/dev/null); then
    local key=$(GenerateKey)

    if [[ "$(LockLoginMutex)" == "LOCKED" ]]; then
      local now=$(date +%s)
      local timeout=$(( ${now} + ${EXPIRATION} ))
      local t=$(mktemp /tmp/login.XXXXXX)

      # Remove all previous login entries for user
      awk -v user="${user}" '
        BEGIN { FS = "|" }
        {
          if ( $1 != user ) {
            print $0;
          }
        }' "${LOGIN_DB}" > "${t}"

      # move new file to DB location
      cp --no-preserve=mode,ownership "${t}" "${LOGIN_DB}"
      rm "${t}"

      # Add new key
      builtin echo "${user}|${key}|${timeout}" >> "${LOGIN_DB}"

      # Unlock mutex
      UnlockLoginMutex

      # Return key to caller
      echo "${key}"
    fi
  fi
}

# Validates if user/key pair match
# 1->user, 2->key
function ValidateUserKey () {
  local user="$(IsSaneUser "$1")" key="$2"

  awk -v user="${user}" -v key="${key}" '
    BEGIN { FS = "|" }
    {
      if ( $1 == user && $2 == key) {
        print $0;
        exit 0;
      }
    }' "${LOGIN_DB}"
}

# Log out user
# 1->user, 2->key
function LogoutUser () {
  local user="$(IsSaneUser "$1")" key="$2"

  if [[ ! -z "$(ValidateUserKey "${user}" "${key}")" ]]; then
    if [[ "$(LockLoginMutex)" == "LOCKED" ]]; then
      local t=$(mktemp /tmp/logout.XXXXXX)

      # Remove all previous logins
      awk -v user="${user}" 'BEGIN{FS="|"}{if ( $1 != user ) { print $0; } }' "${LOGIN_DB}" > "${t}"
      # move new file to DB location
      cp --no-preserve=mode,ownership "${t}" "${LOGIN_DB}"
      rm "${t}"

      # Unlock mutex
      UnlockLoginMutex

      # Return value
      echo "LOGOUT"
    else
      echo "BUSY"
    fi
  else
    echo "INVALID"
  fi
}

# Clean out all old logins
function CleanupLogin () {
  if [[ "$(LockLoginMutex)" == "LOCKED" ]]; then
    local t="$(mktemp /tmp/login.XXXXXX)"
    awk -v now="$(date +%s)" '
      BEGIN { FS = "|" }
      {
        if ( $3 > now ) {
          print $0;
        }
      }' "${LOGIN_DB}" > "${t}"

    # move new file to DB location
    cp --no-preserve=mode,ownership "${t}" "${LOGIN_DB}"
    rm "${t}"

    UnlockLoginMutex
  else
    echo "BUSY"
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
      clear: both;
      padding: 5px;
    }
    input.textbox-600 {
      width: 600px;
    }
    input.textbox-300 {
      width: 300px;
    }
  </style>
</head>
EOF
}

function Title () {
  local sub="$1"

  if [[ ! -z "${sub}" ]]; then
    sub=" - ${sub}"
  fi

  cat << EOF
  <h1>${TITLE}${sub}</h1>
  <small>Version: ${VERSION}</small><br />
EOF
}


########
# Main #
########

extPath="$(ExtPath)"
userId="$(PathUserId "${extPath}")"
case "${extPath}" in
  "" | "/")
    cgi_getvars BOTH cmd
    case "${cmd}" in
      "")
        MainPage
        ;;
      "shorten")
        cgi_getvars BOTH longurl
        ShortenPage "${longurl}"
        ;;
      "login")
        LoginPage
        ;;
      "trylogin")
        cgi_getvars POST user
        cgi_getvars POST password
        TryLogin "${user}" "${password}"
        ;;
      *)
        MainPage
        ;;
    esac
    ;;
  "/u/${userId}")
    cgi_getvars BOTH cmd
    case "${cmd}" in
      "logout")
        LogoutPage
        ;;
      "useraddlink")
        cgi_getvars POST longurl
        cgi_getvars POST name
        cgi_getvars POST tag
        UserAddLinkPage "${userId}" "${longurl}" "${name}" "${tag}"
        ;;
      "userupdatelink")
        cgi_getvars POST longurl
        cgi_getvars POST name
        cgi_getvars POST tag
        cgi_getvars POST shortid
        UserUpdateLinkPage "${userId}" "${shortid}" "${longurl}" "${name}" "${tag}"
        ;;
      "updatelink")
        cgi_getvars BOTH shortid
        UserPage "${userId}" "${shortid}"
        ;;
      "deletelink")
        cgi_getvars BOTH shortid
        UserDeleteLinkPage "${userId}" "${shortid}"
        ;;
      *)
        UserPage "${userId}"
        ;;
    esac
    ;;
  *)
    ExpandPage "${extPath}"
    ;;
esac
