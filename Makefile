NAME := Feather
PLATFORM := iphoneos
SCHEMES := Feather
TMP := $(TMPDIR)/$(NAME)
STAGE := $(TMP)/stage
# Build configuration: Release (default) or Debug when overridden
CONFIG ?= Release
# Derived path for the app based on configuration
APP := $(TMP)/Build/Products/$(CONFIG)-$(PLATFORM)

.PHONY: all clean $(SCHEMES) debug

all: $(SCHEMES)

clean:
	rm -rf $(TMP)
	rm -rf packages
	rm -rf Payload

deps:
	rm -rf deps || true
	mkdir -p deps
	curl -L -o deps/server.crt https://backloop.dev/backloop.dev-cert.crt || true
	curl -L -o deps/server.key1 https://backloop.dev/backloop.dev-key.part1.pem || true
	curl -L -o deps/server.key2 https://backloop.dev/backloop.dev-key.part2.pem || true
	cat deps/server.key1 deps/server.key2 > deps/server.pem 2>/dev/null || true
	rm -f deps/server.key1 deps/server.key2
	echo "*.backloop.dev" > deps/commonName.txt

$(SCHEMES): deps
	xcodebuild \
	    -project Feather.xcodeproj \
	    -scheme "$@" \
	    -configuration $(CONFIG) \
	    -arch arm64 \
	    -sdk $(PLATFORM) \
	    -derivedDataPath $(TMP) \
	    -skipPackagePluginValidation \
	    CODE_SIGNING_ALLOWED=NO \
	    ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES=NO

	rm -rf Payload
	rm -rf $(STAGE)/
	mkdir -p $(STAGE)/Payload

	mv "$(APP)/$@.app" "$(STAGE)/Payload/$@.app"

	chmod -R 0755 "$(STAGE)/Payload/$@.app"
	codesign --force --sign - --timestamp=none "$(STAGE)/Payload/$@.app"

	cp deps/* "$(STAGE)/Payload/$@.app/" || true

	rm -rf "$(STAGE)/Payload/$@.app/_CodeSignature"
	ln -sf "$(STAGE)/Payload" Payload
	
	mkdir -p packages
	zip -r9 "packages/$@.ipa" Payload

# Convenience target to build using Debug configuration
debug:
	$(MAKE) CONFIG=Debug $(SCHEMES)
