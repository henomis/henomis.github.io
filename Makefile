
build:
	cd root && ../hugo-0.145.0 -d ../output

serve:
	cd root && ../hugo-0.145.0 serve --disableFastRender -e production root/
