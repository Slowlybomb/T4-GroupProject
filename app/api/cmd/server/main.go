package main

import (
	"net/http"
	"strconv"
	"time"
	"context"
	"log"
	"os"
	"github.com/jackc/pgx/v5/pgxpool"
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

type CreateActivityRequest struct {
	User    string `json:"user" binding:"required,min=2"`
	Title   string `json:"title" binding:"required,min=3"`
	Type    string `json:"type" binding:"required,oneof=run walk gym cycle"`
	Minutes int    `json:"minutes" binding:"required,gte=1,lte=600"`
}

func main() {
	r := gin.New()
	r.Use(gin.Recovery())
	r.Use(requestLogger())

	api := r.Group("/api/v1")
	{
		api.GET("/health", func(c *gin.Context) {
			c.JSON(http.StatusOK, gin.H{
				"status": "ok",
				"time":   time.Now().UTC().Format(time.RFC3339),
			})
		})

		store := newActivityStore()

		api.GET("/activities", func(c *gin.Context) {
			c.JSON(http.StatusOK, store.list())
		})

		api.POST("/activities", func(c *gin.Context) {
			var req CreateActivityRequest
			if err := c.ShouldBindJSON(&req); err != nil {
				c.JSON(http.StatusBadRequest, gin.H{
					"error":   "invalid request body",
					"details": err.Error(),
				})
				return
			}

			a := store.create(req.User, req.Title, req.Type, req.Minutes)
			c.JSON(http.StatusCreated, a)
		})

		api.GET("/activities/:id", func(c *gin.Context) {
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

		api.PATCH("/activities/:id/like", func(c *gin.Context) {
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

	r.Run(":8080")
}

func parseID(raw string) (int, bool) {
	id, err := strconv.Atoi(raw)
	if err != nil || id <= 0 {
		return 0, false
	}
	return id, true
}

func requestLogger() gin.HandlerFunc {
	return func(c *gin.Context) {
		start := time.Now()
		c.Next()
		latency := time.Since(start)

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
