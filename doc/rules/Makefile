# doc/rules — Pandoc build for the Rules Registry (ADR-050).
#
# Builds R*.html siblings + a single rules.html master with all rules
# inlined. Source markdown stays the source of truth; HTML is for browsing.
#
# Dependencies: pandoc.
#   macOS:  brew install pandoc
#   Linux:  apt install pandoc
#
# Usage:
#   make rules        # build everything
#   make clean        # remove generated HTML
#   make watch        # rebuild on change (requires entr)
#
# Outputs land alongside sources (R001.html next to R001.md). The master
# rules.html concatenates all R*.md files with ToC + per-rule anchors.

RULE_SOURCES := $(sort $(wildcard R*.md))
RULE_HTMLS   := $(RULE_SOURCES:.md=.html)

PANDOC      ?= pandoc
PANDOC_OPTS := --from gfm --to html5 --standalone --section-divs --toc

.PHONY: rules clean watch

rules: rules.html $(RULE_HTMLS)

# Master: concatenate all R*.md with cross-rule navigation.
# README.md is the index page; R*.md files contain the rule statements.
rules.html: README.md $(RULE_SOURCES)
	@echo "  pandoc → rules.html ($(words $(RULE_SOURCES)) rules)"
	@$(PANDOC) $(PANDOC_OPTS) \
	    --metadata title="SPWS Rebuild Rules Registry" \
	    -o $@ $^

# Per-rule pages.
%.html: %.md
	@echo "  pandoc → $@"
	@$(PANDOC) $(PANDOC_OPTS) \
	    --metadata title="$*" \
	    -o $@ $<

clean:
	rm -f rules.html $(RULE_HTMLS)

# Optional: live rebuild (requires `entr`).
watch:
	@which entr >/dev/null || { echo "entr not installed (brew install entr)"; exit 1; }
	@ls *.md | entr -c make rules
