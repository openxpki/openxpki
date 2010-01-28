#!/bin/sh

# base module template
basemod=./basemod-2.6.26-2010-01-13_0021.xml



isomaker \
  -b $basemod \ 
  -m ./openxpki-lightgui.xml \
  -n ./openxpki-mini.xml \
  -r http://www.morphix.org/debian \
  -p grub-gfxboot-iso-udeb \
  -p morphix-cdrom-misc-udeb \
  -p morphix-grub-menulist-udeb \
  -p morphix-iso-grubtheme \
  ./lightgui.iso 2>&1|tee build.log

morphix-rebrand ./lightgui.iso ./openxpki_live.iso ./OpenXPKI_Live.png

rm lightgui.iso
