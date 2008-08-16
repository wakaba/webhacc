all: cc-msg.en.txt cc-msg.ja.txt \
  error-description.en.html.u8 \
  error-description.ja.html.u8

cc-msg.en.txt: error-description-source.xml mkcatalog.pl
	perl mkcatalog.pl $< en > $@

cc-msg.ja.txt: error-description-source.xml mkcatalog.pl
	perl mkcatalog.pl $< ja > $@

error-description.en.html.u8: error-description-source.xml mkdescription.pl
	perl mkdescription.pl $< en > $@

error-description.ja.html.u8: error-description-source.xml mkdescription.pl
	perl mkdescription.pl $< ja > $@
