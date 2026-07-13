# docs/diagrams/Makefile — render every diagram source in the docs tree to a sibling .svg.
#
# Tooling is drawn from the pgmcp `diagramming` toolbox catalog:
#   *.dot   → Graphviz  (graph_layout)     : dot -Tsvg          (Hasse / order diagrams, flowcharts)
#   *.d2    → D2        (uml_architecture)  : d2 --layout elk    (taxonomy, dependency, concept maps)
#   *.puml  → PlantUML  (uml_architecture)  : plantuml -tsvg     (class / sequence diagrams)
#   *.tex   → TikZ/PGF  (diagram_language)  : latex → dvisvgm    (publication-grade math figures)
#
# All four engines emit portable, scalable, native-vector SVG that renders everywhere. PlantUML additionally
# typesets <latex>…</latex> labels through its bundled JLaTeXMath into embedded vector paths, so mathematical
# figure labels are true typeset math rather than unicode literals (see the pgmcp `diagrams-plantuml-latex`
# guideline). PlantUML is preferred over Mermaid for every diagram type both support; Mermaid is no longer
# used here (its retired sources live under docs/archive/ — see docs/archive/README.md).
#
# Sources under docs/archive/ are retired and are deliberately NOT rendered.
#
# Usage:  make            # render everything that is out of date
#         make clean      # remove all generated .svg
#         make list       # show discovered sources

DOCS  := $(abspath $(CURDIR)/..)
PRUNE := -not -path '*/archive/*'

DOT_SRC  := $(shell find $(DOCS) -name '*.dot'  $(PRUNE))
D2_SRC   := $(shell find $(DOCS) -name '*.d2'   $(PRUNE))
PUML_SRC := $(shell find $(DOCS) -name '*.puml' $(PRUNE))
TEX_SRC  := $(shell find $(DOCS) -name '*.tex'  $(PRUNE))

ALL_OUT := $(DOT_SRC:.dot=.svg) $(D2_SRC:.d2=.svg) $(PUML_SRC:.puml=.svg) $(TEX_SRC:.tex=.svg)

.PHONY: all clean list
all: $(ALL_OUT)
	@echo "✓ rendered $(words $(ALL_OUT)) diagram(s)."

%.svg: %.dot
	dot -Tsvg $< -o $@

%.svg: %.d2
	d2 --layout elk $< $@

# PlantUML writes <name>.svg next to the source (the @startuml name matches each file's basename).
%.svg: %.puml
	plantuml -tsvg $<

# TikZ via the DVI route: latex emits .dvi, dvisvgm converts it directly (no Ghostscript dependency).
%.svg: %.tex
	cd $(dir $<) && latex -interaction=nonstopmode -halt-on-error $(notdir $<) >/dev/null \
	  && dvisvgm --no-fonts=0 $(notdir $(<:.tex=.dvi)) -o $(notdir $@) >/dev/null \
	  && rm -f $(notdir $(<:.tex=.dvi)) $(notdir $(<:.tex=.aux)) $(notdir $(<:.tex=.log))

clean:
	rm -f $(ALL_OUT)

list:
	@echo "DOT:  $(DOT_SRC)"; echo "D2:   $(D2_SRC)"; echo "PUML: $(PUML_SRC)"; echo "TEX:  $(TEX_SRC)"
