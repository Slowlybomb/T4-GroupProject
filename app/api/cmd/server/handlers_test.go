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

func testRouter(t *testing.T, authMiddleware gin.HandlerFunc, store activityService) *gin.Engine {
	t.Helper()
	gin.SetMode(gin.TestMode)
	r := gin.New()
	r.Use(gin.Recovery())
	r.Use(requestLogger())
	registerRoutes(r, authMiddleware, store)
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
	r := testRouter(t, passThroughAuth(), &fakeActivityService{})

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
	r := testRouter(t, passThroughAuth(), &fakeActivityService{})

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

	r := testRouter(t, fakeAuthWithUser(wantUserID), store)
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
	r := testRouter(t, fakeAuthWithUser("11111111-1111-1111-1111-111111111111"), &fakeActivityService{})

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

	r := testRouter(t, fakeAuthWithUser(userID), store)
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
	r := testRouter(t, fakeAuthWithUser("11111111-1111-1111-1111-111111111111"), &fakeActivityService{})

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
	r := testRouter(t, fakeAuthWithUser("11111111-1111-1111-1111-111111111111"), store)

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
	r := testRouter(t, fakeAuthWithUser("11111111-1111-1111-1111-111111111111"), store)

	req := httptest.NewRequest(http.MethodPatch, "/api/v1/activities/aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa/like", nil)
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)

	if w.Code != http.StatusInternalServerError {
		t.Fatalf("expected 500, got %d", w.Code)
	}
}
