# Makefile for myperl-openxpki-i18n

PACKAGE_NAME	:= myperl-openxpki-i18n
I18N_DIR		:= ../../../core/i18n

include ../myperl-common.mk

#install: cpanm info
install: info
	cd $(I18N_DIR) && make scan
	cd $(I18N_DIR) && make
	cd $(I18N_DIR) && make install DESTDIR=$(DESTDIR) PREFIX=/opt/myperl

