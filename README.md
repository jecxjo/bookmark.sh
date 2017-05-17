# bookmark.sh
A cgi script for shortening URLs and managing bookmarks.

## Description
This script generates a very basic basic web page to shorten URLs. Drop the
file in your `cgi-bin` directory and setup a directory and the script does all
the work.

The script also supports personal bookmarks. Using the accounts on your server,
users can login, shorten URLs and add names and tags.

Everything in the script is basic shell and system commands. User accounts are
those on your server. Databases are two flat files, one to hold cookies and one
to hold links. Keep it simple.

## Setup

Setup a directory to store the database information. Permissions should be set
to your cgi/web account.

    # mkdir /var/lib/bookmark.sh
    # chown http:http /var/lib/bookmark.sh
    # chmod 700 /var/lib/bookmark.sh

Next drop the script into your `cgi-bin` directory. Modify the configuration
and change it's permissions to executable.

    # vim /srv/http/cgi-bin/bookmark.sh
    # chown http:http /srv/http/cgi-bin/bookmark.sh
    # chmod 700 /srv/http/cgi-bin/bookmark.sh

Once the options are configured (see section below) you can add users via the
command line. Once user is created they can change the password once logged in.

    # /srv/http/cgi-bin/bookmark.sh adduser foo bar

If the password is lost, just run the same command to replace with a new
password.

## Options

    # Path to store database info
    DB_DIR="/var/lib/bookmark.sh"
    
    # Title of page
    TITLE="Bookmark.sh"
    
    # Faull URL path. This is used in the HTML generation, all forms will
    # point to this path
    URL="https://example.com/cgi-bin/bookmark.sh"
    
    # Login expiration (in seconds)
    EXPIRATION=3600 # 1 hour
    
    # Expand delay (in seconds)
    DELAY=3
    
    # Enable User accounts
    # This allows the script to run as a bookmark app as well
    # as a URL shortener. If you just want a shortener set to
    # false.
    ENABLE_USERS=true
    
    # List of users that are not allowed to log into this service
    BLACKLIST=(root http nobody)

## License and Acknowledgements

This script uses bash_cgi created by Philippe Kehl. See
[site](http://oinkzwurgl.org/bash_cgi) for more information.

The rest of this script is released under the [New BSD License](http://opensource.org/licenses/BSD-3-Clause)
