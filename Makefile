URL = git@github.com:jcrd/awesome-launch

rock:
	luarocks make --local rockspec/awesome-launch-devel-1.rockspec

gh-pages:
	git clone -b gh-pages --single-branch $(URL) gh-pages

ldoc: gh-pages
	ldoc . -d gh-pages

.PHONY: rock ldoc
