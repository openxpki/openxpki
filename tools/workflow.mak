#
# It modifies the generic deployment files to have the changes needed
# for testing without going through the full deployment or having
# to maintain separate versions of files, depending on the test environment.
#
# Edit tools/workflow.cfg to the template values needed for your test env.
#
# Usage: (Important: run from root dir of code branch)
#
#  cd <root directory of your git/svn branch>
#  make -f tools/workflow.mak
#
#  to run tests:
#
#  make -f tools/workflow.mak test

# Set this to the destination directory for the XML files
userca := config/files/etc/openxpki/instances/trustcenter1

defaultxml := trunk/deployment/etc/templates/default
ogflow := tools/scripts/ogflow.pl
ogflowopts := 
#ogflowopts := --verbose
metaconf := trunk/deployment/bin/openxpki-metaconf
config := config/workflow.cfg
workflows := test_tools smartcard_cardadm smartcard_personalization_v4

# config/workflow.inc contains common settings for all customized workflows
include config/workflow.inc

# optional: config/workflow.local may be used to override settings (should not be checked in)
-include config/workflow.local

# Create the four individual Workflow XML files
basenames := $(foreach file,$(workflows),workflow_def_$(file) workflow_activity_$(file) workflow_condition_$(file) workflow_validator_$(file))

# Prepend the full file path of the host-specific files and add .xml extension
xmls := $(foreach file,$(basenames),$(userca)/$(file).xml)
xmlins := $(foreach file,$(basenames),$(userca)/$(file).xml.in)

all: $(xmls)

clean:
	rm -f $(xmlins)

cleanall: clean
	rm -f $(xmls)

debug:
	@echo "XMLS: $(xmls)"
	@echo "userca: $(userca)"

FULLPERLRUN = /usr/bin/perl
TEST_VERBOSE = 0
TEST_FILES = tools/scripts/t/*.t

test:
	PERL_DL_NONLAZY=1 $(FULLPERLRUN) "-MExtUtils::Command::MM" "-e" "test_harness($($TEST_VERBOSE))" $(TEST_FILES)
	
# Create the intermediate XML files
# TODO: speed up ogflow.pl by caching parse of plist, which is very time consuming

$(userca)/workflow_def_%.xml.in: $(defaultxml)/graffle/workflow_%.graffle $(ogflow)
	$(ogflow) $(ogflowopts) --outtype=states --outfile="$@" --infile="$<"

$(userca)/workflow_activity_%.xml.in: $(defaultxml)/graffle/workflow_%.graffle $(ogflow)
	$(ogflow) $(ogflowopts) --outtype=actions --outfile="$@" --infile="$<"

$(userca)/workflow_condition_%.xml.in: $(defaultxml)/graffle/workflow_%.graffle $(ogflow)
	$(ogflow) $(ogflowopts) --outtype=conditions --outfile="$@" --infile="$<"

$(userca)/workflow_validator_%.xml.in: $(defaultxml)/graffle/workflow_%.graffle $(ogflow)
	$(ogflow) $(ogflowopts) --outtype=validators --outfile="$@" --infile="$<"

.PHONY: all test debug clean

.SECONDARY:

# Process the local mods for this test server

%.xml: %.xml.in $(config)
	$(metaconf) --config $(config) --file $< > "$@"

