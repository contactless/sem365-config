DESTDIR=/
prefix=etc

all:
	@echo "Nothing to do"

install:
#	install -D -m 0644 list.pkg $(DESTDIR)/$(prefix)/list.pkg

.PHONY: install clean all
