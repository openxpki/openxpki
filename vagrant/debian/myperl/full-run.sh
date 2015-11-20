#!/bin/bash
#
# full-run.sh - start vagrant instances, build packages, test 'em
#
# NOTE: This assumes that it starts with a clean slate, so it's best
# to just destroy any current instances. You'll have to do that 
# yourself--I'm too paranoid.

set -e -x

vagrant up build-myperl
vagrant ssh build-myperl --command '/vagrant/myperl/build.sh all'
vagrant ssh build-myperl --command '/vagrant/myperl/build.sh collect'
vagrant up test-myperl
vagrant ssh test-myperl --command 'sudo /vagrant/myperl/install-oxi.sh'
vagrant ssh test-myperl --command 'sudo /vagrant/myperl/run-tests.sh'

