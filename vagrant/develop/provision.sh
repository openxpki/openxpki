#!/bin/bash
set -euo pipefail

VBOX_VERSION="$1"

announce() {
    echo ""
    echo "=================================================="
    echo "$1"
    echo "--------------------------------------------------"
}

# Basic Vagrant Box setup
announce "Basic setup"
/vagrant/assets/provision-basic.sh $VBOX_VERSION

# Install Docker CE
announce "Install Docker CE"
/vagrant/assets/provision-docker.sh

# Install Oracle DBMS
#announce "Install Oracle DBMS"
#/vagrant/assets/provision-oracle.sh

# Install MariaDB DBMS (Docker container)
announce "Install MariaDB DBMS"
/vagrant/assets/provision-mysql.sh

# Install OpenXPKI
announce "Install OpenXPKI"
/vagrant/assets/provision-openxpki.sh

# Install SQLite DBMS (needs OpenXPKI installed / OXI_CORE_DIR)
announce "Install SQLite"
/vagrant/assets/provision-sqlite.sh

# Cleanup
announce "Cleanup"
/vagrant/assets/provision-cleanup.sh
