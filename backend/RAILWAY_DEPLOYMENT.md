# Deploy Backend to Railway.app (Free)

## Step 1: Push Code to GitHub

```powershell
# Navigate to your repo
cd D:\TranscriberAppRepo

# Check git status
git status

# Add all backend files
git add backend/

# Commit
git commit -m "Prepare backend for Railway deployment"

# Push to GitHub
git push origin main
```

## Step 2: Deploy on Railway

1. **Go to:** https://railway.app
2. **Sign up** with your GitHub account
3. **Click:** "New Project"
4. **Select:** "Deploy from GitHub repo"
5. **Choose:** `TranscriberAppRepo`
6. **Root Directory:** Click "Settings" → Set root directory to `backend`
7. **Click:** "Deploy Now"

## Step 3: Add Environment Variables

In Railway dashboard:

1. Go to your project
2. Click **"Variables"** tab
3. Add these variables:

```
GEMINI_API_KEY=AIzaSyD53A3bgIulJQw8iK_lP54vaCZHrncaf-c
APP_SECRET=fd612e7e29c48edd0622c12e9462535ea80bea2ac8f1892fe8e421e5b68a01f8
```

4. Click **"Save"**

## Step 4: Get Your Backend URL

1. Go to **"Settings"** tab
2. Scroll to **"Domains"**
3. Click **"Generate Domain"**
4. Copy your URL: `https://your-app.up.railway.app`

## Step 5: Update Flutter App

Update `transcriberapp/.env`:

```
SERVER_URL=https://your-app.up.railway.app
API_SECRET=fd612e7e29c48edd0622c12e9462535ea80bea2ac8f1892fe8e421e5b68a01f8
```

## Step 6: Test Your Live Backend

```powershell
# Test in browser or PowerShell
curl https://your-app.up.railway.app
```

Should return: `{"status":"Online","security":"Enabled"}`

## Troubleshooting

### If deployment fails:

1. Check **"Deployments"** tab → Click failed deployment → View logs
2. Common issues:
   - Missing `requirements.txt` ✅ (Already created)
   - Wrong Python version ✅ (Fixed with runtime.txt)
   - Missing environment variables → Add in Railway dashboard

### If app crashes:

Check **"Logs"** tab in Railway for error messages.

## Cost Monitoring

- Go to **"Usage"** tab to see your credit usage
- $5 free credits/month
- Average usage: ~$3-4/month for small apps

## Next Steps After Deployment

1. ✅ Backend live 24/7
2. Update Flutter app with new URL
3. Rebuild and test app
4. Deploy to Play Store with live backend!

---

**Estimated deployment time: 10 minutes**
