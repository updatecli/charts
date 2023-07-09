
.PHONY: lint
lint:
	helm lint ./charts/udash

.PHONY: template
template:
	helm template udash ./charts/udash
