"""
Rate Limiter for Free Tier Gemini API
Queues requests when limits are hit and retries automatically
"""
import asyncio
import time
from datetime import datetime, timedelta
from collections import defaultdict

class RateLimiter:
    def __init__(self):
        self.request_counts = defaultdict(int)  # model -> count
        self.reset_times = {}  # model -> reset timestamp
        
        # Free tier limits (requests per day)
        self.limits = {
            "gemini-2.5-pro": 10,
            "gemini-2.5-flash": 20,
            "gemini-2.5-flash-lite": 50
        }
    
    async def wait_if_needed(self, model_name: str):
        """
        Check if we've hit the limit, if so wait until reset
        """
        # Reset counter if it's a new day
        now = datetime.now()
        if model_name in self.reset_times:
            if now > self.reset_times[model_name]:
                self.request_counts[model_name] = 0
                self.reset_times[model_name] = now + timedelta(days=1)
        else:
            self.reset_times[model_name] = now + timedelta(days=1)
        
        # Check limit
        if self.request_counts[model_name] >= self.limits.get(model_name, 10):
            wait_seconds = (self.reset_times[model_name] - now).total_seconds()
            if wait_seconds > 0:
                print(f"⏳ Rate limit hit for {model_name}. Waiting {wait_seconds:.0f}s...")
                await asyncio.sleep(wait_seconds)
                self.request_counts[model_name] = 0
        
        # Increment counter
        self.request_counts[model_name] += 1
    
    def get_remaining(self, model_name: str) -> int:
        """Get remaining requests for a model"""
        limit = self.limits.get(model_name, 10)
        used = self.request_counts[model_name]
        return max(0, limit - used)

# Global instance
rate_limiter = RateLimiter()
