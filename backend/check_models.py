import google.generativeai as genai
import os
from dotenv import load_dotenv

load_dotenv()
api_key = os.getenv("GEMINI_API_KEY")

if not api_key:
    print("❌ Error: API Key not found in .env")
else:
    genai.configure(api_key=api_key)
    print("🔍 Scanning for available models...\n")
    
    try:
        count = 0
        for m in genai.list_models():
            if 'generateContent' in m.supported_generation_methods:
                print(f"✅ AVAILABLE: {m.name}")
                count += 1
        
        if count == 0:
            print("⚠️ No models found! Your API key might be invalid or has no access.")
            
    except Exception as e:
        print(f"🔥 Error: {e}")