

build-deps.lst:
	cp ../../package/debian/build-deps.lst .

build: build-deps.lst
	docker build -t oxibuilder4debian .

build-nocache: build-deps.lst
	docker build --no-cache -t oxibuilder4debian .

upload:
	rsync -av repository/* packages.openxpki.org:/var/www/hosts/packages.openxpki.org/v3/debian/

repo:
	docker run --rm -ti \
		-v $(abspath ../../):/openxpki \
		-v $(abspath repository):/repository \
		-v $(abspath extra:/extra-packages) \
		-v $(abspath packages):/packages \
		-v $(abspath secret/debian2021.key):/signkey oxibuilder4debian repo

%:
	docker run --rm -ti \
	    -v $(abspath ../../):/openxpki \
		-v $(abspath deps):/deps \
		-v $(abspath packages):/packages \
		oxibuilder4debian $@
