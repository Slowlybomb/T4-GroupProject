package main

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/gin-gonic/gin"
)

type fakeActivityService struct {
	listFn   func(ctx context.Context, userID string) ([]Activity, error)
	createFn func(ctx context.Context, userID string, req CreateActivityRequest) (Activity, error)
	getFn    func(ctx context.Context, userID, activityID string) (Activity, bool, error)
	likeFn   func(ctx context.Context, userID, activityID string) (Activity, bool, error)
}

type fakeStorageSigner struct {
	createSignedUploadURLFn   func(ctx context.Context, bucket, objectPath string, expiresIn time.Duration) (string, error)
	createSignedDownloadURLFn func(ctx context.Context, bucket, objectPath string, expiresIn time.Duration) (string, error)
}

func (f *fakeActivityService) list(ctx context.Context, userID string) ([]Activity, error) {
	if f.listFn != nil {
		return f.listFn(ctx, userID)
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
	gin.SetMode(gin.TestMode)
	r := gin.New()
	r.Use(gin.Recovery())
	r.Use(requestLogger())
	registerRoutes(r, authMiddleware, store, signer)
	return r
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
		listFn: func(ctx context.Context, userID string) ([]Activity, error) {
			if userID != wantUserID {
				t.Fatalf("expected userID %s, got %s", wantUserID, userID)
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
