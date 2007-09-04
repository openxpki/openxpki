
# do not change the order
# some packages have build dependencies
PACKAGES=	\
	core			\
	perl-client-api		\
	deployment		\
	mason-html-client	\
	i18n

EXTERNAL=	\
	Data__Password \
	XML__Filter__XInclude \
	XML__Validator__Schema

.PHONY : $(PACKAGES) $(EXTERNAL)

default:	clean
	make $(EXTERNAL)
	make $(PACKAGES)
	make resultlocal
	make check

$(EXTERNAL):
	dh-make-perl --build --cpan $(subst __,::,$@)

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
	for DIR in $(subst __,-,$(EXTERNAL)); do \
		rm -rf $$DIR-*; \
	done

distclean: clean
