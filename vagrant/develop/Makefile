.PHONY: help up

help:
	@grep '^[a-zA-Z]' Makefile | awk -F ':.*?## ' 'NF==2 {printf "  %-26s%s\n", $$1, $$2}'

up: ## Start the Vagrant box and shell into it
# Not neccessary anymore with Virtualbox 7.2.2
#	@echo "Removing KVM kernel module"
#	@lsmod | grep -c '^kvm_amd\s'   >/dev/null && sudo rmmod kvm_intel kvm && echo "- AMD" || echo "- AMD: nothing to do"
#    @lsmod | grep -c '^kvm_intel\s' >/dev/null && sudo rmmod kvm_intel kvm && echo "- Intel" || echo "- Intel: nothing to do"
	vagrant up && vagrant ssh
