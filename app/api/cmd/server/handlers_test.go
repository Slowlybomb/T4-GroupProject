package main

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"net"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/gin-gonic/gin"
	"golang.org/x/net/websocket"
)

type fakeActivityService struct {
	listFn                  func(ctx context.Context, userID string, scope FeedScope) ([]Activity, error)
	createFn                func(ctx context.Context, userID string, req CreateActivityRequest) (Activity, error)
	getFn                   func(ctx context.Context, userID, activityID string) (Activity, bool, error)
	likeFn                  func(ctx context.Context, userID, activityID string) (Activity, bool, error)
	followFn                func(ctx context.Context, userID, targetUserID string) (bool, error)
	unfollowFn              func(ctx context.Context, userID, targetUserID string) (bool, error)
	listFollowSuggestionsFn func(ctx context.Context, userID string, limit int) ([]FollowSuggestion, error)
	metricsSummaryFn        func(ctx context.Context, userID string, from, to time.Time) (MetricsSummary, error)
}

type fakeStorageSigner struct {
	createSignedUploadURLFn   func(ctx context.Context, bucket, objectPath string, expiresIn time.Duration) (string, error)
	createSignedDownloadURLFn func(ctx context.Context, bucket, objectPath string, expiresIn time.Duration) (string, error)
}

func (f *fakeActivityService) list(ctx context.Context, userID string, scope FeedScope) ([]Activity, error) {
	if f.listFn != nil {
		return f.listFn(ctx, userID, scope)
	}
	return []Activity{}, nil
}

func (f *fakeActivityService) create(ctx context.Context, userID string, req CreateActivityRequest) (Activity, error) {
	if f.createFn != nil {
		return f.createFn(ctx, userID, req)
	}
	return Activity{}, nil
}

func (f *fakeActivityService) get(ctx context.Context, userID, activityID string) (Activity, bool, error) {
	if f.getFn != nil {
		return f.getFn(ctx, userID, activityID)
	}
	return Activity{}, false, nil
}

func (f *fakeActivityService) like(ctx context.Context, userID, activityID string) (Activity, bool, error) {
	if f.likeFn != nil {
		return f.likeFn(ctx, userID, activityID)
	}
	return Activity{}, false, nil
}

func (f *fakeActivityService) follow(ctx context.Context, userID, targetUserID string) (bool, error) {
	if f.followFn != nil {
		return f.followFn(ctx, userID, targetUserID)
	}
	return true, nil
}

func (f *fakeActivityService) unfollow(ctx context.Context, userID, targetUserID string) (bool, error) {
	if f.unfollowFn != nil {
		return f.unfollowFn(ctx, userID, targetUserID)
	}
	return true, nil
}

func (f *fakeActivityService) listFollowSuggestions(ctx context.Context, userID string, limit int) ([]FollowSuggestion, error) {
	if f.listFollowSuggestionsFn != nil {
		return f.listFollowSuggestionsFn(ctx, userID, limit)
	}
	return []FollowSuggestion{}, nil
}

func (f *fakeActivityService) metricsSummary(ctx context.Context, userID string, from, to time.Time) (MetricsSummary, error) {
	if f.metricsSummaryFn != nil {
		return f.metricsSummaryFn(ctx, userID, from, to)
	}
	return MetricsSummary{
		From: from,
		To:   to,
	}, nil
}

// createSignedUploadURL delegates to the injected fake function.
func (f *fakeStorageSigner) createSignedUploadURL(ctx context.Context, bucket, objectPath string, expiresIn time.Duration) (string, error) {
	if f.createSignedUploadURLFn != nil {
		return f.createSignedUploadURLFn(ctx, bucket, objectPath, expiresIn)
	}
	return "", errors.New("createSignedUploadURLFn is not set")
}

// createSignedDownloadURL delegates to the injected fake function.
func (f *fakeStorageSigner) createSignedDownloadURL(ctx context.Context, bucket, objectPath string, expiresIn time.Duration) (string, error) {
	if f.createSignedDownloadURLFn != nil {
		return f.createSignedDownloadURLFn(ctx, bucket, objectPath, expiresIn)
	}
	return "", errors.New("createSignedDownloadURLFn is not set")
}

func testRouter(t *testing.T, authMiddleware gin.HandlerFunc, store activityService, signer storageSigner) *gin.Engine {
	t.Helper()
	r, _ := testRouterWithRealtime(t, authMiddleware, store, signer)
	return r
}

func testRouterWithRealtime(t *testing.T, authMiddleware gin.HandlerFunc, store activityService, signer storageSigner) (*gin.Engine, *realtimeHub) {
	t.Helper()
	gin.SetMode(gin.TestMode)
	r := gin.New()
	r.Use(gin.Recovery())
	r.Use(requestLogger())
	realtime := newRealtimeHub()
	t.Cleanup(realtime.close)
	registerRoutes(r, authMiddleware, store, signer, realtime)
	return r, realtime
}

func fakeAuthWithUser(userID string) gin.HandlerFunc {
	return func(c *gin.Context) {
		c.Set("auth.user_id", userID)
		c.Next()
	}
}

func passThroughAuth() gin.HandlerFunc {
	return func(c *gin.Context) {
		c.Next()
	}
}

func TestHealthEndpoint(t *testing.T) {
	r := testRouter(t, passThroughAuth(), &fakeActivityService{}, nil)

	req := httptest.NewRequest(http.MethodGet, "/api/v1/health", nil)
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d", w.Code)
	}

	var body map[string]any
	if err := json.Unmarshal(w.Body.Bytes(), &body); err != nil {
		t.Fatalf("failed to parse response: %v", err)
	}
	if body["status"] != "ok" {
		t.Fatalf("expected status=ok, got %v", body["status"])
	}
}

func TestActivitiesGetRequiresUserInContext(t *testing.T) {
	r := testRouter(t, passThroughAuth(), &fakeActivityService{}, nil)

	req := httptest.NewRequest(http.MethodGet, "/api/v1/activities", nil)
	req.Header.Set("Authorization", "Bearer test")
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)

	if w.Code != http.StatusUnauthorized {
		t.Fatalf("expected 401, got %d", w.Code)
	}
}

func TestActivitiesGetReturnsStoreValues(t *testing.T) {
	wantUserID := "11111111-1111-1111-1111-111111111111"
	now := time.Now().UTC()

	store := &fakeActivityService{
		listFn: func(ctx context.Context, userID string, scope FeedScope) ([]Activity, error) {
			if userID != wantUserID {
				t.Fatalf("expected userID %s, got %s", wantUserID, userID)
			}
			if scope != feedScopeFollowing {
				t.Fatalf("expected default following scope, got %s", scope)
			}
			return []Activity{
				{
					ID:         "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
					UserID:     wantUserID,
					Visibility: "public",
					StartTime:  now,
					CreatedAt:  now,
				},
			}, nil
		},
	}

	r := testRouter(t, fakeAuthWithUser(wantUserID), store, nil)
	req := httptest.NewRequest(http.MethodGet, "/api/v1/activities", nil)
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d, body=%s", w.Code, w.Body.String())
	}

	var activities []Activity
	if err := json.Unmarshal(w.Body.Bytes(), &activities); err != nil {
		t.Fatalf("failed to parse activities: %v", err)
	}
	if len(activities) != 1 {
		t.Fatalf("expected 1 activity, got %d", len(activities))
	}
	if activities[0].ID != "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa" {
		t.Fatalf("unexpected activity id: %s", activities[0].ID)
	}
}

func TestActivitiesPostRejectsTeamVisibilityWithoutTeamID(t *testing.T) {
	r := testRouter(t, fakeAuthWithUser("11111111-1111-1111-1111-111111111111"), &fakeActivityService{}, nil)

	body := []byte(`{
		"start_time":"2026-01-01T10:00:00Z",
		"visibility":"team"
	}`)

	req := httptest.NewRequest(http.MethodPost, "/api/v1/activities", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)

	if w.Code != http.StatusBadRequest {
		t.Fatalf("expected 400, got %d, body=%s", w.Code, w.Body.String())
	}
}

func TestActivitiesPostCreatesRecord(t *testing.T) {
	const userID = "11111111-1111-1111-1111-111111111111"
	now := time.Now().UTC().Truncate(time.Second)
	title := "Morning row"

	store := &fakeActivityService{
		createFn: func(ctx context.Context, gotUserID string, req CreateActivityRequest) (Activity, error) {
			if gotUserID != userID {
				t.Fatalf("expected userID %s, got %s", userID, gotUserID)
			}
			if req.Visibility != "public" {
				t.Fatalf("expected visibility public, got %s", req.Visibility)
			}
			if req.Title == nil || *req.Title != title {
				t.Fatalf("expected title %q", title)
			}
			return Activity{
				ID:         "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
				UserID:     gotUserID,
				Title:      req.Title,
				Visibility: req.Visibility,
				StartTime:  req.StartTime,
				CreatedAt:  now,
			}, nil
		},
	}

	r := testRouter(t, fakeAuthWithUser(userID), store, nil)
	body := []byte(`{
		"title":"Morning row",
		"start_time":"2026-01-01T10:00:00Z",
		"visibility":"public"
	}`)

	req := httptest.NewRequest(http.MethodPost, "/api/v1/activities", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)

	if w.Code != http.StatusCreated {
		t.Fatalf("expected 201, got %d, body=%s", w.Code, w.Body.String())
	}
}

func TestActivitiesPostNormalizesFeatureCollectionRouteGeoJSON(t *testing.T) {
	const userID = "11111111-1111-1111-1111-111111111111"
	now := time.Now().UTC().Truncate(time.Second)

	store := &fakeActivityService{
		createFn: func(ctx context.Context, gotUserID string, req CreateActivityRequest) (Activity, error) {
			if gotUserID != userID {
				t.Fatalf("expected userID %s, got %s", userID, gotUserID)
			}

			var route map[string]any
			if err := json.Unmarshal(req.RouteGeoJSON, &route); err != nil {
				t.Fatalf("failed to decode normalized route_geojson: %v", err)
			}
			if route["type"] != "LineString" {
				t.Fatalf("expected normalized LineString, got %v", route["type"])
			}
			coords, ok := route["coordinates"].([]any)
			if !ok || len(coords) != 3 {
				t.Fatalf("unexpected coordinates: %#v", route["coordinates"])
			}

			return Activity{
				ID:           "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
				UserID:       gotUserID,
				Visibility:   req.Visibility,
				StartTime:    req.StartTime,
				RouteGeoJSON: req.RouteGeoJSON,
				CreatedAt:    now,
			}, nil
		},
	}

	r := testRouter(t, fakeAuthWithUser(userID), store, nil)
	body := []byte(`{
		"start_time":"2026-01-01T10:00:00Z",
		"visibility":"public",
		"route_geojson":{
			"type":"FeatureCollection",
			"features":[
				{"type":"Feature","geometry":{"type":"Point","coordinates":[-8.46,51.89]}},
				{"type":"Feature","geometry":{"type":"LineString","coordinates":[[-8.4606,51.8991],[-8.4610,51.8995],[-8.4632,51.8997]]}}
			]
		}
	}`)

	req := httptest.NewRequest(http.MethodPost, "/api/v1/activities", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)

	if w.Code != http.StatusCreated {
		t.Fatalf("expected 201, got %d, body=%s", w.Code, w.Body.String())
	}
}

func TestActivitiesPostRejectsRouteGeoJSONWithoutLineString(t *testing.T) {
	const userID = "11111111-1111-1111-1111-111111111111"

	r := testRouter(t, fakeAuthWithUser(userID), &fakeActivityService{}, nil)
	body := []byte(`{
		"start_time":"2026-01-01T10:00:00Z",
		"visibility":"public",
		"route_geojson":{
			"type":"FeatureCollection",
			"features":[
				{"type":"Feature","geometry":{"type":"Point","coordinates":[-8.46,51.89]}}
			]
		}
	}`)

	req := httptest.NewRequest(http.MethodPost, "/api/v1/activities", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)

	if w.Code != http.StatusBadRequest {
		t.Fatalf("expected 400, got %d, body=%s", w.Code, w.Body.String())
	}
	if !strings.Contains(w.Body.String(), "LineString") {
		t.Fatalf("expected LineString error, got body=%s", w.Body.String())
	}
}

func TestActivitiesGetInvalidID(t *testing.T) {
	r := testRouter(t, fakeAuthWithUser("11111111-1111-1111-1111-111111111111"), &fakeActivityService{}, nil)

	req := httptest.NewRequest(http.MethodGet, "/api/v1/activities/not-a-uuid", nil)
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)

	if w.Code != http.StatusBadRequest {
		t.Fatalf("expected 400, got %d", w.Code)
	}
}

func TestActivitiesGetNotFound(t *testing.T) {
	store := &fakeActivityService{
		getFn: func(ctx context.Context, userID, activityID string) (Activity, bool, error) {
			return Activity{}, false, nil
		},
	}
	r := testRouter(t, fakeAuthWithUser("11111111-1111-1111-1111-111111111111"), store, nil)

	req := httptest.NewRequest(http.MethodGet, "/api/v1/activities/aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa", nil)
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)

	if w.Code != http.StatusNotFound {
		t.Fatalf("expected 404, got %d", w.Code)
	}
}

func TestActivitiesLikeStoreError(t *testing.T) {
	store := &fakeActivityService{
		likeFn: func(ctx context.Context, userID, activityID string) (Activity, bool, error) {
			return Activity{}, false, errors.New("db is down")
		},
	}
	r := testRouter(t, fakeAuthWithUser("11111111-1111-1111-1111-111111111111"), store, nil)

	req := httptest.NewRequest(http.MethodPatch, "/api/v1/activities/aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa/like", nil)
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)

	if w.Code != http.StatusInternalServerError {
		t.Fatalf("expected 500, got %d", w.Code)
	}
}

func TestActivitiesGetRejectsInvalidScope(t *testing.T) {
	r := testRouter(t, fakeAuthWithUser("11111111-1111-1111-1111-111111111111"), &fakeActivityService{}, nil)

	req := httptest.NewRequest(http.MethodGet, "/api/v1/activities?scope=invalid", nil)
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)

	if w.Code != http.StatusBadRequest {
		t.Fatalf("expected 400, got %d", w.Code)
	}
}

func TestActivitiesGetUsesExplicitScope(t *testing.T) {
	const userID = "11111111-1111-1111-1111-111111111111"
	capturedScope := feedScopeFollowing

	store := &fakeActivityService{
		listFn: func(ctx context.Context, gotUserID string, scope FeedScope) ([]Activity, error) {
			if gotUserID != userID {
				t.Fatalf("expected userID %s, got %s", userID, gotUserID)
			}
			capturedScope = scope
			return []Activity{}, nil
		},
	}

	r := testRouter(t, fakeAuthWithUser(userID), store, nil)
	req := httptest.NewRequest(http.MethodGet, "/api/v1/activities?scope=friends", nil)
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d", w.Code)
	}
	if capturedScope != feedScopeFriends {
		t.Fatalf("expected friends scope, got %s", capturedScope)
	}
}

func TestFollowsPutSuccess(t *testing.T) {
	const userID = "11111111-1111-1111-1111-111111111111"
	const targetID = "22222222-2222-2222-2222-222222222222"

	store := &fakeActivityService{
		followFn: func(ctx context.Context, gotUserID, gotTargetID string) (bool, error) {
			if gotUserID != userID {
				t.Fatalf("expected userID %s, got %s", userID, gotUserID)
			}
			if gotTargetID != targetID {
				t.Fatalf("expected targetID %s, got %s", targetID, gotTargetID)
			}
			return true, nil
		},
	}

	r := testRouter(t, fakeAuthWithUser(userID), store, nil)
	req := httptest.NewRequest(http.MethodPut, "/api/v1/follows/"+targetID, nil)
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)

	if w.Code != http.StatusNoContent {
		t.Fatalf("expected 204, got %d", w.Code)
	}
}

func TestFollowsPutRejectsSelfFollow(t *testing.T) {
	const userID = "11111111-1111-1111-1111-111111111111"
	r := testRouter(t, fakeAuthWithUser(userID), &fakeActivityService{}, nil)

	req := httptest.NewRequest(http.MethodPut, "/api/v1/follows/"+userID, nil)
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)

	if w.Code != http.StatusBadRequest {
		t.Fatalf("expected 400, got %d", w.Code)
	}
}

func TestFollowsPutReturnsNotFoundWhenTargetMissing(t *testing.T) {
	const userID = "11111111-1111-1111-1111-111111111111"
	const targetID = "22222222-2222-2222-2222-222222222222"

	store := &fakeActivityService{
		followFn: func(ctx context.Context, gotUserID, gotTargetID string) (bool, error) {
			return false, nil
		},
	}

	r := testRouter(t, fakeAuthWithUser(userID), store, nil)
	req := httptest.NewRequest(http.MethodPut, "/api/v1/follows/"+targetID, nil)
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)

	if w.Code != http.StatusNotFound {
		t.Fatalf("expected 404, got %d", w.Code)
	}
}

func TestFollowsSuggestionsUsesLimitClamp(t *testing.T) {
	const userID = "11111111-1111-1111-1111-111111111111"
	capturedLimit := 0

	store := &fakeActivityService{
		listFollowSuggestionsFn: func(ctx context.Context, gotUserID string, limit int) ([]FollowSuggestion, error) {
			if gotUserID != userID {
				t.Fatalf("expected userID %s, got %s", userID, gotUserID)
			}
			capturedLimit = limit
			return []FollowSuggestion{
				{
					ID:        "33333333-3333-3333-3333-333333333333",
					Username:  "sarah",
					CreatedAt: time.Now().UTC(),
				},
			}, nil
		},
	}

	r := testRouter(t, fakeAuthWithUser(userID), store, nil)
	req := httptest.NewRequest(http.MethodGet, "/api/v1/follows/suggestions?limit=200", nil)
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d, body=%s", w.Code, w.Body.String())
	}
	if capturedLimit != maxSuggestionsLimit {
		t.Fatalf("expected clamped limit %d, got %d", maxSuggestionsLimit, capturedLimit)
	}
}

func TestMetricsSummarySuccess(t *testing.T) {
	const userID = "11111111-1111-1111-1111-111111111111"
	from := time.Date(2026, 1, 5, 0, 0, 0, 0, time.UTC)
	to := time.Date(2026, 1, 7, 12, 0, 0, 0, time.UTC)

	store := &fakeActivityService{
		metricsSummaryFn: func(ctx context.Context, gotUserID string, gotFrom, gotTo time.Time) (MetricsSummary, error) {
			if gotUserID != userID {
				t.Fatalf("expected userID %s, got %s", userID, gotUserID)
			}
			if !gotFrom.Equal(from) || !gotTo.Equal(to) {
				t.Fatalf("unexpected range from=%s to=%s", gotFrom, gotTo)
			}
			return MetricsSummary{
				From:                 gotFrom,
				To:                   gotTo,
				TotalWorkouts:        4,
				TotalDistanceM:       12345,
				TotalDurationSeconds: 3600,
			}, nil
		},
	}

	r := testRouter(t, fakeAuthWithUser(userID), store, nil)
	req := httptest.NewRequest(
		http.MethodGet,
		"/api/v1/metrics/summary?from="+urlQueryEscape(from.Format(time.RFC3339))+"&to="+urlQueryEscape(to.Format(time.RFC3339)),
		nil,
	)
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d, body=%s", w.Code, w.Body.String())
	}
}

func TestMetricsSummaryRejectsInvertedRange(t *testing.T) {
	const userID = "11111111-1111-1111-1111-111111111111"
	r := testRouter(t, fakeAuthWithUser(userID), &fakeActivityService{}, nil)

	req := httptest.NewRequest(
		http.MethodGet,
		"/api/v1/metrics/summary?from=2026-01-07T12:00:00Z&to=2026-01-05T00:00:00Z",
		nil,
	)
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)

	if w.Code != http.StatusBadRequest {
		t.Fatalf("expected 400, got %d", w.Code)
	}
}

func TestMetricsSummaryRejectsBadTimestamp(t *testing.T) {
	const userID = "11111111-1111-1111-1111-111111111111"
	r := testRouter(t, fakeAuthWithUser(userID), &fakeActivityService{}, nil)

	req := httptest.NewRequest(
		http.MethodGet,
		"/api/v1/metrics/summary?from=bad-value&to=2026-01-05T00:00:00Z",
		nil,
	)
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)

	if w.Code != http.StatusBadRequest {
		t.Fatalf("expected 400, got %d", w.Code)
	}
}

func urlQueryEscape(value string) string {
	return strings.ReplaceAll(value, ":", "%3A")
}

// TestFilesUploadURLSuccess verifies happy-path upload URL signing.
func TestFilesUploadURLSuccess(t *testing.T) {
	const userID = "11111111-1111-1111-1111-111111111111"
	const signedURL = "https://example.supabase.co/storage/v1/object/upload/sign/avatars/11111111-1111-1111-1111-111111111111/profile.jpg?token=abc"

	signer := &fakeStorageSigner{
		createSignedUploadURLFn: func(ctx context.Context, bucket, objectPath string, expiresIn time.Duration) (string, error) {
			if bucket != "avatars" {
				t.Fatalf("expected bucket avatars, got %s", bucket)
			}
			if objectPath != userID+"/profile.jpg" {
				t.Fatalf("unexpected objectPath %q", objectPath)
			}
			if expiresIn != 15*time.Minute {
				t.Fatalf("expected 15m expiry, got %s", expiresIn)
			}
			return signedURL, nil
		},
	}

	r := testRouter(t, fakeAuthWithUser(userID), &fakeActivityService{}, signer)
	body := []byte(`{
		"bucket":"avatars",
		"path":"11111111-1111-1111-1111-111111111111/profile.jpg",
		"content_type":"image/jpeg",
		"expires_in_seconds":900
	}`)

	req := httptest.NewRequest(http.MethodPost, "/api/v1/files/upload-url", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d, body=%s", w.Code, w.Body.String())
	}

	var resp createUploadURLResponse
	if err := json.Unmarshal(w.Body.Bytes(), &resp); err != nil {
		t.Fatalf("failed to parse response: %v", err)
	}
	if resp.Method != http.MethodPut {
		t.Fatalf("expected method PUT, got %s", resp.Method)
	}
	if resp.UploadURL != signedURL {
		t.Fatalf("unexpected upload_url: %s", resp.UploadURL)
	}
	if resp.Headers["Content-Type"] != "image/jpeg" {
		t.Fatalf("expected Content-Type header to be image/jpeg, got %q", resp.Headers["Content-Type"])
	}
}

// TestFilesUploadURLRejectsForeignPrefix ensures cross-user paths are blocked.
func TestFilesUploadURLRejectsForeignPrefix(t *testing.T) {
	const userID = "11111111-1111-1111-1111-111111111111"

	signer := &fakeStorageSigner{
		createSignedUploadURLFn: func(ctx context.Context, bucket, objectPath string, expiresIn time.Duration) (string, error) {
			t.Fatalf("signer should not be called for invalid path")
			return "", nil
		},
	}

	r := testRouter(t, fakeAuthWithUser(userID), &fakeActivityService{}, signer)
	body := []byte(`{
		"bucket":"avatars",
		"path":"22222222-2222-2222-2222-222222222222/profile.jpg",
		"content_type":"image/jpeg"
	}`)

	req := httptest.NewRequest(http.MethodPost, "/api/v1/files/upload-url", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)

	if w.Code != http.StatusBadRequest {
		t.Fatalf("expected 400, got %d, body=%s", w.Code, w.Body.String())
	}
}

// TestFilesDownloadURLUsesDefaultExpiry validates default expiry behavior.
func TestFilesDownloadURLUsesDefaultExpiry(t *testing.T) {
	const userID = "11111111-1111-1111-1111-111111111111"
	const signedURL = "https://example.supabase.co/storage/v1/object/sign/workout-images/11111111-1111-1111-1111-111111111111/act-1/img.jpg?token=abc"

	signer := &fakeStorageSigner{
		createSignedDownloadURLFn: func(ctx context.Context, bucket, objectPath string, expiresIn time.Duration) (string, error) {
			if bucket != "workout-images" {
				t.Fatalf("expected bucket workout-images, got %s", bucket)
			}
			if objectPath != userID+"/act-1/img.jpg" {
				t.Fatalf("unexpected objectPath %q", objectPath)
			}
			if expiresIn != 10*time.Minute {
				t.Fatalf("expected default 10m expiry, got %s", expiresIn)
			}
			return signedURL, nil
		},
	}

	r := testRouter(t, fakeAuthWithUser(userID), &fakeActivityService{}, signer)
	body := []byte(`{
		"bucket":"workout-images",
		"path":"11111111-1111-1111-1111-111111111111/act-1/img.jpg"
	}`)

	req := httptest.NewRequest(http.MethodPost, "/api/v1/files/download-url", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d, body=%s", w.Code, w.Body.String())
	}

	var resp createDownloadURLResponse
	if err := json.Unmarshal(w.Body.Bytes(), &resp); err != nil {
		t.Fatalf("failed to parse response: %v", err)
	}
	if resp.DownloadURL != signedURL {
		t.Fatalf("unexpected download_url: %s", resp.DownloadURL)
	}
}

// TestFilesUploadURLReturns503WhenSignerMissing checks graceful misconfig handling.
func TestFilesUploadURLReturns503WhenSignerMissing(t *testing.T) {
	r := testRouter(t, fakeAuthWithUser("11111111-1111-1111-1111-111111111111"), &fakeActivityService{}, nil)
	body := []byte(`{
		"bucket":"avatars",
		"path":"11111111-1111-1111-1111-111111111111/profile.jpg",
		"content_type":"image/jpeg"
	}`)

	req := httptest.NewRequest(http.MethodPost, "/api/v1/files/upload-url", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)

	if w.Code != http.StatusServiceUnavailable {
		t.Fatalf("expected 503, got %d, body=%s", w.Code, w.Body.String())
	}
}

// TestFilesUploadURLRequiresUserInContext enforces auth context presence.
func TestFilesUploadURLRequiresUserInContext(t *testing.T) {
	signer := &fakeStorageSigner{
		createSignedUploadURLFn: func(ctx context.Context, bucket, objectPath string, expiresIn time.Duration) (string, error) {
			t.Fatalf("signer should not be called without user context")
			return "", nil
		},
	}

	r := testRouter(t, passThroughAuth(), &fakeActivityService{}, signer)
	body := []byte(`{
		"bucket":"avatars",
		"path":"11111111-1111-1111-1111-111111111111/profile.jpg",
		"content_type":"image/jpeg"
	}`)

	req := httptest.NewRequest(http.MethodPost, "/api/v1/files/upload-url", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer test")
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)

	if w.Code != http.StatusUnauthorized {
		t.Fatalf("expected 401, got %d, body=%s", w.Code, w.Body.String())
	}
}

type wsEvent struct {
	Channel string         `json:"channel"`
	Type    string         `json:"type"`
	Payload map[string]any `json:"payload"`
}

func wsURLFromHTTP(serverURL string) string {
	return "ws" + strings.TrimPrefix(serverURL, "http") + "/api/v1/ws"
}

func dialWS(t *testing.T, serverURL string, header http.Header) *websocket.Conn {
	t.Helper()
	cfg, err := websocket.NewConfig(wsURLFromHTTP(serverURL), "http://localhost/")
	if err != nil {
		t.Fatalf("failed to build websocket config: %v", err)
	}
	if header != nil {
		cfg.Header = header
	}
	conn, err := websocket.DialConfig(cfg)
	if err != nil {
		t.Fatalf("websocket dial failed: %v", err)
	}
	return conn
}

func readWSEvent(t *testing.T, conn *websocket.Conn) wsEvent {
	t.Helper()
	_ = conn.SetReadDeadline(time.Now().Add(2 * time.Second))

	var payload []byte
	if err := websocket.Message.Receive(conn, &payload); err != nil {
		t.Fatalf("failed to read websocket event: %v", err)
	}

	var event wsEvent
	if err := json.Unmarshal(payload, &event); err != nil {
		t.Fatalf("failed to decode websocket event: %v", err)
	}
	return event
}

func TestRealtimeWSHandshakeRequiresUser(t *testing.T) {
	r := testRouter(t, passThroughAuth(), &fakeActivityService{}, nil)
	req := httptest.NewRequest(http.MethodGet, "/api/v1/ws", nil)
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)

	if w.Code != http.StatusUnauthorized {
		t.Fatalf("expected 401 for unauthenticated websocket handshake, got %d", w.Code)
	}
}

func TestRealtimeWSHandshakeSuccess(t *testing.T) {
	r := testRouter(t, fakeAuthWithUser("11111111-1111-1111-1111-111111111111"), &fakeActivityService{}, nil)
	server := httptest.NewServer(r)
	defer server.Close()

	header := http.Header{}
	header.Set("Authorization", "Bearer test-token")

	conn := dialWS(t, server.URL, header)
	defer conn.Close()

	event := readWSEvent(t, conn)
	if event.Channel != wsChannelStatus || event.Type != "ws.connected" {
		t.Fatalf("unexpected initial event: channel=%s type=%s", event.Channel, event.Type)
	}
}

func TestRealtimeWSRejectsUnknownChannelSubscription(t *testing.T) {
	r := testRouter(t, fakeAuthWithUser("11111111-1111-1111-1111-111111111111"), &fakeActivityService{}, nil)
	server := httptest.NewServer(r)
	defer server.Close()

	conn := dialWS(t, server.URL, nil)
	defer conn.Close()

	_ = readWSEvent(t, conn) // ws.connected

	if err := websocket.JSON.Send(conn, wsClientMessage{
		Action:   "subscribe",
		Channels: []string{"invalid-channel"},
	}); err != nil {
		t.Fatalf("failed to write subscribe message: %v", err)
	}

	event := readWSEvent(t, conn)
	if event.Channel != wsChannelStatus || event.Type != "error" {
		t.Fatalf("expected status error event, got channel=%s type=%s", event.Channel, event.Type)
	}
}

func TestRealtimeWSChannelFiltering(t *testing.T) {
	r, realtime := testRouterWithRealtime(t, fakeAuthWithUser("11111111-1111-1111-1111-111111111111"), &fakeActivityService{}, nil)
	server := httptest.NewServer(r)
	defer server.Close()

	feedConn := dialWS(t, server.URL, nil)
	defer feedConn.Close()
	_ = readWSEvent(t, feedConn) // ws.connected

	statusConn := dialWS(t, server.URL, nil)
	defer statusConn.Close()
	_ = readWSEvent(t, statusConn) // ws.connected

	if err := websocket.JSON.Send(feedConn, wsClientMessage{
		Action:   "subscribe",
		Channels: []string{wsChannelFeed},
	}); err != nil {
		t.Fatalf("feed subscribe failed: %v", err)
	}
	feedAck := readWSEvent(t, feedConn)
	if feedAck.Type != "subscription.updated" {
		t.Fatalf("expected feed subscription ack, got %s", feedAck.Type)
	}

	if err := websocket.JSON.Send(statusConn, wsClientMessage{
		Action:   "subscribe",
		Channels: []string{wsChannelStatus},
	}); err != nil {
		t.Fatalf("status subscribe failed: %v", err)
	}
	statusAck := readWSEvent(t, statusConn)
	if statusAck.Type != "subscription.updated" {
		t.Fatalf("expected status subscription ack, got %s", statusAck.Type)
	}

	realtime.broadcastActivityCreated(Activity{
		ID:         "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
		UserID:     "11111111-1111-1111-1111-111111111111",
		Visibility: "public",
		StartTime:  time.Now().UTC(),
		CreatedAt:  time.Now().UTC(),
	})

	feedEvent := readWSEvent(t, feedConn)
	if feedEvent.Channel != wsChannelFeed || feedEvent.Type != "activity.created" {
		t.Fatalf("expected feed activity.created event, got channel=%s type=%s", feedEvent.Channel, feedEvent.Type)
	}

	_ = statusConn.SetReadDeadline(time.Now().Add(250 * time.Millisecond))
	var payload []byte
	err := websocket.Message.Receive(statusConn, &payload)
	if err == nil {
		t.Fatal("status subscriber should not receive feed events")
	}

	var netErr net.Error
	if !errors.As(err, &netErr) || !netErr.Timeout() {
		t.Fatalf("expected timeout when waiting for unrelated channel event, got %v", err)
	}
}
