package main

import (
	"context"
	"crypto"
	"crypto/rsa"
	"crypto/sha256"
	"database/sql"
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
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

type Activity struct {
	// This shape mirrors public.activities + derived counters (likes/comments).
	// Pointer fields represent nullable DB columns.
	ID                  string          `json:"id"`
	UserID              string          `json:"user_id"`
	Title               *string         `json:"title,omitempty"`
	Notes               *string         `json:"notes,omitempty"`
	StartTime           time.Time       `json:"start_time"`
	DurationSeconds     *int32          `json:"duration_seconds,omitempty"`
	DistanceM           *float64        `json:"distance_m,omitempty"`
	AvgSplit500MSeconds *int32          `json:"avg_split_500m_seconds,omitempty"`
	AvgStrokeSPM        *int16          `json:"avg_stroke_spm,omitempty"`
	Visibility          string          `json:"visibility"`
	TeamID              *string         `json:"team_id,omitempty"`
	RouteGeoJSON        json.RawMessage `json:"route_geojson,omitempty"`
	Likes               int             `json:"likes"`
	Comments            int             `json:"comments"`
	CreatedAt           time.Time       `json:"created_at"`
}

// Keep request payload separate so clients cannot set server-managed fields (id, user_id, likes, comments, created_at).
type CreateActivityRequest struct {
	// We accept nullable fields to match database columns and avoid inventing defaults in API code.
	Title               *string         `json:"title" binding:"omitempty,max=120"`
	Notes               *string         `json:"notes" binding:"omitempty,max=5000"`
	StartTime           time.Time       `json:"start_time" binding:"required"`
	DurationSeconds     *int32          `json:"duration_seconds" binding:"omitempty,gte=0"`
	DistanceM           *float64        `json:"distance_m" binding:"omitempty,gte=0"`
	AvgSplit500MSeconds *int32          `json:"avg_split_500m_seconds" binding:"omitempty,gte=0"`
	AvgStrokeSPM        *int16          `json:"avg_stroke_spm" binding:"omitempty,gte=0"`
	Visibility          string          `json:"visibility" binding:"required,oneof=private followers public team"`
	TeamID              *string         `json:"team_id" binding:"omitempty,uuid"`
	RouteGeoJSON        json.RawMessage `json:"route_geojson"`
}

// authConfig holds necessary info to verify JWTs against Supabase's JWKS endpoint.
type authConfig struct {
	JWKSURL   string
	Audience  string
	Issuer    string
	HTTPDelay time.Duration
}

type activityService interface {
	list(ctx context.Context, userID string) ([]Activity, error)
	create(ctx context.Context, userID string, req CreateActivityRequest) (Activity, error)
	get(ctx context.Context, userID, activityID string) (Activity, bool, error)
	like(ctx context.Context, userID, activityID string) (Activity, bool, error)
}

// main is the app entry point.
// It wires middleware, auth, storage, and routes, then starts the HTTP server.
func main() {
	r := gin.New()
	// Recovery avoids crashing the whole process if one request panics.
	r.Use(gin.Recovery())
	// Small custom logger that writes request duration as a response header.
	r.Use(requestLogger())

	authMiddleware, err := newAuthMiddlewareFromEnv()
	if err != nil {
		log.Fatalf("auth middleware setup failed: %v", err)
	}

	store, err := newActivityStoreFromEnv(context.Background())
	if err != nil {
		// Fail fast if DB is unavailable; activities endpoints depend on it.
		log.Fatalf("activity store setup failed: %v", err)
	}
	defer store.close()

	registerRoutes(r, authMiddleware, store)

	// Default port is 8080.
	if err := r.Run(":8080"); err != nil {
		log.Fatalf("server failed to start: %v", err)
	}
}

// registerRoutes groups all API endpoint wiring so tests can build a router
// with fake middleware/store implementations.
func registerRoutes(r *gin.Engine, authMiddleware gin.HandlerFunc, store activityService) {
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
			// user_id comes from JWT "sub" set by auth middleware.
			userID, ok := authUserID(c)
			if !ok {
				c.JSON(http.StatusUnauthorized, gin.H{"error": "missing authenticated user"})
				return
			}

			activities, err := store.list(c.Request.Context(), userID)
			if err != nil {
				log.Printf("list activities failed: %v", err)
				c.JSON(http.StatusInternalServerError, gin.H{"error": "internal server error"})
				return
			}

			c.JSON(http.StatusOK, activities)
		})

		activities.POST("", func(c *gin.Context) {
			// Bind + validate JSON according to tags on CreateActivityRequest.
			var req CreateActivityRequest
			if err := c.ShouldBindJSON(&req); err != nil {
				c.JSON(http.StatusBadRequest, gin.H{
					"error":   "invalid request body",
					"details": err.Error(),
				})
				return
			}

			if req.TeamID != nil {
				// Normalize team_id to avoid accepting whitespace-only values.
				trimmedTeamID := strings.TrimSpace(*req.TeamID)
				if trimmedTeamID == "" {
					req.TeamID = nil
				} else {
					req.TeamID = &trimmedTeamID
				}
			}

			if req.Visibility == "team" && req.TeamID == nil {
				c.JSON(http.StatusBadRequest, gin.H{"error": "team_id is required when visibility is team"})
				return
			}
			// Keep request semantics aligned with DB constraint:
			// team_id must be present only for team visibility.
			if req.Visibility != "team" && req.TeamID != nil {
				c.JSON(http.StatusBadRequest, gin.H{"error": "team_id is only allowed when visibility is team"})
				return
			}

			if len(req.RouteGeoJSON) > 0 && !json.Valid(req.RouteGeoJSON) {
				c.JSON(http.StatusBadRequest, gin.H{"error": "route_geojson must be valid JSON"})
				return
			}

			userID, ok := authUserID(c)
			if !ok {
				c.JSON(http.StatusUnauthorized, gin.H{"error": "missing authenticated user"})
				return
			}

			a, err := store.create(c.Request.Context(), userID, req)
			if err != nil {
				log.Printf("create activity failed: %v", err)
				c.JSON(http.StatusInternalServerError, gin.H{"error": "internal server error"})
				return
			}

			c.JSON(http.StatusCreated, a)
		})

		activities.GET("/:id", func(c *gin.Context) {
			// Route id is a UUID now (old prototype used integer IDs).
			id, ok := parseActivityID(c.Param("id"))
			if !ok {
				c.JSON(http.StatusBadRequest, gin.H{"error": "id must be a UUID"})
				return
			}

			userID, ok := authUserID(c)
			if !ok {
				c.JSON(http.StatusUnauthorized, gin.H{"error": "missing authenticated user"})
				return
			}

			a, found, err := store.get(c.Request.Context(), userID, id)
			if err != nil {
				log.Printf("get activity failed: %v", err)
				c.JSON(http.StatusInternalServerError, gin.H{"error": "internal server error"})
				return
			}
			if !found {
				c.JSON(http.StatusNotFound, gin.H{"error": "activity not found"})
				return
			}

			c.JSON(http.StatusOK, a)
		})

		activities.PATCH("/:id/like", func(c *gin.Context) {
			id, ok := parseActivityID(c.Param("id"))
			if !ok {
				c.JSON(http.StatusBadRequest, gin.H{"error": "id must be a UUID"})
				return
			}

			userID, ok := authUserID(c)
			if !ok {
				c.JSON(http.StatusUnauthorized, gin.H{"error": "missing authenticated user"})
				return
			}

			a, found, err := store.like(c.Request.Context(), userID, id)
			if err != nil {
				log.Printf("like activity failed: %v", err)
				c.JSON(http.StatusInternalServerError, gin.H{"error": "internal server error"})
				return
			}
			if !found {
				c.JSON(http.StatusNotFound, gin.H{"error": "activity not found"})
				return
			}

			c.JSON(http.StatusOK, a)
		})
	}
}

// newAuthMiddlewareFromEnv builds JWT auth middleware from env config.
// The middleware:
// 1) reads bearer token,
// 2) verifies token signature + claims,
// 3) stores user info in Gin context.
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

// readAuthConfigFromEnv collects required auth settings from env vars.
// SUPABASE_JWKS_URL is required.
// JWT_AUDIENCE defaults to "authenticated" if not set.
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

// jwksProvider caches RSA public keys from Supabase JWKS endpoint.
// This avoids calling the remote JWKS URL on every request.
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

// lookupKey gets a public key by kid.
// If key is missing, it refreshes JWKS once and retries.
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

// refresh downloads and parses JWKS into an in-memory key map.
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

// parseRSAPublicKey converts JWK n/e fields (base64url) into rsa.PublicKey.
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

// verifyJWT performs manual JWT verification:
// - split token,
// - decode header,
// - fetch public key by kid,
// - verify RS256 signature,
// - decode claims and validate them.
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

// validateClaims checks exp/nbf/iat and optional iss/aud constraints.
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

// numericClaim converts common JSON number formats into int64.
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

// audienceContains supports "aud" as string or array.
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

// extractBearerToken parses "Authorization: Bearer <token>".
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

func parseActivityID(raw string) (string, bool) {
	// Cheap UUID syntax check for route params without extra dependencies.
	id := strings.TrimSpace(raw)
	if len(id) != 36 {
		return "", false
	}

	for i := 0; i < len(id); i++ {
		ch := id[i]
		switch i {
		case 8, 13, 18, 23:
			if ch != '-' {
				return "", false
			}
		default:
			if !isHex(ch) {
				return "", false
			}
		}
	}

	return strings.ToLower(id), true
}

// isHex returns true when a byte is [0-9a-fA-F].
func isHex(ch byte) bool {
	switch {
	case ch >= '0' && ch <= '9':
		return true
	case ch >= 'a' && ch <= 'f':
		return true
	case ch >= 'A' && ch <= 'F':
		return true
	default:
		return false
	}
}

// authUserID fetches the authenticated user id from Gin context.
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

// requestLogger adds X-Request-Duration so latency is visible in responses.
func requestLogger() gin.HandlerFunc {
	return func(c *gin.Context) {
		start := time.Now()
		c.Next()
		latency := time.Since(start)

		// Quick visibility for debugging response times.
		c.Writer.Header().Set("X-Request-Duration", latency.String())
	}
}

// Common SELECT projection used by list/get/create return paths.
const activitySelectColumns = `
a.id::text,
a.user_id::text,
a.title,
a.notes,
a.start_time,
a.duration_seconds,
a.distance_m,
a.avg_split_500m_seconds,
a.avg_stroke_spm,
a.visibility,
a.team_id::text,
a.route_geojson,
a.created_at,
coalesce((select count(*) from public.activity_likes l where l.activity_id = a.id), 0)::int,
coalesce((select count(*) from public.activity_comments c where c.activity_id = a.id), 0)::int
`

const listActivitiesQuery = `
-- List own activities and public activities for feed-like behavior.
select ` + activitySelectColumns + `
from public.activities a
where a.user_id = $1::uuid
   or a.visibility = 'public'
order by a.start_time desc
limit 100
`

const getActivityQuery = `
-- Fetch a single activity if visible to requester.
select ` + activitySelectColumns + `
from public.activities a
where a.id = $2::uuid
  and (a.user_id = $1::uuid or a.visibility = 'public')
limit 1
`

const createActivityQuery = `
-- Insert first, then re-select with computed counters so API shape is consistent.
with inserted as (
	insert into public.activities (
		user_id,
		title,
		notes,
		start_time,
		duration_seconds,
		distance_m,
		avg_split_500m_seconds,
		avg_stroke_spm,
		visibility,
		team_id,
		route_geojson
	)
	values (
		$1::uuid,
		$2,
		$3,
		$4,
		$5,
		$6,
		$7,
		$8,
		$9,
		$10::uuid,
		$11::jsonb
	)
	returning id
)
select ` + activitySelectColumns + `
from public.activities a
join inserted i on i.id = a.id
`

const ensureProfileQuery = `
-- Activities.user_id references profiles.id, so we create a minimal profile row
-- for first-time users if it does not exist yet.
insert into public.profiles (id, username)
values ($1::uuid, $2)
on conflict (id) do nothing
`

const insertLikeQuery = `
insert into public.activity_likes (user_id, activity_id)
values ($1::uuid, $2::uuid)
on conflict do nothing
`

// activityStore is a small repository around pgxpool.
type activityStore struct {
	pool *pgxpool.Pool
}

func newActivityStoreFromEnv(ctx context.Context) (*activityStore, error) {
	// Reuse one pool for all handlers; pgxpool manages internal connection concurrency.
	databaseURL, err := readDatabaseURLFromEnv()
	if err != nil {
		return nil, err
	}

	poolConfig, err := pgxpool.ParseConfig(databaseURL)
	if err != nil {
		return nil, fmt.Errorf("parse database url: %w", err)
	}

	connectCtx, cancel := context.WithTimeout(ctx, 10*time.Second)
	defer cancel()

	pool, err := pgxpool.NewWithConfig(connectCtx, poolConfig)
	if err != nil {
		return nil, fmt.Errorf("connect to database: %w", err)
	}

	if err := pool.Ping(connectCtx); err != nil {
		pool.Close()
		return nil, fmt.Errorf("ping database: %w", err)
	}

	return &activityStore{pool: pool}, nil
}

// readDatabaseURLFromEnv supports either DATABASE_URL or DB_URL.
func readDatabaseURLFromEnv() (string, error) {
	if databaseURL := strings.TrimSpace(os.Getenv("DATABASE_URL")); databaseURL != "" {
		return databaseURL, nil
	}
	if databaseURL := strings.TrimSpace(os.Getenv("DB_URL")); databaseURL != "" {
		return databaseURL, nil
	}
	return "", errors.New("DATABASE_URL or DB_URL is required")
}

// close closes the shared pgx pool on shutdown.
func (s *activityStore) close() {
	if s == nil || s.pool == nil {
		return
	}
	s.pool.Close()
}

// list returns activities visible to the current user.
func (s *activityStore) list(ctx context.Context, userID string) ([]Activity, error) {
	// Read path: query + scan into API model.
	rows, err := s.pool.Query(ctx, listActivitiesQuery, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	activities := make([]Activity, 0, 32)
	for rows.Next() {
		activity, err := scanActivity(rows)
		if err != nil {
			return nil, err
		}
		activities = append(activities, activity)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}

	return activities, nil
}

// create inserts a new activity and returns the inserted row in API shape.
func (s *activityStore) create(ctx context.Context, userID string, req CreateActivityRequest) (Activity, error) {
	// Ensure FK target exists before insert into activities.
	if err := s.ensureProfile(ctx, userID); err != nil {
		return Activity{}, err
	}

	var routeJSON any
	if len(req.RouteGeoJSON) > 0 {
		routeJSON = req.RouteGeoJSON
	}

	row := s.pool.QueryRow(
		ctx,
		createActivityQuery,
		userID,
		req.Title,
		req.Notes,
		req.StartTime.UTC(),
		req.DurationSeconds,
		req.DistanceM,
		req.AvgSplit500MSeconds,
		req.AvgStrokeSPM,
		req.Visibility,
		req.TeamID,
		routeJSON,
	)

	activity, err := scanActivity(row)
	if err != nil {
		return Activity{}, err
	}
	return activity, nil
}

// get reads one activity if requester is allowed to see it.
func (s *activityStore) get(ctx context.Context, userID, activityID string) (Activity, bool, error) {
	row := s.pool.QueryRow(ctx, getActivityQuery, userID, activityID)
	activity, err := scanActivity(row)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return Activity{}, false, nil
		}
		return Activity{}, false, err
	}
	return activity, true, nil
}

// like does an idempotent like insert, then returns updated counters.
func (s *activityStore) like(ctx context.Context, userID, activityID string) (Activity, bool, error) {
	// We check visibility first, then idempotently insert like, then return fresh counters.
	if _, found, err := s.get(ctx, userID, activityID); err != nil || !found {
		return Activity{}, found, err
	}

	if _, err := s.pool.Exec(ctx, insertLikeQuery, userID, activityID); err != nil {
		return Activity{}, false, err
	}

	activity, found, err := s.get(ctx, userID, activityID)
	if err != nil || !found {
		return Activity{}, found, err
	}

	return activity, true, nil
}

// ensureProfile creates a minimal profile row so activities FK can reference it.
// Username is deterministic and based on user id.
func (s *activityStore) ensureProfile(ctx context.Context, userID string) error {
	username := "user_" + strings.ReplaceAll(strings.ToLower(userID), "-", "")
	_, err := s.pool.Exec(ctx, ensureProfileQuery, userID, username)
	return err
}

// scanActivity maps one DB row into Activity struct.
// It handles nullable DB values with sql.Null* wrappers.
func scanActivity(scanner interface{ Scan(dest ...any) error }) (Activity, error) {
	// sql.Null* keeps null semantics explicit while scanning optional DB columns.
	var (
		activity            Activity
		title               sql.NullString
		notes               sql.NullString
		durationSeconds     sql.NullInt32
		distanceM           sql.NullFloat64
		avgSplit500mSeconds sql.NullInt32
		avgStrokeSPM        sql.NullInt16
		teamID              sql.NullString
		routeGeoJSON        []byte
		likes               int32
		comments            int32
	)

	if err := scanner.Scan(
		&activity.ID,
		&activity.UserID,
		&title,
		&notes,
		&activity.StartTime,
		&durationSeconds,
		&distanceM,
		&avgSplit500mSeconds,
		&avgStrokeSPM,
		&activity.Visibility,
		&teamID,
		&routeGeoJSON,
		&activity.CreatedAt,
		&likes,
		&comments,
	); err != nil {
		return Activity{}, err
	}

	if title.Valid {
		activity.Title = stringPtr(title.String)
	}
	if notes.Valid {
		activity.Notes = stringPtr(notes.String)
	}
	if durationSeconds.Valid {
		activity.DurationSeconds = int32Ptr(durationSeconds.Int32)
	}
	if distanceM.Valid {
		activity.DistanceM = float64Ptr(distanceM.Float64)
	}
	if avgSplit500mSeconds.Valid {
		activity.AvgSplit500MSeconds = int32Ptr(avgSplit500mSeconds.Int32)
	}
	if avgStrokeSPM.Valid {
		activity.AvgStrokeSPM = int16Ptr(avgStrokeSPM.Int16)
	}
	if teamID.Valid {
		activity.TeamID = stringPtr(teamID.String)
	}
	if len(routeGeoJSON) > 0 {
		activity.RouteGeoJSON = append(json.RawMessage(nil), routeGeoJSON...)
	}

	activity.Likes = int(likes)
	activity.Comments = int(comments)

	return activity, nil
}

// Small pointer helpers keep scan-to-API mapping readable.
func stringPtr(v string) *string {
	return &v
}

func int32Ptr(v int32) *int32 {
	return &v
}

func int16Ptr(v int16) *int16 {
	return &v
}

func float64Ptr(v float64) *float64 {
	return &v
}
