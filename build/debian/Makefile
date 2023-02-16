
EXTRA_DIRS=packages repository extra

-include Makefile.local

.PHONY: dirs

all: cpan openxpki repo test

Makefile.local: ;

build-deps.lst:
	cp ../../package/debian/build-deps.lst .

debian-deps.lst:
	cp ../../package/debian/debian-deps.lst .

build: build-deps.lst
	docker build -t oxibuilder4debian .

build-nocache: build-deps.lst
	docker build --no-cache -t oxibuilder4debian .

upload:
	rsync -av repository/* packages.openxpki.org:/var/www/hosts/packages.openxpki.org/v3/debian/

$(EXTRA_DIRS):
	@mkdir -m 755 -p $@

dirs: $(EXTRA_DIRS)

repo:
	docker run --rm -ti \
		-v $(abspath ../../):/openxpki:ro \
		-v $(abspath repository):/repository \
		-v $(abspath extra:/extra-packages) \
		-v $(abspath packages):/packages \
		-v $(abspath secret/debian2021.key):/signkey:ro oxibuilder4debian repo

%: packages
	docker run --rm -ti \
	    -v $(abspath ../../):/openxpki:ro \
		-v $(abspath deps):/deps \
		-v $(abspath packages):/packages \
		-e OPENXPKI_BUILD_DEBUG=${OPENXPKI_BUILD_DEBUG} \
		-e OPENXPKI_BUILD_TAG=${OPENXPKI_BUILD_TAG} \
		oxibuilder4debian $@
