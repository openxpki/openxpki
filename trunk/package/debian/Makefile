
PACKAGES=	\
	core	\
	deployment

.PHONY : $(PACKAGES)

default:	clean
	make $(PACKAGES)

$(PACKAGES):
	cd $@ && make
	mv $@/*.dsc .
	mv $@/*.dsc.asc .
	mv $@/*.tar.gz .
	mv $@/*.deb .
	# use -i to see more details
	lintian *.deb

clean:
	rm -f *.dsc *.dsc.asc *.tar.gz *.deb
