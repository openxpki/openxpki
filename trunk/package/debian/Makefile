
# do not change the order
# some packages have build dependencies
PACKAGES=	\
	core			\
	perl-client-api		\
	perl-cli-client		\
	deployment		\
	mason-html-client	\
	i18n

.PHONY : $(PACKAGES)

default:	clean
	make $(PACKAGES)
	make resultlocal
	make check

$(PACKAGES):
	cd $@ && PATH=$(PATH):/usr/sbin make $(SUBTARGET)

resultlocal:
	mv */*.dsc .     || echo No dsc file present.
	mv */*.dsc.asc . || echo No asc file present.
	mv */*.tar.gz .  || echo No source file present.
	mv */*.deb .     || echo No debian package file present.
	mv */*.changes . || echo No changes file present.

check:
	# use -i to see more details
	lintian *.deb

clean:
	rm -f *.dsc *.dsc.asc *.tar.gz *.deb *.changes
	make $(PACKAGES) SUBTARGET=clean

distclean: clean
