# Pinto is used to manage a local CPAN Mirror.
#
# TARGETS:
#
# prereqs		Install Pinto from CPAN
#

PINTO_REPOSITORY_ROOT := $(HOME)/pinto

info:
	@echo "Pinto root = $(PINTO_REPOSITORY_ROOT)"
	@pinto -r $(PINTO_REPOSITORY_ROOT) list

prereqs:
	# need --notest because of http_proxy
	cpanm --notest App::Pinto

init: $(PINTO_REPOSITORY_ROOT)

load: load-openxpki-core load-misc

$(PINTO_REPOSITORY_ROOT):
	pinto -r $(PINTO_REPOSITORY_ROOT) init
	pinto -r $(PINTO_REPOSITORY_ROOT) copy master oxibld

openxpki-core.deps:
	(cd ~/git/openxpki/core/server && cpanm --scandeps .) \
		| grep 'Found dependencies' \
		| perl -pe 's/.+dependencies: //' > $@.new
	mv $@.new $@

load-openxpki-core: openxpki-core.deps
	cat $< | xargs pinto -r $(PINTO_REPOSITORY_ROOT) \
		pull --recurse --stack oxibld \
		--cascade --message "import oxi core"
		
load-misc: manual-cpan-mods.txt
	cat $< | xargs pinto -r $(PINTO_REPOSITORY_ROOT) \
		pull --recurse --stack oxibld --cascade \
		--message "import oxi misc"


