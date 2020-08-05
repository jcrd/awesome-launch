URL = git@github.com:jcrd/awesome-launch

rock:
	luarocks make --local rockspec/awesome-launch-devel-1.rockspec

gh-pages:
	git clone -b gh-pages --single-branch $(URL) gh-pages

ldoc: gh-pages
	ldoc . -d gh-pages

serve: gh-pages
	python -m http.server --directory gh-pages

.PHONY: rock ldoc serve
