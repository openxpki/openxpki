#!/bin/bash
set -euo pipefail

VBOX_VERSION="$1"

announce() {
    echo ""
    echo "=================================================="
    echo "$1"
    echo "--------------------------------------------------"
}

announce "Basic setup"
/vagrant/assets/provision-basics.sh

announce "Install Virtualbox guest addins"
/vagrant/assets/provision-vbox.sh $VBOX_VERSION

announce "Install Git"
/vagrant/assets/provision-git.sh

announce "Install cpanm"
/vagrant/assets/provision-cpanm.sh

announce "Install Docker CE"
/vagrant/assets/provision-docker.sh

# Install Oracle DBMS
#announce "Install Oracle DBMS"
#/vagrant/assets/provision-oracle.sh

announce "Install MariaDB DBMS"
/vagrant/assets/provision-mysql.sh

announce "Install OpenXPKI"
/vagrant/assets/provision-openxpki.sh

announce "Install SQLite"
/vagrant/assets/provision-sqlite.sh

announce "Cleanup"
/vagrant/assets/provision-cleanup.sh
