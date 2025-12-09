# 📊 UptimeRobot Setup Guide

## Why UptimeRobot?

Render's free tier **spins down after 15 minutes of inactivity**, causing:
- 30-60 second cold starts for users
- Poor user experience
- Wasted time waiting

**Solution**: UptimeRobot pings your API every 5 minutes to keep it awake! 🎯

---

## Step 1: Create UptimeRobot Account

1. Go to https://uptimerobot.com
2. Click **"Sign Up Free"**
3. Use your email or sign in with Google
4. Free tier includes:
   - ✅ 50 monitors
   - ✅ 5-minute check intervals
   - ✅ Email alerts
   - ✅ No credit card required

---

## Step 2: Add Your Monitor

### 2.1 Create New Monitor
1. Log into UptimeRobot dashboard
2. Click **"+ Add New Monitor"**

### 2.2 Configure Monitor Settings

Fill in the following details:

| Field | Value | Notes |
|-------|-------|-------|
| **Monitor Type** | HTTP(s) | Default option |
| **Friendly Name** | `Transcriber Backend` | Any name you prefer |
| **URL** | `https://your-app.onrender.com/` | Your Render URL with trailing `/` |
| **Monitoring Interval** | `5 minutes` | Free tier default (perfect!) |
| **Monitor Timeout** | `30 seconds` | Default is fine |
| **HTTP Method** | `GET` | Default |

### 2.3 Alert Settings (Optional)
- Enable email alerts for downtime
- Get notified if your API goes down
- Free tier includes email notifications

### 2.4 Save Monitor
Click **"Create Monitor"** 

---

## Step 3: Verify It's Working

### Check Monitor Status
1. Go to your UptimeRobot dashboard
2. You should see your monitor with:
   - 🟢 Green "Up" status
   - Response time (usually 100-500ms)
   - Uptime percentage

### Check Render Logs
1. Open your Render dashboard
2. Go to your service → **"Logs"** tab
3. You should see GET requests every 5 minutes:
   ```
   INFO:     127.0.0.1:xxxxx - "GET / HTTP/1.1" 200 OK
   ```

---

## Step 4: Advanced Configuration (Optional)

### Add Health Check Monitoring
Instead of just pinging `/`, you can verify your API is truly healthy:

1. Edit your monitor in UptimeRobot
2. Under **"Advanced Settings"**:
   - **Keyword**: Add `Online` (checks if response contains this word)
   - This ensures your API isn't just returning 200 but actually working

### Multiple Endpoints
Free tier allows 50 monitors! You can add:
- Main health check: `/`
- Transcription test: `/transcribe` (GET, should return 405 Method Not Allowed)

### Status Page (Optional)
- Create a public status page
- Share with users: `https://stats.uptimerobot.com/xxxxx`
- Shows real-time uptime statistics

---

## Expected Behavior

### Before UptimeRobot
- First request after 15+ min idle: **30-60 seconds** (cold start)
- User sees: Loading... Loading... Loading... 😴

### After UptimeRobot
- API pinged every 5 minutes
- Stays warm 24/7
- User sees: **Instant response** ⚡

### Response Times
- **Warm API**: 100-500ms
- **Cold start**: 30,000-60,000ms (30-60 sec)
- **Savings**: 60x - 600x faster! 🚀

---

## Cost Breakdown

| Service | Free Tier | Limitations |
|---------|-----------|-------------|
| **Render** | 750 hrs/month | Spins down after 15 min idle |
| **UptimeRobot** | 50 monitors, 5 min interval | Perfect for keeping Render awake |
| **Total Cost** | **$0/month** 🎉 | Good for MVP/testing |

### When to Upgrade?

#### Render Paid Plan ($7/month)
- No spin-down
- Always instant
- Better performance
- **Don't need UptimeRobot anymore!**

#### UptimeRobot Pro ($7/month)
- 1-minute check intervals
- SMS alerts
- More monitors
- **Only if staying on Render free tier**

---

## Troubleshooting

### Monitor Shows "Down"
1. Check your Render URL is correct
2. Verify your app is deployed successfully
3. Test manually: Open URL in browser
4. Check Render logs for errors

### API Still Cold Starts
1. Verify monitor is actually pinging (check Render logs)
2. Make sure interval is 5 minutes (not longer)
3. Check UptimeRobot shows "Up" status

### Too Many Requests / Rate Limiting
- 5-minute intervals are safe
- Don't set multiple monitors to same endpoint
- Render free tier has no request limits for this usage

---

## Alternative Solutions

If you don't want to use UptimeRobot:

### 1. Cron-job.org
- Free HTTP pings
- Similar to UptimeRobot
- Website: https://cron-job.org

### 2. GitHub Actions
- Free for public repos
- Run scheduled workflow to ping API
- More complex setup

### 3. Your Own Cron Job
- If you have a VPS/server
- `curl https://your-app.onrender.com/` every 5 minutes

### 4. Upgrade to Render Paid ($7/month)
- **Best solution for production**
- No external dependencies
- Always instant
- Better performance

---

## Monitoring Dashboard Tips

### UptimeRobot Dashboard
- **Daily uptime**: Should be 99%+
- **Average response time**: 100-500ms
- **Down events**: Investigate immediately

### Render Dashboard
- **Logs**: Check for errors
- **Metrics**: CPU/Memory usage
- **Events**: Deployment history

---

## Final Checklist

Before going live:

- [ ] Render deployment successful
- [ ] UptimeRobot monitor created
- [ ] Monitor shows "Up" status
- [ ] Check Render logs for ping requests
- [ ] Test API manually (curl or browser)
- [ ] Update Flutter app with production URL
- [ ] Test end-to-end from mobile app
- [ ] Set up email alerts in UptimeRobot
- [ ] Bookmark both dashboards
- [ ] Share status page (optional)

---

## Next Steps

1. ✅ Set up UptimeRobot monitoring
2. 📱 Update Flutter app with Render URL
3. 🧪 Test transcription from mobile device
4. 📈 Monitor uptime and response times
5. 🎉 Launch your app!

When you're ready to scale:
- Upgrade Render to Starter plan ($7/month)
- Remove UptimeRobot (no longer needed)
- Enjoy instant responses 24/7

---

## Support & Resources

- [UptimeRobot Documentation](https://uptimerobot.com/help/)
- [UptimeRobot API](https://uptimerobot.com/api/) (for automation)
- [Render + UptimeRobot Guide](https://render.com/docs/free#free-web-services)

**Questions?** Check Render and UptimeRobot support forums!
