PACKAGE = openntpd
ORG = amylum

DEP_DIR = /tmp/deps

BUILD_DIR = /tmp/$(PACKAGE)-build
RELEASE_DIR = /tmp/$(PACKAGE)-release
RELEASE_FILE = /tmp/$(PACKAGE).tar.gz

PACKAGE_VERSION = 5.7p4
PATCH_VERSION = $$(cat version)
VERSION = $(PACKAGE_VERSION)-$(PATCH_VERSION)

SOURCE_URL = http://ftp.openbsd.org/pub/OpenBSD/OpenNTPD/$(PACKAGE)-$(PACKAGE_VERSION).tar.gz
SOURCE_PATH = /tmp/source
SOURCE_TARBALL = /tmp/source.tar.gz

PATH_FLAGS = --bindir=/usr/bin --mandir=/usr/share/man --sysconfdir=/etc
CONF_FLAGS = --with-privsep-user=ntp --with-privsep-path=/run/openntpd/
CFLAGS = -static -static-libgcc -Wl,-static -lc -I$(DEP_DIR)/include

.PHONY : default source manual container build version push local

default: container

source:
	rm -rf $(SOURCE_PATH) $(SOURCE_TARBALL)
	mkdir $(SOURCE_PATH)
	curl -sLo $(SOURCE_TARBALL) $(SOURCE_URL)
	tar -x -C $(SOURCE_PATH) -f $(SOURCE_TARBALL) --strip-components=1

manual:
	./meta/launch /bin/bash || true

container:
	./meta/launch

build: source
	rm -rf $(BUILD_DIR) $(DEP_DIR)
	cp -R $(SOURCE_PATH) $(BUILD_DIR)
	mkdir -p $(DEP_DIR)/include
	cp -R /usr/include/{linux,asm,asm-generic} $(DEP_DIR)/include/
	cd $(BUILD_DIR) && CC=musl-gcc CFLAGS='$(CFLAGS)' ./configure $(PATH_FLAGS) $(CONF_FLAGS)
	cd $(BUILD_DIR) && make DESTDIR=$(RELEASE_DIR) install
	rm -rf $(RELEASE_DIR)/var
	mkdir -p $(RELEASE_DIR)/usr/share/licenses/$(PACKAGE)
	cp $(BUILD_DIR)/COPYING $(RELEASE_DIR)/usr/share/licenses/$(PACKAGE)/LICENSE
	cd $(RELEASE_DIR) && tar -czvf $(RELEASE_FILE) *

version:
	@echo $$(($(PATCH_VERSION) + 1)) > version

push: version
	git commit -am "$(VERSION)"
	ssh -oStrictHostKeyChecking=no git@github.com &>/dev/null || true
	git tag -f "$(VERSION)"
	git push --tags origin master
	targit -a .github -c -f $(ORG)/$(PACKAGE) $(VERSION) $(RELEASE_FILE)
	@sha512sum $(RELEASE_FILE) | cut -d' ' -f1

local: build push

