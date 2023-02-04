dev:
	docker build --load -f Dockerfile -t shiharuharu/smokeping:latest .

build:
	docker buildx build --no-cache --progress=plain --platform linux/amd64,linux/arm64,linux/armhf -f Dockerfile --push -t shiharuharu/smokeping:latest .