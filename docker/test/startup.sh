#!/bin/bash

BRANCH="$1"
GITHUB_USER_REPO="$2"

echo -e "\n====[ MySQL ]===="
nohup sh -c mysqld >/tmp/mysqld.log &

#
# Wait for database initialization
#
echo "Waiting for DB initialize (max. 120 seconds)"
sec=0; error=1
while [ $error -ne 0 -a $sec -lt 60 ]; do
    error=$(echo "quit" | mysql -h 127.0.0.1 -uroot --connect_timeout=1 2>&1 | grep -c ERROR)
    sec=$[$sec+1]
    sleep 1
done
if [ $error -ne 0 ]; then
    echo "It seems that the MySQL database was not started. Output:"
    echo "quit" | mysql -h 127.0.0.1 -uroot --connect_timeout=1
    exit 333
fi

set -e

#
# Database setup
#
echo "Preparing database for OpenXPKI (user + schema)"

cat <<__SQL | mysql -h 127.0.0.1 -uroot
DROP database IF EXISTS $OXI_TEST_DB_MYSQL_NAME;
CREATE database $OXI_TEST_DB_MYSQL_NAME CHARSET utf8;
CREATE USER '$OXI_TEST_DB_MYSQL_USER'@'%' IDENTIFIED BY '$OXI_TEST_DB_MYSQL_PASSWORD';
GRANT ALL ON $OXI_TEST_DB_MYSQL_NAME.* TO '$OXI_TEST_DB_MYSQL_USER'@'%';
flush privileges;
__SQL

#
# Repository clone
#
set +e

# Default: remote Github repo
REPO=https://dummy:nope@github.com/$GITHUB_USER_REPO.git

# Local repo from host (if Docker volume is mounted)
mountpoint -q /repo && REPO=file:///repo

echo -e "\n====[ Git checkout: $BRANCH from $REPO ]===="
git ls-remote -h $REPO >/dev/null 2>&1
if [ $? -ne 0 ]; then
    2>&1 echo "ERROR: Git repo either does not exist or is not readable for everyone"
    exit 1
fi
set -e
git clone --depth=1 --branch=$BRANCH $REPO /opt/openxpki

#
# Grab and install Perl module dependencies from Makefile.PL using PPI
#
echo -e "\n====[ Scanning Makefile.PL for new Perl dependencies ]===="
cpanm --quiet --notest PPI

perl -e '
use PPI;
use PPI::Dumper;

$doc = PPI::Document->new("/opt/openxpki/core/server/Makefile.PL") or die "Makefile.PL not found";
$doc->prune("PPI::Token::Whitespace");
$doc->prune("PPI::Token::Comment");

my $sub = $doc->find_first(sub {                         # find
    $_[1]->parent == $_[0]                               # at root level
    and $_[1]->isa("PPI::Statement")                     # a statement
    and $_[1]->first_element->content eq "WriteMakefile" # called "WriteMakefile"
}) or die "Subroutine call WriteMakefile() not found\n";

$key = $sub->find_first(sub {                            # below that find
    $_[1]->isa("PPI::Token::Quote")                      # a quoted string
    and $_[1]->content =~ /PREREQ_PM/                    # called "PREREQ_PM"
}) or die "Argument PREREQ_PM not found in WriteMakefile()\n";

$list = $key->next_sibling->next_sibling; # skip "=>" and go to HashRef "{}"
$list->prune("PPI::Token::Operator");     # remove all "=>"
%modmap = map { s/(\x27|\x22)//g; $_ }    # remove single or double quotes
    map { $_->content }
    @{$list->find("PPI::Token")};

use version;
my @modlist =
    map { "$_~".$modmap{$_} }
    grep {
        ! (
            eval "require $_;" and
            eval "version->parse($_->VERSION) >= version->parse($modmap{$_})"
        )
    }
    keys %modmap;

if (@modlist) {
    print "installing missing dependencies\n";
    system("cpanm --quiet --notest ".join(" ", @modlist));
}
'

#
# Unit tests
#
echo -e "\n====[ Compile and test OpenXPKI ]===="
# Config::Versioned reads USER env variable
export USER=dummy

cd /opt/openxpki/core/server
perl Makefile.PL
make
make test

#
# OpenXPKI installation
#
echo -e "\n====[ Install OpenXPKI ]===="
make install > /dev/null

# directory list borrowed from /package/debian/core/libopenxpki-perl.dirs
mkdir -p /var/openxpki/session
mkdir -p /var/log/openxpki

# copy config
cp -R /opt/openxpki/config/openxpki /etc

# customize config
sed -ri 's/^((user|group):\s+)\w+/\1root/' /etc/openxpki/config.d/system/server.yaml

cat <<__DB > /etc/openxpki/config.d/system/database.yaml
main:
    debug: 0
    type: MySQL
    host: 127.0.0.1
    name: $OXI_TEST_DB_MYSQL_NAME
    user: $OXI_TEST_DB_MYSQL_USER
    passwd: $OXI_TEST_DB_MYSQL_PASSWORD
__DB

/bin/bash /opt/openxpki/config/sampleconfig.sh

/usr/local/bin/openxpkictl start

#
# QA tests
#
cd /opt/openxpki/qatest/backend/nice/  && prove .
cd /opt/openxpki/qatest/backend/api/   && prove .
cd /opt/openxpki/qatest/backend/webui/ && prove .
