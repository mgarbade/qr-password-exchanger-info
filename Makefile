# Install the qpe desktop CLI.
#
#   make install                         # per-user, into ~/.local (no sudo)
#   sudo make install PREFIX=/usr/local  # system-wide
#   make link                            # symlink to this checkout (development)
#   make uninstall

PREFIX ?= $(HOME)/.local
DESTDIR ?=
BINDIR := $(DESTDIR)$(PREFIX)/bin
LIBEXECDIR := $(DESTDIR)$(PREFIX)/libexec/qpe
COMPLETIONDIR := $(DESTDIR)$(PREFIX)/share/bash-completion/completions

SUBCOMMANDS := key send receive contacts

.PHONY: install link uninstall check

install:
	install -d "$(BINDIR)" "$(LIBEXECDIR)" "$(COMPLETIONDIR)"
	install -m 755 desktop/bin/qpe "$(BINDIR)/qpe"
	for c in $(SUBCOMMANDS); do \
		install -m 755 "desktop/libexec/qpe/qpe-$$c" "$(LIBEXECDIR)/qpe-$$c"; \
	done
	install -m 644 desktop/completion/qpe.bash "$(COMPLETIONDIR)/qpe"
	@echo "Installed qpe to $(BINDIR)/qpe"

link:
	install -d "$(BINDIR)" "$(COMPLETIONDIR)"
	ln -sfn "$(CURDIR)/desktop/bin/qpe" "$(BINDIR)/qpe"
	ln -sfn "$(CURDIR)/desktop/completion/qpe.bash" "$(COMPLETIONDIR)/qpe"
	@echo "Linked $(BINDIR)/qpe -> $(CURDIR)/desktop/bin/qpe"

uninstall:
	rm -f "$(BINDIR)/qpe" "$(COMPLETIONDIR)/qpe"
	for c in $(SUBCOMMANDS); do rm -f "$(LIBEXECDIR)/qpe-$$c"; done
	-rmdir "$(LIBEXECDIR)" 2>/dev/null

check:
	bash -n desktop/bin/qpe desktop/completion/qpe.bash
	for c in $(SUBCOMMANDS); do bash -n "desktop/libexec/qpe/qpe-$$c"; done
	command -v shellcheck >/dev/null && shellcheck desktop/bin/qpe desktop/libexec/qpe/qpe-* || true
