
.PHONY: lint
lint:
	helm lint ./charts/udash
	helm lint ./charts/udash-agent

.PHONY: template
template:
	helm template udash ./charts/udash
	helm template udash ./charts/udash-agent
