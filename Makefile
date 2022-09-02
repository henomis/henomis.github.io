
build-home:
	docker run --user 1000:1000 --rm -it -v ${PWD}/home/:/src -v ${PWD}/output:/output peaceiris/hugo -d /output

serve-home:
	docker run --user 1000:1000 --rm -it -v ${PWD}/home/:/src -p 1313:1313 klakegg/hugo:0.92.1 server

build-blog:
	docker run --user 1000:1000 --rm -it -v ${PWD}/blog/:/src -v ${PWD}/output:/output peaceiris/hugo -d /output/blog

serve-blog:
	docker run --user 1000:1000 --rm -it -v ${PWD}/blog/:/src -p 1313:1313 klakegg/hugo:latest server
