all: build

WGET = wget
CURL = curl
GIT = git

updatenightly: local/bin/pmbp.pl
	$(CURL) -s -S -L https://gist.githubusercontent.com/wakaba/34a71d3137a52abb562d/raw/gistfile1.txt | sh
	$(GIT) add modules
	perl local/bin/pmbp.pl --update
	$(GIT) add config

## ------ Setup ------

deps: always
	true
ifdef PMBP_HEROKU_BUILDPACK
else
	$(MAKE) git-submodules
endif
	$(MAKE) pmbp-install

git-submodules:
	$(GIT) submodule update --init

PMBP_OPTIONS=

local/bin/pmbp.pl:
	mkdir -p local/bin
	$(CURL) -s -S -L https://raw.githubusercontent.com/wakaba/perl-setupenv/master/bin/pmbp.pl > $@
pmbp-upgrade: local/bin/pmbp.pl
	perl local/bin/pmbp.pl $(PMBP_OPTIONS) --update-pmbp-pl
pmbp-update: git-submodules pmbp-upgrade
	perl local/bin/pmbp.pl $(PMBP_OPTIONS) --update
pmbp-install: pmbp-upgrade
	perl local/bin/pmbp.pl $(PMBP_OPTIONS) --install \
	    --install-module Inline \
	    --install-module Crypt::SSLeay \
	    --install-module Mozilla::CA \
            --create-perl-command-shortcut @perl \
            --create-perl-command-shortcut @prove \
            --create-perl-command-shortcut @plackup=perl\ modules/twiggy-packed/script/plackup
	-perl local/bin/pmbp.pl $(PMBP_OPTIONS) \
	    --install-module Inline::Python

## ------ Build ------

PERL = ./perl

build: cc-msg.en.txt cc-msg.ja.txt \
  error-description.en.html.u8 \
  error-description.ja.html.u8 \
  whatpm-demo-files

cc-msg.en.txt: error-description-source.xml mkcatalog.pl
	$(PERL) mkcatalog.pl $< en > $@

cc-msg.ja.txt: error-description-source.xml mkcatalog.pl
	$(PERL) mkcatalog.pl $< ja > $@

error-description.en.html.u8: error-description-source.xml mkdescription.pl
	$(PERL) mkdescription.pl $< en > $@

error-description.ja.html.u8: error-description-source.xml mkdescription.pl
	$(PERL) mkdescription.pl $< ja > $@

whatpm-demo-files:
	cp modules/manakai/doc/demo/*.cgi ./
	cp modules/manakai/doc/demo/*.js ./
	cp modules/manakai/doc/demo/*.html ./

create-commit-for-heroku:
	git remote rm origin
	rm -fr deps/pmtar/.git deps/pmpp/.git modules/*/.git
	git add -f deps/pmtar/* #deps/pmpp/*
	#rm -fr ./t_deps/modules
	#git rm -r t_deps/modules
	git rm .gitmodules
	git rm modules/* --cached
	git add -f modules/*/*
	git commit -m "for heroku"

## ------ Tests ------

PROVE = ./prove

test: test-deps test-main

test-deps: deps

test-main:
	$(PROVE) t/*.pm

always:

## License: Public Domain.
