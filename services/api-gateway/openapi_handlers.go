package main

import (
    "net/http"
)

func (s *Server) handleOpenAPIPublic() http.HandlerFunc {
    return func(w http.ResponseWriter, _ *http.Request) {
        w.Header().Set("Content-Type", "application/yaml; charset=utf-8")
        w.WriteHeader(http.StatusOK)
        _, _ = w.Write(openAPIPublicYAML)
    }
}

func (s *Server) handleOpenAPIPrivate() http.HandlerFunc {
    return func(w http.ResponseWriter, _ *http.Request) {
        w.Header().Set("Content-Type", "application/yaml; charset=utf-8")
        w.WriteHeader(http.StatusOK)
        _, _ = w.Write(openAPIPrivateYAML)
    }
}
