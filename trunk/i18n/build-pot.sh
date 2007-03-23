#!/bin/sh
OXI18="I18N_OPENXPKI_"
OXSEDCMD="\
/$OXI18/h;\
s/$OXI18\([A-Z0-9_]*\).*/$OXI18\1/;\
s/.*$OXI18\([A-Z0-9_]*\)/msgid \"$OXI18\1\"/;\
/$OXI18/p;\
/$OXI18/x;\
s/$OXI18\([A-Z0-9_]*\)//;\
tcycle"

if [ "x$SED" = "x" ]; then
    SED=sed
fi

if test ! -d "$1"; then
   echo "Directory '$1' for scan not found." > /dev/stderr
   exit 1
fi

echo "
# SOME DESCRIPTIVE TITLE.
# Copyright (C) YEAR THE PACKAGE'S COPYRIGHT HOLDER
# This file is distributed under the same license as the PACKAGE package.
# FIRST AUTHOR <EMAIL@ADDRESS>, YEAR.
#
"
echo '
msgid ""
msgstr ""
"Project-Id-Version: PACKAGE VERSION\n"
"Report-Msgid-Bugs-To: \n"
"POT-Creation-Date: 2004-09-08 14:02+0200\n"
"PO-Revision-Date: YEAR-MO-DA HO:MI+ZONE\n"
"Last-Translator: FULL NAME <EMAIL@ADDRESS>\n"
"Language-Team: LANGUAGE <LL@li.org>\n"
"MIME-Version: 1.0\n"
"Content-Type: text/plain; charset=UTF-8\n"
"Content-Transfer-Encoding: 8bit\n"
'

grep -Ir 'I18N_OPENXPKI' $@ \
| grep -v ".svn" \
| $SED -n -e :cycle  -e "$OXSEDCMD" \
| sort | uniq \
| $SED "s/.*XX_ERASE_XX.*//g;G" \
| $SED "s/^\$/msgstr \"\"/g"
