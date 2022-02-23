build:
	docker run --user 1000:1000 --rm -it -v ${PWD}/home/:/src peaceiris/hugo

serve:
	docker run --user 1000:1000 --rm -it -v ${PWD}/home/:/src -p 1313:1313 klakegg/hugo:0.92.1 server

build-certs:
	mkdir -p ${PWD}/certs/etc/letsencrypt
	mkdir -p ${PWD}/certs/var/lib/letsencrypt
	mkdir -p ${PWD}/certs/var/log/letsencrypt
	docker run --user 1000:1000 -it --rm --name certbot \
            -v ${PWD}/certs/etc/letsencrypt:/etc/letsencrypt:rw \
            -v ${PWD}/certs/var/lib/letsencrypt:/var/lib/letsencrypt:rw \
			-v ${PWD}/certs/var/log/letsencrypt:/var/log/letsencrypt:rw \
            certbot/certbot certonly --manual --agree-tos --preferred-challenges dns  -d *.simonevellei.link -d simonevellei.link

clean-certs:
	rm -fr ${PWD}/certs

clean:
	rm -fr ./home/public
