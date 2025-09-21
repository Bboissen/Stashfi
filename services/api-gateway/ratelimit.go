package main

import (
	"sync"
	"time"
)

type rateLimiter struct {
	rps   float64
	burst float64
	store sync.Map // key -> *bucket
}

type bucket struct {
	mu       sync.Mutex
	tokens   float64
	last     time.Time
	rps      float64
	capacity float64
}

func newRateLimiter(rps float64, burst int) *rateLimiter {
	if rps <= 0 {
		rps = 10
	}
	if burst <= 0 {
		burst = 20
	}
	return &rateLimiter{rps: rps, burst: float64(burst)}
}

func (rl *rateLimiter) getBucket(key string) *bucket {
	if b, ok := rl.store.Load(key); ok {
		return b.(*bucket)
	}
	b := &bucket{tokens: rl.burst, last: time.Now(), rps: rl.rps, capacity: rl.burst}
	actual, _ := rl.store.LoadOrStore(key, b)
	return actual.(*bucket)
}

func (rl *rateLimiter) Allow(key string) bool {
	b := rl.getBucket(key)
	b.mu.Lock()
	defer b.mu.Unlock()

	now := time.Now()
	elapsed := now.Sub(b.last).Seconds()
	b.last = now

	// Refill tokens
	b.tokens += elapsed * b.rps
	if b.tokens > b.capacity {
		b.tokens = b.capacity
	}
	if b.tokens >= 1.0 {
		b.tokens -= 1.0
		return true
	}
	return false
}
