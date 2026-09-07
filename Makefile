HUGO ?= hugo
CONTENT_DIR ?= content/posts
DATE := $(shell powershell -NoProfile -Command "(Get-Date).ToString('yyyy-MM-dd')")

.DEFAULT_GOAL := help

.PHONY: help new preview preview-fast build minify clean

help:
	@echo "Available targets:"
	@echo "  make new TITLE=Article-Title  Create a new post"
	@echo "  make preview                  Preview the site with drafts"
	@echo "  make preview-fast             Preview with fast render enabled"
	@echo "  make build                    Build the site"
	@echo "  make minify                   Build the site with minification"
	@echo "  make clean                    Remove generated files"

new:
ifndef TITLE
	$(error TITLE is required, for example: make new TITLE=My-Article)
endif
	$(HUGO) new content "$(CONTENT_DIR)/$(DATE)-$(TITLE).md"

preview:
	$(HUGO) server -D --disableFastRender

preview-fast:
	$(HUGO) server -D

build:
	$(HUGO)

minify:
	$(HUGO) --minify

clean:
	@powershell -NoProfile -Command "Remove-Item -Recurse -Force -ErrorAction SilentlyContinue public, resources"
