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
xmldir := core/config/basic/realm/ca-one/_workflow

graffledir := core/config/graffle
ogflow := tools/scripts/ogflow.pl
ogflowopts := 
#ogflowopts := --verbose
# Metaconf seems to have gone away with the recent reorg
#metaconf := trunk/deployment/bin/openxpki-metaconf
config := config/workflow.cfg
# Not all workflow docs have been transfered from customer repo, so we'll
# just add them as we move them over.
#workflows := test_tools smartcard_fetch_puk smartcard_cardadm smartcard_personalization_v4 enrollment
workflows := enrollment certificate_revoke

# config/workflow.inc contains common settings for all customized workflows
-include config/workflow.inc

# optional: config/workflow.local may be used to override settings (should not be checked in)
-include config/workflow.local

# Create the four individual Workflow XML files
basenames := $(foreach file,$(workflows),workflow_def_$(file) workflow_activity_$(file) workflow_condition_$(file) workflow_validator_$(file))

# Prepend the full file path of the host-specific files and add .xml extension
xmls := $(foreach file,$(basenames),$(xmldir)/$(file).xml)
#xmlins := $(foreach file,$(basenames),$(xmldir)/$(file).xml.in)

all: $(xmls)

clean:
	rm -f $(xmlins)

cleanall: clean
	rm -f $(xmls)

debug:
	@echo "XMLS: $(xmls)"
	@echo "xmldir: $(xmldir)"
	@echo "graffledir: $(graffledir)"

FULLPERLRUN = /usr/bin/perl
TEST_VERBOSE = 0
TEST_FILES = tools/scripts/t/*.t

test:
	PERL_DL_NONLAZY=1 $(FULLPERLRUN) "-MExtUtils::Command::MM" "-e" "test_harness($($TEST_VERBOSE))" $(TEST_FILES)
	
# Create the intermediate XML files
# TODO: speed up ogflow.pl by caching parse of plist, which is very time consuming

$(xmldir)/workflow_def_%.xml: $(graffledir)/workflow_%.graffle $(ogflow)
	$(ogflow) $(ogflowopts) --outtype=states --outfile="$@" --infile="$<"

$(xmldir)/workflow_activity_%.xml: $(graffledir)/workflow_%.graffle $(ogflow)
	$(ogflow) $(ogflowopts) --outtype=actions --outfile="$@" --infile="$<"

$(xmldir)/workflow_condition_%.xml: $(graffledir)/workflow_%.graffle $(ogflow)
	$(ogflow) $(ogflowopts) --outtype=conditions --outfile="$@" --infile="$<"

$(xmldir)/workflow_validator_%.xml: $(graffledir)/workflow_%.graffle $(ogflow)
	$(ogflow) $(ogflowopts) --outtype=validators --outfile="$@" --infile="$<"

.PHONY: all test debug clean

#smartcard_cardadm: $(xmldir)/workflow_def_smartcard_cardadm.xml
#smartcard_cardadm: $(xmldir)/workflow_activity_smartcard_cardadm.xml
#smartcard_cardadm: $(xmldir)/workflow_condition_smartcard_cardadm.xml
#smartcard_cardadm: $(xmldir)/workflow_validator_smartcard_cardadm.xml
#
#smartcard_fetch_puk: $(xmldir)/workflow_def_smartcard_fetch_puk.xml
#smartcard_fetch_puk: $(xmldir)/workflow_activity_smartcard_fetch_puk.xml
#smartcard_fetch_puk: $(xmldir)/workflow_condition_smartcard_fetch_puk.xml
#smartcard_fetch_puk: $(xmldir)/workflow_validator_smartcard_fetch_puk.xml
#
#test_tools: $(xmldir)/workflow_def_test_tools.xml
#test_tools: $(xmldir)/workflow_activity_test_tools.xml
#test_tools: $(xmldir)/workflow_condition_test_tools.xml
#test_tools: $(xmldir)/workflow_validator_test_tools.xml

enrollment: $(xmldir)/workflow_def_enrollment.xml
enrollment: $(xmldir)/workflow_activity_enrollment.xml
enrollment: $(xmldir)/workflow_condition_enrollment.xml
enrollment: $(xmldir)/workflow_validator_enrollment.xml

certificate_revoke: $(xmldir)/workflow_def_certificate_revoke.xml
certificate_revoke: $(xmldir)/workflow_activity_certificate_revoke.xml
certificate_revoke: $(xmldir)/workflow_condition_certificate_revoke.xml
certificate_revoke: $(xmldir)/workflow_validator_certificate_revoke.xml

.SECONDARY:

# Process the local mods for this test server

#%.xml: %.xml.in $(config)
#	$(metaconf) --config $(config) --file $< > "$@"

