# ========= Resolve the intended user, home, and group (works with/without sudo) =========
SUDO_USER         ?=
EFFECTIVE_USER     := $(if $(SUDO_USER),$(SUDO_USER),$(shell id -un))
EFFECTIVE_HOME     := $(shell eval echo ~$(EFFECTIVE_USER))
EFFECTIVE_GROUP    := $(shell id -gn $(EFFECTIVE_USER))

# ========= User template (your exact file name) =========
TEMPLATE_SRC       ?= template_thunderbird_task.rtf.in.rtf
USER_TEMPLATE_DIR  ?= $(EFFECTIVE_HOME)/.config/templates/copyq
USER_TEMPLATE_DEST := $(USER_TEMPLATE_DIR)/$(TEMPLATE_SRC)

# ========= System script install + symlink =========
BIN_NAME           ?= paste_thunderbird_template_task
OPTDIR             ?= /opt/$(BIN_NAME)
SYSTEM_BIN         ?= $(OPTDIR)/$(BIN_NAME)
LINK_DIR           ?= /usr/local/bin
LINK_PATH          ?= $(LINK_DIR)/$(BIN_NAME)

# ========= Tools =========
INSTALL            ?= install
MKDIR_P            ?= $(INSTALL) -d
LN                 ?= ln
CHOWN              ?= chown
RM                 ?= rm -f
RMDIR              ?= rmdir

# ========= Phony =========
.PHONY: all install install-user install-system uninstall uninstall-user uninstall-system list check

all:
	@echo "Targets:"
	@echo "  make install-user          # user template (NO sudo needed)"
	@echo "  sudo make install-system   # script + symlink (root-owned)"

# ========= INSTALL =========
# Tip: run as two commands to avoid mixing privileges:
#   make install-user
#   sudo make install-system
install: install-user install-system

# --- USER INSTALL (always into EFFECTIVE_USER's HOME, owned by EFFECTIVE_USER) ---
install-user: guard-not-root-only $(USER_TEMPLATE_DEST)
	@echo "✔ User template installed at: $(USER_TEMPLATE_DEST) (owner: $(EFFECTIVE_USER):$(EFFECTIVE_GROUP))"

$(USER_TEMPLATE_DEST): $(TEMPLATE_SRC)
	$(MKDIR_P) "$(USER_TEMPLATE_DIR)"
	# Copy the file
	$(INSTALL) -m 0644 "$(TEMPLATE_SRC)" "$(USER_TEMPLATE_DEST)"
	# Ensure ownership is the original user, even if invoked with sudo
	@if [ "$$(id -u)" -eq 0 ]; then \
		$(CHOWN) "$(EFFECTIVE_USER):$(EFFECTIVE_GROUP)" "$(USER_TEMPLATE_DEST)"; \
	fi

# Guard: if truly root without SUDO_USER, refuse to install to /root
.PHONY: guard-not-root-only
guard-not-root-only:
	@if [ "$$(id -u)" -eq 0 ] && [ -z "$(SUDO_USER)" ]; then \
		echo "ERROR: install-user is running as root without SUDO_USER."; \
		echo "       Please run 'make install-user' as your normal user (no sudo),"; \
		echo "       or use 'sudo -u <user> make install-user'."; \
		exit 1; \
	fi

# --- SYSTEM INSTALL (root-owned binary in /opt + symlink in /usr/local/bin) ---
install-system: $(SYSTEM_BIN) link-bin
	@echo "✔ System script installed at: $(SYSTEM_BIN)"
	@echo "✔ Symlink created at:         $(LINK_PATH)"

$(SYSTEM_BIN): $(BIN_NAME)
	$(MKDIR_P) "$(OPTDIR)"
	$(INSTALL) -m 0755 "$(BIN_NAME)" "$(SYSTEM_BIN)"
	@# lock it down as root-owned
	$(CHOWN) root:root "$(SYSTEM_BIN)"

.PHONY: link-bin
link-bin:
	$(MKDIR_P) "$(LINK_DIR)"
	$(LN) -sf "$(SYSTEM_BIN)" "$(LINK_PATH)"

# ========= UNINSTALL =========
uninstall: uninstall-user uninstall-system

uninstall-user:
	-$(RM) "$(USER_TEMPLATE_DEST)"
	-$(RMDIR) "$(USER_TEMPLATE_DIR)" 2>/dev/null || true
	-$(RMDIR) "$(dir $(USER_TEMPLATE_DIR))" 2>/dev/null || true
	@echo "✔ User template uninstalled (dirs kept if not empty)."

uninstall-system:
	-$(RM) "$(LINK_PATH)"
	-$(RM) "$(SYSTEM_BIN)"
	-$(RMDIR) "$(OPTDIR)" 2>/dev/null || true
	@echo "✔ System script & symlink uninstalled (dir kept if not empty)."

# ========= Helpers =========
list:
	@echo "Resolved user/home/group:"
	@echo "  EFFECTIVE_USER  = $(EFFECTIVE_USER)"
	@echo "  EFFECTIVE_HOME  = $(EFFECTIVE_HOME)"
	@echo "  EFFECTIVE_GROUP = $(EFFECTIVE_GROUP)"
	@echo "User template:"
	@echo "  SRC  = $(TEMPLATE_SRC)"
	@echo "  DEST = $(USER_TEMPLATE_DEST)"
	@echo "System script:"
	@echo "  OPTDIR     = $(OPTDIR)"
	@echo "  SYSTEM_BIN = $(SYSTEM_BIN)"
	@echo "  LINK_PATH  = $(LINK_PATH)"

check:
	@echo "Checking source files exist…"
	@test -f "$(TEMPLATE_SRC)" && echo "  ✔ $(TEMPLATE_SRC)" || { echo "  ✘ Missing: $(TEMPLATE_SRC)"; exit 1; }
	@test -f "$(BIN_NAME)"      && echo "  ✔ $(BIN_NAME)"      || { echo "  ✘ Missing: $(BIN_NAME)"; exit 1; }
	@echo "OK."

