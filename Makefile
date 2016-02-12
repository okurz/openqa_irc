.PHONY: all
all:

.PHONY: test
test:
	prove -r

.PHONY: coverage
coverage:
	cover -test -report html
