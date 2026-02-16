package main

import (
	"context"
	"crypto"
	"crypto/rsa"
	"crypto/sha256"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"log"
	"math/big"
	"net/http"
	"os"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/gin-gonic/gin"
)

type Activity struct {
	ID        int       `json:"id"`
	User      string    `json:"user" binding:"required,min=2"`
	Title     string    `json:"title" binding:"required,min=3"`
	Type      string    `json:"type" binding:"required,oneof=run walk gym cycle"`
	Minutes   int       `json:"minutes" binding:"required,gte=1,lte=600"`
	Likes     int       `json:"likes"`
	CreatedAt time.Time `json:"created_at"`
}

// Keep request payload separate so clients cannot set server-managed fields (id, user, likes, created_at).
type CreateActivityRequest struct {
	Title   string `json:"title" binding:"required,min=3"`
	Type    string `json:"type" binding:"required,oneof=run walk gym cycle"`
	Minutes int    `json:"minutes" binding:"required,gte=1,lte=600"`
}

// authConfig holds necessary info to verify JWTs against Supabase's JWKS endpoint.
type authConfig struct {
	JWKSURL   string
	Audience  string
	Issuer    string
	HTTPDelay time.Duration
}

func main() {
	r := gin.New()
	r.Use(gin.Recovery())
	r.Use(requestLogger())

	authMiddleware, err := newAuthMiddlewareFromEnv()
	if err != nil {
		log.Fatalf("auth middleware setup failed: %v", err)
	}

	store := newActivityStore()

	api := r.Group("/api/v1")
	{
		// Health stays public so uptime checks do not need a JWT.
		api.GET("/health", func(c *gin.Context) {
			c.JSON(http.StatusOK, gin.H{
				"status": "ok",
				"time":   time.Now().UTC().Format(time.RFC3339),
			})
		})

		activities := api.Group("/activities")
		// Everything under /activities is protected by JWT middleware.
		activities.Use(authMiddleware)

		activities.GET("", func(c *gin.Context) {
			c.JSON(http.StatusOK, store.list())
		})

		activities.POST("", func(c *gin.Context) {
			var req CreateActivityRequest
			if err := c.ShouldBindJSON(&req); err != nil {
				c.JSON(http.StatusBadRequest, gin.H{
					"error":   "invalid request body",
					"details": err.Error(),
				})
				return
			}

			userID, ok := authUserID(c)
			if !ok {
				c.JSON(http.StatusUnauthorized, gin.H{"error": "missing authenticated user"})
				return
			}

			a := store.create(userID, req.Title, req.Type, req.Minutes)
			c.JSON(http.StatusCreated, a)
		})

		activities.GET("/:id", func(c *gin.Context) {
			id, ok := parseID(c.Param("id"))
			if !ok {
				c.JSON(http.StatusBadRequest, gin.H{"error": "id must be an integer"})
				return
			}

			a, found := store.get(id)
			if !found {
				c.JSON(http.StatusNotFound, gin.H{"error": "activity not found"})
				return
			}

			c.JSON(http.StatusOK, a)
		})

		activities.PATCH("/:id/like", func(c *gin.Context) {
			id, ok := parseID(c.Param("id"))
			if !ok {
				c.JSON(http.StatusBadRequest, gin.H{"error": "id must be an integer"})
				return
			}

			a, found := store.like(id)
			if !found {
				c.JSON(http.StatusNotFound, gin.H{"error": "activity not found"})
				return
			}

			c.JSON(http.StatusOK, a)
		})
	}

	if err := r.Run(":8080"); err != nil {
		log.Fatalf("server failed to start: %v", err)
	}
}

func newAuthMiddlewareFromEnv() (gin.HandlerFunc, error) {
	cfg, err := readAuthConfigFromEnv()
	if err != nil {
		return nil, err
	}

	jwks := newJWKSProvider(cfg.JWKSURL, cfg.HTTPDelay)
	if err := jwks.refresh(context.Background()); err != nil {
		return nil, fmt.Errorf("initial jwks fetch failed: %w", err)
	}

	return func(c *gin.Context) {
		// 1) Read Bearer token from Authorization header.
		token, ok := extractBearerToken(c.GetHeader("Authorization"))
		if !ok {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "missing bearer token"})
			return
		}

		// 2) Verify signature + claims against Supabase JWKS.
		claims, err := verifyJWT(token, cfg, jwks.lookupKey)
		if err != nil {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "invalid token"})
			return
		}

		sub, _ := claims["sub"].(string)
		if strings.TrimSpace(sub) == "" {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "token missing subject"})
			return
		}

		// Make user data available to handlers through Gin context.
		c.Set("auth.user_id", sub)
		c.Set("auth.claims", claims)
		c.Next()
	}, nil
}

func readAuthConfigFromEnv() (authConfig, error) {
	cfg := authConfig{
		JWKSURL:   strings.TrimSpace(os.Getenv("SUPABASE_JWKS_URL")),
		Audience:  strings.TrimSpace(os.Getenv("JWT_AUDIENCE")),
		HTTPDelay: 5 * time.Second,
	}

	if cfg.JWKSURL == "" {
		return authConfig{}, errors.New("SUPABASE_JWKS_URL is required")
	}
	if cfg.Audience == "" {
		cfg.Audience = "authenticated"
	}

	if issuer := strings.TrimSpace(os.Getenv("JWT_ISSUER")); issuer != "" {
		cfg.Issuer = issuer
	} else if supabaseURL := strings.TrimSuffix(strings.TrimSpace(os.Getenv("SUPABASE_URL")), "/"); supabaseURL != "" {
		cfg.Issuer = supabaseURL + "/auth/v1"
	}

	return cfg, nil
}

type jwksProvider struct {
	url    string
	client *http.Client

	mu   sync.RWMutex
	keys map[string]*rsa.PublicKey
}

type jwkSet struct {
	Keys []jwkKey `json:"keys"`
}

type jwkKey struct {
	Kid string `json:"kid"`
	Kty string `json:"kty"`
	N   string `json:"n"`
	E   string `json:"e"`
}

func newJWKSProvider(url string, timeout time.Duration) *jwksProvider {
	if timeout <= 0 {
		timeout = 5 * time.Second
	}

	return &jwksProvider{
		url:    url,
		client: &http.Client{Timeout: timeout},
		keys:   make(map[string]*rsa.PublicKey),
	}
}

func (p *jwksProvider) lookupKey(kid string) (*rsa.PublicKey, error) {
	p.mu.RLock()
	key, ok := p.keys[kid]
	p.mu.RUnlock()
	if ok {
		return key, nil
	}

	if err := p.refresh(context.Background()); err != nil {
		return nil, err
	}

	p.mu.RLock()
	key, ok = p.keys[kid]
	p.mu.RUnlock()
	if !ok {
		return nil, fmt.Errorf("kid %q not found in jwks", kid)
	}
	return key, nil
}

func (p *jwksProvider) refresh(ctx context.Context) error {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, p.url, nil)
	if err != nil {
		return err
	}

	resp, err := p.client.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("jwks endpoint returned status %d", resp.StatusCode)
	}

	var set jwkSet
	if err := json.NewDecoder(resp.Body).Decode(&set); err != nil {
		return fmt.Errorf("decode jwks: %w", err)
	}

	keys := make(map[string]*rsa.PublicKey, len(set.Keys))
	for _, k := range set.Keys {
		if k.Kty != "RSA" || k.Kid == "" {
			continue
		}

		pub, err := parseRSAPublicKey(k.N, k.E)
		if err != nil {
			return fmt.Errorf("parse key %q: %w", k.Kid, err)
		}
		keys[k.Kid] = pub
	}

	if len(keys) == 0 {
		return errors.New("jwks returned no RSA keys")
	}

	p.mu.Lock()
	p.keys = keys
	p.mu.Unlock()
	return nil
}

func parseRSAPublicKey(nRaw, eRaw string) (*rsa.PublicKey, error) {
	modulusBytes, err := base64.RawURLEncoding.DecodeString(nRaw)
	if err != nil {
		return nil, fmt.Errorf("decode modulus: %w", err)
	}
	if len(modulusBytes) == 0 {
		return nil, errors.New("empty modulus")
	}

	exponentBytes, err := base64.RawURLEncoding.DecodeString(eRaw)
	if err != nil {
		return nil, fmt.Errorf("decode exponent: %w", err)
	}
	if len(exponentBytes) == 0 {
		return nil, errors.New("empty exponent")
	}

	exponent := int(new(big.Int).SetBytes(exponentBytes).Int64())
	if exponent < 3 {
		return nil, errors.New("invalid exponent")
	}

	return &rsa.PublicKey{
		N: new(big.Int).SetBytes(modulusBytes),
		E: exponent,
	}, nil
}

type jwtHeader struct {
	Alg string `json:"alg"`
	Kid string `json:"kid"`
	Typ string `json:"typ"`
}

func verifyJWT(
	token string,
	cfg authConfig,
	keyLookup func(kid string) (*rsa.PublicKey, error),
) (map[string]any, error) {
	// JWT format is: header.payload.signature
	parts := strings.Split(token, ".")
	if len(parts) != 3 {
		return nil, errors.New("token must have 3 parts")
	}

	headerBytes, err := base64.RawURLEncoding.DecodeString(parts[0])
	if err != nil {
		return nil, fmt.Errorf("decode header: %w", err)
	}

	var header jwtHeader
	if err := json.Unmarshal(headerBytes, &header); err != nil {
		return nil, fmt.Errorf("parse header: %w", err)
	}
	if header.Alg != "RS256" {
		return nil, errors.New("unsupported jwt algorithm")
	}
	if header.Kid == "" {
		return nil, errors.New("missing kid")
	}

	signature, err := base64.RawURLEncoding.DecodeString(parts[2])
	if err != nil {
		return nil, fmt.Errorf("decode signature: %w", err)
	}

	key, err := keyLookup(header.Kid)
	if err != nil {
		return nil, fmt.Errorf("lookup key: %w", err)
	}

	digest := sha256.Sum256([]byte(parts[0] + "." + parts[1]))
	if err := rsa.VerifyPKCS1v15(key, crypto.SHA256, digest[:], signature); err != nil {
		return nil, errors.New("invalid signature")
	}

	claimsBytes, err := base64.RawURLEncoding.DecodeString(parts[1])
	if err != nil {
		return nil, fmt.Errorf("decode claims: %w", err)
	}

	var claims map[string]any
	if err := json.Unmarshal(claimsBytes, &claims); err != nil {
		return nil, fmt.Errorf("parse claims: %w", err)
	}

	if err := validateClaims(claims, cfg, time.Now().UTC()); err != nil {
		return nil, err
	}

	return claims, nil
}

func validateClaims(claims map[string]any, cfg authConfig, now time.Time) error {
	nowUnix := now.Unix()
	const leewaySeconds int64 = 30

	// exp is mandatory: if token is expired, reject.
	exp, ok := numericClaim(claims["exp"])
	if !ok {
		return errors.New("missing exp")
	}
	if nowUnix > exp+leewaySeconds {
		return errors.New("token expired")
	}

	if nbf, ok := numericClaim(claims["nbf"]); ok && nowUnix+leewaySeconds < nbf {
		return errors.New("token not active yet")
	}

	if iat, ok := numericClaim(claims["iat"]); ok && iat > nowUnix+leewaySeconds {
		return errors.New("token issued in the future")
	}

	if cfg.Issuer != "" {
		iss, _ := claims["iss"].(string)
		if iss != cfg.Issuer {
			return errors.New("unexpected issuer")
		}
	}

	if cfg.Audience != "" && !audienceContains(claims["aud"], cfg.Audience) {
		return errors.New("audience mismatch")
	}

	return nil
}

func numericClaim(v any) (int64, bool) {
	switch n := v.(type) {
	case float64:
		return int64(n), true
	case float32:
		return int64(n), true
	case int:
		return int64(n), true
	case int64:
		return n, true
	case json.Number:
		val, err := n.Int64()
		if err != nil {
			return 0, false
		}
		return val, true
	case string:
		val, err := strconv.ParseInt(n, 10, 64)
		if err != nil {
			return 0, false
		}
		return val, true
	default:
		return 0, false
	}
}

func audienceContains(raw any, expected string) bool {
	switch aud := raw.(type) {
	case string:
		return aud == expected
	case []any:
		for _, item := range aud {
			s, ok := item.(string)
			if ok && s == expected {
				return true
			}
		}
		return false
	case []string:
		for _, item := range aud {
			if item == expected {
				return true
			}
		}
		return false
	default:
		return false
	}
}

func extractBearerToken(header string) (string, bool) {
	if len(header) < len("Bearer ") {
		return "", false
	}
	if !strings.EqualFold(header[:len("Bearer ")], "Bearer ") {
		return "", false
	}

	token := strings.TrimSpace(header[len("Bearer "):])
	if token == "" {
		return "", false
	}

	return token, true
}

func parseID(raw string) (int, bool) {
	id, err := strconv.Atoi(raw)
	if err != nil || id <= 0 {
		return 0, false
	}
	return id, true
}

func authUserID(c *gin.Context) (string, bool) {
	raw, ok := c.Get("auth.user_id")
	if !ok {
		return "", false
	}

	userID, ok := raw.(string)
	if !ok {
		return "", false
	}

	userID = strings.TrimSpace(userID)
	if userID == "" {
		return "", false
	}

	return userID, true
}

func requestLogger() gin.HandlerFunc {
	return func(c *gin.Context) {
		start := time.Now()
		c.Next()
		latency := time.Since(start)

		// Quick visibility for debugging response times.
		c.Writer.Header().Set("X-Request-Duration", latency.String())
	}
}

/*
	In-memory store.
	Not thread-safe.
	For a prototype it's fine.
	For production, you'd use a DB + proper concurrency control.
*/

type activityStore struct {
	nextID     int
	activities map[int]Activity
	order      []int
}

func newActivityStore() *activityStore {
	s := &activityStore{
		nextID:     1,
		activities: make(map[int]Activity),
		order:      make([]int, 0, 64),
	}

	// Seed a couple of examples so your API isn't empty on boot.
	s.create("hleb", "Evening run", "run", 35)
	s.create("alex", "Leg day", "gym", 55)

	return s
}

func (s *activityStore) create(user, title, typ string, minutes int) Activity {
	a := Activity{
		ID:        s.nextID,
		User:      user,
		Title:     title,
		Type:      typ,
		Minutes:   minutes,
		Likes:     0,
		CreatedAt: time.Now().UTC(),
	}
	s.activities[a.ID] = a
	s.order = append(s.order, a.ID)
	s.nextID++
	return a
}

func (s *activityStore) list() []Activity {
	out := make([]Activity, 0, len(s.order))
	for _, id := range s.order {
		out = append(out, s.activities[id])
	}
	return out
}

func (s *activityStore) get(id int) (Activity, bool) {
	a, ok := s.activities[id]
	return a, ok
}

func (s *activityStore) like(id int) (Activity, bool) {
	a, ok := s.activities[id]
	if !ok {
		return Activity{}, false
	}
	a.Likes++
	s.activities[id] = a
	return a, true
}
