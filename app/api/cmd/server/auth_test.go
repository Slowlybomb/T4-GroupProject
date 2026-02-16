package main

import (
	"testing"
	"time"
)

func TestExtractBearerToken(t *testing.T) {
	tests := []struct {
		name   string
		header string
		want   string
		ok     bool
	}{
		{name: "valid token", header: "Bearer abc.def.ghi", want: "abc.def.ghi", ok: true},
		{name: "valid token lowercase prefix", header: "bearer token123", want: "token123", ok: true},
		{name: "missing prefix", header: "Token abc", want: "", ok: false},
		{name: "empty token", header: "Bearer   ", want: "", ok: false},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got, ok := extractBearerToken(tt.header)
			if ok != tt.ok {
				t.Fatalf("expected ok=%v, got %v", tt.ok, ok)
			}
			if got != tt.want {
				t.Fatalf("expected token=%q, got %q", tt.want, got)
			}
		})
	}
}

func TestParseActivityID(t *testing.T) {
	if _, ok := parseActivityID("aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"); !ok {
		t.Fatal("expected valid uuid to pass")
	}

	if got, ok := parseActivityID("AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA"); !ok || got != "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa" {
		t.Fatalf("expected uppercase UUID to normalize, got %q ok=%v", got, ok)
	}

	if _, ok := parseActivityID("bad-id"); ok {
		t.Fatal("expected invalid id to fail")
	}
}

func TestValidateClaims(t *testing.T) {
	now := time.Unix(1700000000, 0).UTC()
	cfg := authConfig{
		Audience: "authenticated",
		Issuer:   "https://example.supabase.co/auth/v1",
	}

	validClaims := map[string]any{
		"exp": float64(now.Add(5 * time.Minute).Unix()),
		"nbf": float64(now.Add(-1 * time.Minute).Unix()),
		"iat": float64(now.Add(-1 * time.Minute).Unix()),
		"iss": cfg.Issuer,
		"aud": "authenticated",
	}
	if err := validateClaims(validClaims, cfg, now); err != nil {
		t.Fatalf("expected valid claims, got error: %v", err)
	}

	expiredClaims := map[string]any{
		"exp": float64(now.Add(-1 * time.Minute).Unix()),
		"iss": cfg.Issuer,
		"aud": "authenticated",
	}
	if err := validateClaims(expiredClaims, cfg, now); err == nil {
		t.Fatal("expected expired claims to fail")
	}

	wrongAudClaims := map[string]any{
		"exp": float64(now.Add(5 * time.Minute).Unix()),
		"iss": cfg.Issuer,
		"aud": "anon",
	}
	if err := validateClaims(wrongAudClaims, cfg, now); err == nil {
		t.Fatal("expected wrong audience to fail")
	}

	wrongIssuerClaims := map[string]any{
		"exp": float64(now.Add(5 * time.Minute).Unix()),
		"iss": "https://other.example/auth/v1",
		"aud": "authenticated",
	}
	if err := validateClaims(wrongIssuerClaims, cfg, now); err == nil {
		t.Fatal("expected wrong issuer to fail")
	}
}
