# This Makefile creates the supplemental data
# needed for the Enrollment tests
#

workflows := enrollment

basedir := ../../../../..
xmldir := $(basedir)/core/config/basic/realm/ca-one/_workflow
graffledir := $(basedir)/core/config/graffle
ogflow := $(basedir)/tools/scripts/ogflow.pl

# Create the four individual Workflow XML files
basenames := $(foreach file,$(workflows),workflow_def_$(file) workflow_activity_$(file) workflow_condition_$(file) workflow_validator_$(file))

# Add .xml extension
xmls := $(foreach file,$(basenames),$(file).xml)

xml: $(xmls)

cleanall:
	rm -f $(xmls)

debug:
	ls -l $(basedir)

workflow_def_%.xml: $(graffledir)/workflow_%.graffle $(ogflow)
	$(ogflow) $(ogflowopts) --outtype=states --outfile="$@" --infile="$<"

workflow_activity_%.xml: $(graffledir)/workflow_%.graffle $(ogflow)
	$(ogflow) $(ogflowopts) --outtype=actions --outfile="$@" --infile="$<"

workflow_condition_%.xml: $(graffledir)/workflow_%.graffle $(ogflow)
	$(ogflow) $(ogflowopts) --outtype=conditions --outfile="$@" --infile="$<"

workflow_validator_%.xml: $(graffledir)/workflow_%.graffle $(ogflow)
	$(ogflow) $(ogflowopts) --outtype=validators --outfile="$@" --infile="$<"

enrollment: workflow_def_enrollment.xml
enrollment: workflow_activity_enrollment.xml
enrollment: workflow_condition_enrollment.xml
enrollment: workflow_validator_enrollment.xml


