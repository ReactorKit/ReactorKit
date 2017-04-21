VERSION=`git describe --tags --abbrev=0`

clean:
	rm -rf sourcekitten-output.json build docs/latest tmp-reactorkit

doc:
	swift build
	sourcekitten doc --spm-module ReactorKit > sourcekitten-output.json
	bundle exec jazzy \
		--clean \
		--sourcekitten-sourcefile sourcekitten-output.json \
		--exclude Sources/AssociatedObjectStore.swift \
		--output docs/latest \
		--min-acl public \
		--author "Suyeol Jeon" \
		--author_url https://xoul.kr \
		--github_url https://github.com/ReactorKit/ReactorKit \
		--module ReactorKit \
		--root-url http://reactorkit.io/docs

publish: doc
	git clone https://github.com/ReactorKit/ReactorKit -b gh-pages tmp-reactorkit
	rm -rf tmp-reactorkit/docs/latest
	mkdir -p tmp-reactorkit/docs
	cp -r docs/latest tmp-reactorkit/docs/latest
	cd tmp-reactorkit && \
		git add docs/latest && \
		git commit -am "Generate documentation"  && \
		git push origin gh-pages
	rm -rf tmp-reactorkit
