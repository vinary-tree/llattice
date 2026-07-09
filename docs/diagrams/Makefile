# docs/diagrams/Makefile — render every diagram source in the docs tree to a sibling .svg.
#
# Tooling is drawn from the pgmcp `diagramming` toolbox catalog:
#   *.dot  → Graphviz  (graph_layout)     : dot -Tsvg
#   *.d2   → D2        (uml_architecture)  : d2
#   *.mmd  → Mermaid   (uml_architecture)  : mmdc  (headless Chromium)
#   *.tex  → TikZ/PGF  (diagram_language)  : latex → dvisvgm  (DVI route; no Ghostscript needed)
#
# `powerset-hasse.dot` is the canonical source for powerset-hasse.svg; `powerset-hasse.puml`
# is kept as an equivalent PlantUML reference and is NOT auto-rendered (it would clobber the .svg).
#
# Usage:  make            # render everything that is out of date
#         make clean      # remove all generated .svg
#         make list       # show discovered sources

DOCS := $(abspath $(CURDIR)/..)

DOT_SRC := $(shell find $(DOCS) -name '*.dot')
D2_SRC  := $(shell find $(DOCS) -name '*.d2')
MMD_SRC := $(shell find $(DOCS) -name '*.mmd')
TEX_SRC := $(shell find $(DOCS) -name '*.tex')

# Graphviz / D2 / TikZ emit portable native-text SVG (scalable, render everywhere).
# Mermaid is rendered to high-resolution PNG via mmdc (headless Chromium): its SVG output
# uses <foreignObject> HTML labels that GitHub/librsvg cannot rasterize, whereas Chromium
# renders them with full fidelity (spaces, wrapping, colour). PNG is portable to every viewer.
ALL_OUT := $(DOT_SRC:.dot=.svg) $(D2_SRC:.d2=.svg) $(MMD_SRC:.mmd=.png) $(TEX_SRC:.tex=.svg)

.PHONY: all clean list
all: $(ALL_OUT)
	@echo "✓ rendered $(words $(ALL_OUT)) diagram(s)."

%.svg: %.dot
	dot -Tsvg $< -o $@

%.svg: %.d2
	d2 --layout elk $< $@

%.png: %.mmd
	mmdc --quiet -c $(CURDIR)/mermaid.json -i $< -o $@ -s 2 -b white

# TikZ via the DVI route: latex emits .dvi, dvisvgm converts it directly (no Ghostscript dependency).
%.svg: %.tex
	cd $(dir $<) && latex -interaction=nonstopmode -halt-on-error $(notdir $<) >/dev/null \
	  && dvisvgm --no-fonts=0 $(notdir $(<:.tex=.dvi)) -o $(notdir $@) >/dev/null \
	  && rm -f $(notdir $(<:.tex=.dvi)) $(notdir $(<:.tex=.aux)) $(notdir $(<:.tex=.log))

clean:
	rm -f $(ALL_OUT)

list:
	@echo "DOT: $(DOT_SRC)"; echo "D2:  $(D2_SRC)"; echo "MMD: $(MMD_SRC)"; echo "TEX: $(TEX_SRC)"
