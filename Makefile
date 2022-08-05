
build-home:
	docker run --user 1000:1000 --rm -it -v ${PWD}/home/:/src -v ${PWD}/output:/output peaceiris/hugo -d /output

serve-home:
	docker run --user 1000:1000 --rm -it -v ${PWD}/home/:/src -p 1313:1313 klakegg/hugo:0.92.1 server

build-blog:
	docker run --user 1000:1000 --rm -it -v ${PWD}/blog/:/src -v ${PWD}/output:/output peaceiris/hugo -d /output/blog

serve-blog:
	docker run --user 1000:1000 --rm -it -v ${PWD}/blog/:/src -p 1313:1313 klakegg/hugo:latest server

build-certs:
	mkdir -p ${PWD}/certs/etc/letsencrypt
	mkdir -p ${PWD}/certs/var/lib/letsencrypt
	mkdir -p ${PWD}/certs/var/log/letsencrypt
	docker run --user 1000:1000 -it --rm --name certbot \
            -v ${PWD}/certs/etc/letsencrypt:/etc/letsencrypt:rw \
            -v ${PWD}/certs/var/lib/letsencrypt:/var/lib/letsencrypt:rw \
			-v ${PWD}/certs/var/log/letsencrypt:/var/log/letsencrypt:rw \
            certbot/certbot certonly --manual --agree-tos --preferred-challenges dns  -d *.simonevellei.com -d simonevellei.com

clean-certs:
	rm -fr ${PWD}/certs

clean:
	rm -fr ./home/public
