all: error-description.en.html.u8

error-description.en.html.u8: error-description-source.xml mkdescription.pl
	perl mkdescription.pl $< > $@
