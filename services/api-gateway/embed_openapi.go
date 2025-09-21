package main

import _ "embed"

//go:embed openapi/public-api.yaml
var openAPIPublicYAML []byte

//go:embed openapi/private-api.yaml
var openAPIPrivateYAML []byte
