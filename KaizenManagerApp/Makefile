APP_NAME=KaizenManager
BUNDLE_ID=br.com.kaizen.KaizenManager
BUILD_DIR=build
APP_BUNDLE=$(BUILD_DIR)/$(APP_NAME).app
CONTENTS_DIR=$(APP_BUNDLE)/Contents
MACOS_DIR=$(CONTENTS_DIR)/MacOS
RESOURCES_DIR=$(CONTENTS_DIR)/Resources
SWIFT_FILES=$(wildcard Sources/*.swift)

all: clean build_app

build_app:
	@echo "Creating App Bundle structure..."
	mkdir -p $(MACOS_DIR)
	mkdir -p $(RESOURCES_DIR)
	@echo "Copying Info.plist..."
	cp Info.plist $(CONTENTS_DIR)/
	@echo "Copying Icon..."
	cp MyIcon.icns $(RESOURCES_DIR)/AppIcon.icns
	cp MenuBarIcon.png $(RESOURCES_DIR)/MenuBarIcon.png
	@echo "Compiling Swift files..."
	swiftc -O $(SWIFT_FILES) -o $(MACOS_DIR)/$(APP_NAME)
	@echo "App Bundle created at $(APP_BUNDLE)"

clean:
	rm -rf $(BUILD_DIR)
