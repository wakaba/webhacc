all: cc-msg.en.txt error-description.en.html.u8

cc-msg.en.txt: error-description-source.xml mkcatalog.pl
	perl mkcatalog.pl $< > $@

error-description.en.html.u8: error-description-source.xml mkdescription.pl
	perl mkdescription.pl $< > $@
