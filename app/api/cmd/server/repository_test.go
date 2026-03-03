package main

import (
	"database/sql"
	"errors"
	"fmt"
	"reflect"
	"testing"
	"time"
)

type fakeScanner struct {
	values []any
	err    error
}

func (f fakeScanner) Scan(dest ...any) error {
	if f.err != nil {
		return f.err
	}
	if len(dest) != len(f.values) {
		return fmt.Errorf("scan destination mismatch: got %d want %d", len(dest), len(f.values))
	}

	for i := range dest {
		dstVal := reflect.ValueOf(dest[i])
		if dstVal.Kind() != reflect.Pointer || dstVal.IsNil() {
			return fmt.Errorf("dest[%d] is not a pointer", i)
		}

		srcVal := reflect.ValueOf(f.values[i])
		target := dstVal.Elem()
		if !srcVal.IsValid() {
			target.Set(reflect.Zero(target.Type()))
			continue
		}

		if srcVal.Type().AssignableTo(target.Type()) {
			target.Set(srcVal)
			continue
		}
		if srcVal.Type().ConvertibleTo(target.Type()) {
			target.Set(srcVal.Convert(target.Type()))
			continue
		}

		return fmt.Errorf("cannot assign %s to %s", srcVal.Type(), target.Type())
	}

	return nil
}

func TestReadDatabaseURLFromEnv(t *testing.T) {
	t.Run("prefer DATABASE_URL over DB_URL", func(t *testing.T) {
		t.Setenv("DATABASE_URL", "postgres://from-database-url")
		t.Setenv("DB_URL", "postgres://from-db-url")

		got, err := readDatabaseURLFromEnv()
		if err != nil {
			t.Fatalf("unexpected error: %v", err)
		}
		if got != "postgres://from-database-url" {
			t.Fatalf("expected DATABASE_URL, got %q", got)
		}
	})

	t.Run("fall back to DB_URL", func(t *testing.T) {
		t.Setenv("DATABASE_URL", "")
		t.Setenv("DB_URL", "postgres://from-db-url")

		got, err := readDatabaseURLFromEnv()
		if err != nil {
			t.Fatalf("unexpected error: %v", err)
		}
		if got != "postgres://from-db-url" {
			t.Fatalf("expected DB_URL, got %q", got)
		}
	})

	t.Run("error when both are missing", func(t *testing.T) {
		t.Setenv("DATABASE_URL", "")
		t.Setenv("DB_URL", "")

		_, err := readDatabaseURLFromEnv()
		if err == nil {
			t.Fatal("expected error when no DB env var is set")
		}
	})
}

func TestScanActivityPopulatedFields(t *testing.T) {
	start := time.Date(2026, 1, 1, 10, 0, 0, 0, time.UTC)
	created := start.Add(5 * time.Minute)

	row := fakeScanner{
		values: []any{
			"aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
			"bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb",
			sql.NullString{String: "hugo", Valid: true},
			sql.NullString{String: "Hugo", Valid: true},
			sql.NullString{String: "https://example.com/avatar.png", Valid: true},
			sql.NullString{String: "Morning row", Valid: true},
			sql.NullString{String: "Strong headwind", Valid: true},
			start,
			sql.NullInt32{Int32: 3600, Valid: true},
			sql.NullFloat64{Float64: 10000.5, Valid: true},
			sql.NullInt32{Int32: 121, Valid: true},
			sql.NullInt16{Int16: 28, Valid: true},
			"public",
			sql.NullString{String: "cccccccc-cccc-cccc-cccc-cccccccccccc", Valid: true},
			[]byte(`{"type":"LineString","coordinates":[[0,0],[1,1]]}`),
			created,
			int32(3),
			int32(2),
		},
	}

	activity, err := scanActivity(row)
	if err != nil {
		t.Fatalf("unexpected scan error: %v", err)
	}

	if activity.ID == "" || activity.UserID == "" {
		t.Fatal("expected non-empty id and user_id")
	}
	if activity.Username == nil || *activity.Username != "hugo" {
		t.Fatalf("unexpected username: %#v", activity.Username)
	}
	if activity.DisplayName == nil || *activity.DisplayName != "Hugo" {
		t.Fatalf("unexpected display name: %#v", activity.DisplayName)
	}
	if activity.AvatarURL == nil || *activity.AvatarURL == "" {
		t.Fatalf("unexpected avatar url: %#v", activity.AvatarURL)
	}
	if activity.Title == nil || *activity.Title != "Morning row" {
		t.Fatalf("unexpected title: %#v", activity.Title)
	}
	if activity.DurationSeconds == nil || *activity.DurationSeconds != 3600 {
		t.Fatalf("unexpected duration: %#v", activity.DurationSeconds)
	}
	if activity.DistanceM == nil || *activity.DistanceM != 10000.5 {
		t.Fatalf("unexpected distance: %#v", activity.DistanceM)
	}
	if activity.AvgStrokeSPM == nil || *activity.AvgStrokeSPM != 28 {
		t.Fatalf("unexpected stroke spm: %#v", activity.AvgStrokeSPM)
	}
	if activity.TeamID == nil || *activity.TeamID == "" {
		t.Fatalf("expected team id, got %#v", activity.TeamID)
	}
	if len(activity.RouteGeoJSON) == 0 {
		t.Fatal("expected non-empty route geojson")
	}
	if activity.Likes != 3 || activity.Comments != 2 {
		t.Fatalf("unexpected counters likes=%d comments=%d", activity.Likes, activity.Comments)
	}
}

func TestScanActivityNullOptionalFields(t *testing.T) {
	start := time.Date(2026, 1, 1, 10, 0, 0, 0, time.UTC)
	created := start.Add(5 * time.Minute)

	row := fakeScanner{
		values: []any{
			"aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
			"bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb",
			sql.NullString{Valid: false},
			sql.NullString{Valid: false},
			sql.NullString{Valid: false},
			sql.NullString{Valid: false},
			sql.NullString{Valid: false},
			start,
			sql.NullInt32{Valid: false},
			sql.NullFloat64{Valid: false},
			sql.NullInt32{Valid: false},
			sql.NullInt16{Valid: false},
			"private",
			sql.NullString{Valid: false},
			[]byte(nil),
			created,
			int32(0),
			int32(0),
		},
	}

	activity, err := scanActivity(row)
	if err != nil {
		t.Fatalf("unexpected scan error: %v", err)
	}

	if activity.Title != nil || activity.Notes != nil {
		t.Fatal("expected nil title/notes for NULL DB values")
	}
	if activity.Username != nil || activity.DisplayName != nil || activity.AvatarURL != nil {
		t.Fatal("expected nil profile fields for NULL DB values")
	}
	if activity.DurationSeconds != nil || activity.DistanceM != nil {
		t.Fatal("expected nil numeric pointers for NULL DB values")
	}
	if activity.TeamID != nil {
		t.Fatal("expected nil team_id for NULL DB value")
	}
	if len(activity.RouteGeoJSON) != 0 {
		t.Fatal("expected empty route geojson for NULL DB value")
	}
}

func TestScanActivityPropagatesScanError(t *testing.T) {
	_, err := scanActivity(fakeScanner{err: errors.New("scan failed")})
	if err == nil {
		t.Fatal("expected scan error to be returned")
	}
}
