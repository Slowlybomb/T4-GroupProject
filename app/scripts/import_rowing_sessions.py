#!/usr/bin/env python3
"""Import rowing sessions from Flutter assets into activities via API.

This script is intentionally one-off friendly:
- Authenticates as a real user via Supabase password grant.
- Verifies JWT subject matches the expected UID.
- Parses local rowing CSV files, derives aggregate metrics, and posts
  one activity per file.
- Attaches the shared route GeoJSON payload.
"""

from __future__ import annotations

import argparse
import base64
import csv
import json
import math
import os
import sys
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any
from urllib import error, parse, request


DEFAULT_EXPECTED_UID = "c7dd9047-bbac-4d28-a3eb-a877326892ab"
DEFAULT_VISIBILITY = "public"


class ImportErrorWithContext(RuntimeError):
    """Raised when a recoverable import step fails with actionable context."""


@dataclass(frozen=True)
class SessionMetrics:
    duration_seconds: int
    distance_m: float
    avg_stroke_spm: int
    avg_split_500m_seconds: int
    row_count: int


def round_half_up(value: float) -> int:
    return int(math.floor(value + 0.5))


def format_utc(dt: datetime) -> str:
    return dt.astimezone(timezone.utc).replace(microsecond=0).isoformat().replace(
        "+00:00", "Z"
    )


def normalize_url_base(url: str) -> str:
    trimmed = url.strip()
    return trimmed[:-1] if trimmed.endswith("/") else trimmed


def resolve_required(name: str, cli_value: str | None) -> str:
    if cli_value is not None and cli_value.strip():
        return cli_value.strip()

    env_value = os.getenv(name, "").strip()
    if env_value:
        return env_value

    raise ImportErrorWithContext(f"missing required value: {name}")


def decode_jwt_payload(access_token: str) -> dict[str, Any]:
    segments = access_token.split(".")
    if len(segments) != 3:
        raise ImportErrorWithContext("received malformed JWT (expected 3 segments)")

    payload_segment = segments[1]
    padding = "=" * (-len(payload_segment) % 4)
    try:
        decoded = base64.urlsafe_b64decode(payload_segment + padding).decode("utf-8")
        payload = json.loads(decoded)
    except (ValueError, json.JSONDecodeError) as exc:
        raise ImportErrorWithContext(f"failed to decode JWT payload: {exc}") from exc

    if not isinstance(payload, dict):
        raise ImportErrorWithContext("decoded JWT payload is not a JSON object")
    return payload


def request_json(
    *,
    method: str,
    url: str,
    headers: dict[str, str] | None = None,
    body: dict[str, Any] | None = None,
    timeout_seconds: int = 30,
) -> tuple[int, Any]:
    payload: bytes | None = None
    if body is not None:
        payload = json.dumps(body).encode("utf-8")

    req = request.Request(url=url, method=method, data=payload)
    for key, value in (headers or {}).items():
        req.add_header(key, value)

    try:
        with request.urlopen(req, timeout=timeout_seconds) as resp:
            status = resp.status
            raw = resp.read()
    except error.HTTPError as exc:
        status = exc.code
        raw = exc.read()
    except error.URLError as exc:
        raise ImportErrorWithContext(f"network error while calling {url}: {exc}") from exc

    text = raw.decode("utf-8", errors="replace")
    if not text.strip():
        return status, None

    try:
        parsed = json.loads(text)
    except json.JSONDecodeError as exc:
        raise ImportErrorWithContext(
            f"non-JSON response from {url} (status {status}): {text[:200]}"
        ) from exc
    return status, parsed


def authenticate_supabase(
    *,
    supabase_url: str,
    supabase_anon_key: str,
    email: str,
    password: str,
    timeout_seconds: int,
) -> str:
    endpoint = (
        f"{normalize_url_base(supabase_url)}/auth/v1/token"
        f"?{parse.urlencode({'grant_type': 'password'})}"
    )
    status, payload = request_json(
        method="POST",
        url=endpoint,
        headers={
            "apikey": supabase_anon_key,
            "Content-Type": "application/json",
            "Accept": "application/json",
        },
        body={"email": email, "password": password},
        timeout_seconds=timeout_seconds,
    )

    if status < 200 or status >= 300 or not isinstance(payload, dict):
        raise ImportErrorWithContext(
            f"supabase login failed (status {status}): {json.dumps(payload, default=str)}"
        )

    access_token = str(payload.get("access_token", "")).strip()
    if not access_token:
        raise ImportErrorWithContext("supabase login succeeded but access_token missing")

    return access_token


def parse_float_from_row(
    row: dict[str, str], keys: list[str], *, field_name: str, file_name: str, line_no: int
) -> float:
    for key in keys:
        raw = (row.get(key) or "").strip()
        if not raw:
            continue
        try:
            return float(raw)
        except ValueError as exc:
            raise ImportErrorWithContext(
                f"{file_name}:{line_no} invalid {field_name} value '{raw}' for key '{key}'"
            ) from exc

    raise ImportErrorWithContext(
        f"{file_name}:{line_no} missing {field_name}; expected one of {keys}"
    )


def derive_metrics(csv_path: Path) -> SessionMetrics:
    points: list[tuple[float, float]] = []
    with csv_path.open("r", encoding="utf-8", newline="") as handle:
        reader = csv.DictReader(handle)
        if reader.fieldnames is None:
            raise ImportErrorWithContext(f"{csv_path.name}: missing CSV header row")

        for idx, row in enumerate(reader, start=2):
            timestamp_ms = parse_float_from_row(
                row,
                ["stroke_timestamp_ms", "timestamp_ms", "timestamp"],
                field_name="timestamp_ms",
                file_name=csv_path.name,
                line_no=idx,
            )
            distance_m = parse_float_from_row(
                row,
                ["distance_m", "distance"],
                field_name="distance_m",
                file_name=csv_path.name,
                line_no=idx,
            )
            points.append((timestamp_ms, distance_m))

    if len(points) < 2:
        raise ImportErrorWithContext(
            f"{csv_path.name}: expected at least 2 samples, found {len(points)}"
        )

    points.sort(key=lambda pair: pair[0])
    first_ts = points[0][0]
    last_ts = points[-1][0]
    duration_seconds = round_half_up((last_ts - first_ts) / 1000.0)
    if duration_seconds <= 0:
        raise ImportErrorWithContext(
            f"{csv_path.name}: non-positive duration derived ({duration_seconds}s)"
        )

    distance_m = max(pair[1] for pair in points)
    if distance_m <= 0:
        raise ImportErrorWithContext(
            f"{csv_path.name}: non-positive distance derived ({distance_m}m)"
        )

    row_count = len(points)
    avg_stroke_spm = round_half_up(row_count / (duration_seconds / 60.0))
    avg_split_500m_seconds = round_half_up((duration_seconds * 500.0) / distance_m)

    return SessionMetrics(
        duration_seconds=duration_seconds,
        distance_m=distance_m,
        avg_stroke_spm=avg_stroke_spm,
        avg_split_500m_seconds=avg_split_500m_seconds,
        row_count=row_count,
    )


def build_activity_payload(
    *,
    source_file_name: str,
    batch_id: str,
    start_time_utc: datetime,
    visibility: str,
    metrics: SessionMetrics,
    route_geojson: Any,
) -> dict[str, Any]:
    return {
        "title": f"Imported session {source_file_name}",
        "notes": f"import_batch={batch_id}; source={source_file_name}",
        "start_time": format_utc(start_time_utc),
        "duration_seconds": metrics.duration_seconds,
        "distance_m": metrics.distance_m,
        "avg_split_500m_seconds": metrics.avg_split_500m_seconds,
        "avg_stroke_spm": metrics.avg_stroke_spm,
        "visibility": visibility,
        "route_geojson": route_geojson,
    }


def create_activity(
    *,
    api_base_url: str,
    access_token: str,
    payload: dict[str, Any],
    timeout_seconds: int,
) -> dict[str, Any]:
    endpoint = f"{normalize_url_base(api_base_url)}/api/v1/activities"
    status, body = request_json(
        method="POST",
        url=endpoint,
        headers={
            "Authorization": f"Bearer {access_token}",
            "Content-Type": "application/json",
            "Accept": "application/json",
        },
        body=payload,
        timeout_seconds=timeout_seconds,
    )

    if status != 201 or not isinstance(body, dict):
        raise ImportErrorWithContext(
            f"create activity failed (status {status}): {json.dumps(body, default=str)}"
        )
    return body


def verify_feed_contains(
    *,
    api_base_url: str,
    access_token: str,
    expected_titles: list[str],
    timeout_seconds: int,
) -> None:
    endpoint = (
        f"{normalize_url_base(api_base_url)}/api/v1/activities"
        f"?{parse.urlencode({'scope': 'following'})}"
    )
    status, body = request_json(
        method="GET",
        url=endpoint,
        headers={
            "Authorization": f"Bearer {access_token}",
            "Accept": "application/json",
        },
        timeout_seconds=timeout_seconds,
    )
    if status != 200 or not isinstance(body, list):
        raise ImportErrorWithContext(
            f"verification list call failed (status {status}): {json.dumps(body, default=str)}"
        )

    seen_titles = {str(item.get("title", "")).strip() for item in body if isinstance(item, dict)}
    missing = [title for title in expected_titles if title not in seen_titles]
    if missing:
        raise ImportErrorWithContext(
            f"verification failed; missing titles in following feed: {missing}"
        )


def parse_args() -> argparse.Namespace:
    app_root = Path(__file__).resolve().parents[1]
    default_geojson = app_root / "flutter_app" / "assets" / "geojson" / "dummy-training-path.geojson"
    default_csv_dir = app_root / "flutter_app" / "assets" / "rowingdata"

    parser = argparse.ArgumentParser(
        description="Import rowing asset CSV sessions as real activities via API."
    )
    parser.add_argument("--api-base-url", default=None, help="API base URL (or env API_BASE_URL)")
    parser.add_argument("--supabase-url", default=None, help="Supabase URL (or env SUPABASE_URL)")
    parser.add_argument(
        "--supabase-anon-key",
        default=None,
        help="Supabase anon key (or env SUPABASE_ANON_KEY)",
    )
    parser.add_argument("--email", default=None, help="Login email (or env IMPORT_EMAIL)")
    parser.add_argument("--password", default=None, help="Login password (or env IMPORT_PASSWORD)")
    parser.add_argument(
        "--expected-uid",
        default=os.getenv("EXPECTED_UID", DEFAULT_EXPECTED_UID),
        help=f"Expected JWT sub (default: {DEFAULT_EXPECTED_UID}, overridable by EXPECTED_UID)",
    )
    parser.add_argument(
        "--csv-dir",
        type=Path,
        default=default_csv_dir,
        help=f"CSV folder (default: {default_csv_dir})",
    )
    parser.add_argument(
        "--geojson-path",
        type=Path,
        default=default_geojson,
        help=f"Route GeoJSON path (default: {default_geojson})",
    )
    parser.add_argument(
        "--visibility",
        default=DEFAULT_VISIBILITY,
        choices=["public", "followers", "private"],
        help=f"Activity visibility (default: {DEFAULT_VISIBILITY})",
    )
    parser.add_argument(
        "--timeout-seconds",
        type=int,
        default=30,
        help="HTTP timeout in seconds (default: 30)",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Parse/derive payloads only; do not call Supabase/API",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()

    csv_dir = args.csv_dir.resolve()
    geojson_path = args.geojson_path.resolve()
    if not csv_dir.is_dir():
        raise ImportErrorWithContext(f"csv directory not found: {csv_dir}")
    if not geojson_path.is_file():
        raise ImportErrorWithContext(f"geojson file not found: {geojson_path}")

    csv_files = sorted(csv_dir.glob("*.csv"), key=lambda path: path.name)
    if len(csv_files) != 4:
        raise ImportErrorWithContext(
            f"expected exactly 4 csv files in {csv_dir}, found {len(csv_files)}"
        )

    with geojson_path.open("r", encoding="utf-8") as handle:
        route_geojson = json.load(handle)

    now_utc = datetime.now(timezone.utc)
    batch_id = now_utc.strftime("%Y%m%dT%H%M%SZ")
    total = len(csv_files)

    payloads: list[dict[str, Any]] = []
    for index, csv_file in enumerate(csv_files):
        metrics = derive_metrics(csv_file)
        days_ago = (total - 1) - index
        start_time = now_utc - timedelta(days=days_ago)
        payload = build_activity_payload(
            source_file_name=csv_file.name,
            batch_id=batch_id,
            start_time_utc=start_time,
            visibility=args.visibility,
            metrics=metrics,
            route_geojson=route_geojson,
        )
        payloads.append(payload)

        print(
            f"prepared {csv_file.name}: duration={metrics.duration_seconds}s, "
            f"distance={metrics.distance_m:.1f}m, spm={metrics.avg_stroke_spm}, "
            f"split500={metrics.avg_split_500m_seconds}s, start_time={payload['start_time']}"
        )

    if args.dry_run:
        print("dry-run complete; no network requests were made.")
        return 0

    api_base_url = resolve_required("API_BASE_URL", args.api_base_url)
    supabase_url = resolve_required("SUPABASE_URL", args.supabase_url)
    supabase_anon_key = resolve_required("SUPABASE_ANON_KEY", args.supabase_anon_key)
    email = resolve_required("IMPORT_EMAIL", args.email)
    password = resolve_required("IMPORT_PASSWORD", args.password)

    access_token = authenticate_supabase(
        supabase_url=supabase_url,
        supabase_anon_key=supabase_anon_key,
        email=email,
        password=password,
        timeout_seconds=args.timeout_seconds,
    )
    claims = decode_jwt_payload(access_token)
    subject = str(claims.get("sub", "")).strip()
    if subject != args.expected_uid:
        raise ImportErrorWithContext(
            f"uid mismatch: expected {args.expected_uid}, got {subject or '<empty>'}"
        )
    print(f"authenticated as expected uid: {subject}")

    expected_titles: list[str] = []
    for payload in payloads:
        created = create_activity(
            api_base_url=api_base_url,
            access_token=access_token,
            payload=payload,
            timeout_seconds=args.timeout_seconds,
        )
        title = str(created.get("title", "")).strip()
        created_id = str(created.get("id", "")).strip()
        created_user_id = str(created.get("user_id", "")).strip()
        if created_user_id != args.expected_uid:
            raise ImportErrorWithContext(
                f"created activity user_id mismatch for '{title}': "
                f"expected {args.expected_uid}, got {created_user_id or '<empty>'}"
            )
        expected_titles.append(title)
        print(f"created activity: id={created_id}, title={title}")

    verify_feed_contains(
        api_base_url=api_base_url,
        access_token=access_token,
        expected_titles=expected_titles,
        timeout_seconds=args.timeout_seconds,
    )
    print("verification passed: all imported titles visible in scope=following feed")
    print(
        f"import complete: {len(expected_titles)} activities, "
        f"import_batch={batch_id}, visibility={args.visibility}"
    )
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except ImportErrorWithContext as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        sys.exit(1)
