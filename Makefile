# The files to watch:

# The master file of the document
ROOTFILE            = Licenta_Andrei

# All the (other) .tex files
SATELITFILES	    = *.tex

# make a pdf
.PHONY : pdf
pdf : $(ROOTFILE).pdf

# make rootfile.pdf
$(ROOTFILE).pdf : $(SATELITFILES)
	pdflatex $(ROOTFILE).tex

# make bibliogrphy
.PHONY : bib
bib :	
	bibtex $(ROOTFILE)

# make index
#.PHONY : index
#index :	
#	makeindex $(ROOTFILE)

# make the full document
.PHONY : all
all : 
	make clean
	pdflatex $(ROOTFILE).tex
	makeglossaries $(ROOTFILE)
	pdflatex $(ROOTFILE).tex
	bibtex $(ROOTFILE)
	pdflatex $(ROOTFILE).tex
	makeindex $(ROOTFILE)
	pdflatex $(ROOTFILE).tex
	pdflatex $(ROOTFILE).tex
	makeglossaries $(ROOTFILE)
	pdflatex $(ROOTFILE).tex
	pdflatex $(ROOTFILE).tex

# make the document, fast
.PHONY : fast
fast :
	make clean
	pdflatex $(ROOTFILE).tex
	bibtex $(ROOTFILE)
	makeindex $(ROOTFILE)
	pdflatex $(ROOTFILE).tex
	pdflatex $(ROOTFILE).tex
	makeglossaries $(ROOTFILE)
	pdflatex $(ROOTFILE).tex
	pdflatex $(ROOTFILE).tex

# remove the temporary files
.PHONY : clean
clean :
	rm -f *.aux
	rm -f *.log
	rm -f *~
	rm -f *.toc
	rm -f *.bbl
	rm -f *.blg
	rm -f *.bak
	rm -f .*.swp
	rm -f *.idx
	rm -f *.ilg
	rm -f *.ind
	rm -f *.out
	rm -f *.glx
	rm -f *.gxg
	rm -f *.gxs
	rm -f *.glo
	rm -f *.acn
	rm -f *.acr
	rm -f *.alg
	rm -f *.gls
	rm -f *.glg
	rm -f *.ist
	rm -f *.lot
	rm -f *.lof

# remove everything but the sourcefiles
.PHONY : cleanfull
cleanfull :
	make clean
	rm -f *.pdf
	rm -f *.ps
	rm -f *.dvi



# Rommel:

# Niet gebruiken: een ps maken
$(ROOTFILE).ps : $(ROOTFILE).dvi
	dvips $(ROOTFILE).dvi -o $(ROOTFILE).ps

# Niet gebruiken: een dvi maken
$(ROOTFILE).dvi : $(SATELITFILES)
	latex $(ROOTFILE).tex


