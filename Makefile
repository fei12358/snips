SHELL := /bin/bash

MODULE   = $(shell env GO111MODULE=on go list -m)
VERSION=$(shell cat constants/version.go | grep "Version\ =" | sed -e s/^.*\ //g | sed -e s/\"//g)

DIRS_WITHOUT_VENDOR=$(shell ls -d */ | grep -vE "vendor")
PKGS_WITHOUT_VENDOR=$(shell env GO111MODULE=on go list ./... | grep -v "/vendor/")
TESTPKGS = $(shell env GO111MODULE=on go list -f \
			'{{ if or .TestGoFiles .XTestGoFiles }}{{ .ImportPath }}{{ end }}' \
			$(PKGS_WITHOUT_VENDOR))

BIN      = $(CURDIR)/bin
RELEASE  = $(CURDIR)/release

export GO111MODULE=on

.PHONY: help
help:
	@echo "Please use \`make <target>\` where <target> is one of"
	@echo "  all           to check, build, test and release snips"
	@echo "  check         to vet and lint snips"
	@echo "  build         to create bin directory and build snips"
	@echo "  test          to run test"
	@echo "  test-coverage to test with coverage"
	@echo "  install       to install snips to ${GOPATH}/bin"
	@echo "  uninstall     to uninstall snips"
	@echo "  release       to build and release snips"
	@echo "  clean         to clean build and test files"

.PHONY: all
all: check build release clean

.PHONY: check
check: fmt vet lint

.PHONY: fmt
fmt:
	@echo "Running go tool fmt, on snips packages"
	@go fmt ${PKGS_WITHOUT_VENDOR}
	@echo "Done"

.PHONY: vet
vet:
	@echo "Running go tool vet, on snips packages"
	@go vet ${PKGS_WITHOUT_VENDOR}
	@echo "Done"

.PHONY: lint
lint:
	@echo "Running golint, on snips packages"
	@lint=$$(for pkg in ${PKGS_WITHOUT_VENDOR}; do golint $${pkg}; done); \
	 if [[ -n $${lint} ]]; then echo "$${lint}"; exit 1; fi
	@echo "Done"

.PHONY: build
build:
	@echo "Building snips"
	go build -o $(BIN)/snips main.go
	@echo "Done"

.PHONY: test
test:
	@echo "Running test"
	go test -v ${PKGS_WITHOUT_VENDOR}
	@echo "Done"

.PHONY: test-coverage
test-coverage:
	@echo "Running test with coverage"
	for pkg in ${PKGS_WITHOUT_VENDOR}; do \
		output="coverage$${pkg#github.com/yunify/snips}"; \
		mkdir -p $${output}; \
		go test -v -cover -coverprofile="$${output}/profile.out" $${pkg}; \
		if [[ -e "$${output}/profile.out" ]]; then \
			go tool cover -html="$${output}/profile.out" -o "$${output}/profile.html"; \
		fi; \
	done
	@echo "Done"

.PHONY: install
install: build
	@if [[ -z "${GOPATH}" ]]; then echo "ERROR: $GOPATH not found."; exit 1; fi
	@echo "Installing into ${GOPATH}/bin/snips..."
	@cp $(BIN)/snips ${GOPATH}/bin/snips
	@echo "Done"

.PHONY: uninstall
uninstall:
	@if [[ -z "${GOPATH}" ]]; then echo "ERROR: $GOPATH not found."; exit 1; fi
	@echo "Uninstalling snips..."
	rm -f ${GOPATH}/bin/snips
	@echo "Done"

.PHONY: release
release:
	@echo "Release snips"
	mkdir -p ./release
	@echo "for Linux"
	mkdir -p ./bin/linux
	GOOS=linux GOARCH=amd64 go build -o ./bin/linux/snips .
	tar -C ./bin/linux/ -czf ./release/snips-v${VERSION}-linux_amd64.tar.gz snips
	@echo "for macOS"
	mkdir -p ./bin/darwin
	GOOS=darwin GOARCH=amd64 go build -o ./bin/darwin/snips .
	tar -C ./bin/darwin/ -czf ./release/snips-v${VERSION}-darwin_amd64.tar.gz snips
	@echo "for Windows"
	mkdir -p ./bin/windows
	GOOS=windows GOARCH=amd64 go build -o ./bin/windows/snips.exe .
	cd ./bin/windows/ && zip ../../release/snips-v${VERSION}-windows_amd64.zip snips.exe
	@echo "Done"

.PHONY: clean
clean:
	rm -rf ./bin
	rm -rf ./release
	rm -rf ./coverage
