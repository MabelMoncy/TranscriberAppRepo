# 🚀 Render.com Deployment Guide

## Prerequisites
- GitHub account (already have: TranscriberAppRepo)
- Render.com account (free tier available)
- Gemini API Key (from https://aistudio.google.com/app/apikey)

---

## Step 1: Prepare Your Repository

Your backend code is ready! The following files have been configured:
- ✅ `render.yaml` - Render configuration
- ✅ `requirements.txt` - Python dependencies
- ✅ `main.py` - FastAPI application

---

## Step 2: Push to GitHub

Make sure your latest code is pushed to GitHub:

```bash
cd d:\TranscriberAppRepo
git add backend/render.yaml backend/.env.example
git commit -m "Add Render.com deployment configuration"
git push origin main
```

---

## Step 3: Deploy on Render.com

### 3.1 Create Account & Connect GitHub
1. Go to https://render.com
2. Sign up with GitHub (recommended)
3. Authorize Render to access your repositories

### 3.2 Create New Web Service
1. Click **"New +"** → **"Web Service"**
2. Select your repository: **TranscriberAppRepo**
3. Render will detect `render.yaml` automatically

### 3.3 Configure Service
- **Name**: `transcriber-backend` (or your choice)
- **Region**: Choose closest to your users (e.g., Oregon, Frankfurt)
- **Branch**: `main`
- **Root Directory**: `backend`
- **Runtime**: Python 3
- **Build Command**: `pip install -r requirements.txt`
- **Start Command**: `uvicorn main:app --host 0.0.0.0 --port $PORT`

### 3.4 Set Environment Variables
In the Render dashboard, add these environment variables:

| Variable | Value | How to Get |
|----------|-------|------------|
| `GEMINI_API_KEY` | Your API key | Get from https://aistudio.google.com/app/apikey |
| `APP_SECRET` | Random secure string | Generate: `python -c "import secrets; print(secrets.token_urlsafe(32))"` |

**Important**: Keep `APP_SECRET` secure! You'll need this in your Flutter app.

### 3.5 Deploy
1. Click **"Create Web Service"**
2. Render will:
   - Clone your repo
   - Install dependencies
   - Start your FastAPI server
   - Provide a public URL (e.g., `https://transcriber-backend.onrender.com`)

---

## Step 4: Test Your Deployment

### Check Health Endpoint
```bash
curl https://your-app.onrender.com/
```

Expected response:
```json
{
  "status": "Online",
  "security": "Enabled"
}
```

### Test Transcription (with your APP_SECRET)
```bash
curl -X POST https://your-app.onrender.com/transcribe \
  -H "X-App-Secret: YOUR_APP_SECRET_HERE" \
  -F "file=@test_audio.mp3"
```

---

## Step 5: Update Your Flutter App

Update the API endpoint in your Flutter app:

```dart
// In your services/transcription_service.dart or similar
const String API_BASE_URL = 'https://your-app.onrender.com';
const String APP_SECRET = 'your_app_secret_from_render';
```

---

## ⚠️ Important Notes

### Free Tier Limitations
- **Spins down after 15 minutes of inactivity**
- **Cold start takes 30-60 seconds** when waking up
- 750 hours/month free (enough for most personal projects)
- Solution: Use UptimeRobot (see UPTIMEROBOT_SETUP.md)

### Upgrade to Paid Plan (Optional)
- **Starter Plan** ($7/month): No spin-down, faster, 512MB RAM
- **Standard Plan** ($25/month): Better performance, 2GB RAM

### Logs & Monitoring
- View logs in Render dashboard: **"Logs"** tab
- Check metrics: **"Metrics"** tab
- Set up email alerts for downtime

---

## Troubleshooting

### Build Fails
- Check `requirements.txt` has all dependencies
- Verify Python version compatibility (3.11+ recommended)

### 503 Service Unavailable
- Check logs for errors
- Verify `GEMINI_API_KEY` is set correctly
- Ensure Gemini API quota isn't exceeded

### 401 Unauthorized
- Verify `APP_SECRET` matches between Render and Flutter app
- Check header name is `X-App-Secret` (case-sensitive)

### Slow Cold Starts
- This is normal for free tier
- Set up UptimeRobot to ping every 5 minutes (see next guide)
- Consider upgrading to paid plan

---

## Next Steps

1. ✅ Deploy to Render
2. 📊 Set up UptimeRobot monitoring (see UPTIMEROBOT_SETUP.md)
3. 📱 Update Flutter app with new API URL
4. 🧪 Test end-to-end functionality
5. 🎉 Launch your app!

---

## Useful Links
- [Render Documentation](https://render.com/docs)
- [Render Status Page](https://status.render.com)
- [Your Render Dashboard](https://dashboard.render.com)
