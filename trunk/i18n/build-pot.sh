#!/bin/sh

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

grep -r 'I18N_OPENXPKI' $@ | sed "s/.*I18N_OPENXPKI/I18N_OPENXPKI/" | sed "s/[\"'].*//" | sed "s/[<].*//" | sed "s/.*=>.*/XX_ERASE_XX/" | sed "s/.*).*/XX_ERASE_XX/" | sort | uniq | sed "s/^I/msgid \"I/g" | sed "s/\$/\"msgstr \"\"\n/g" | sed "s/.*XX_ERASE_XX.*//g" | sed "s/msgstr/\nmsgstr/g"

