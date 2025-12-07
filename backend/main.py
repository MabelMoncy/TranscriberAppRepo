'''import os
import shutil
import asyncio
import google.generativeai as genai
from fastapi import FastAPI, UploadFile, File, HTTPException
from dotenv import load_dotenv

# 1. Load Secrets
load_dotenv()
API_KEY = os.getenv("GEMINI_API_KEY")

if not API_KEY:
    raise ValueError("No API Key found! Please check your .env file.")

genai.configure(api_key=API_KEY)

# 2. Define Model Names
# NOTE: Ensure these are the exact names available to your API key.
# If "gemini-3-pro-preview" fails, try "gemini-1.5-pro"
PRIMARY_NAME = "gemini-2.5-pro" 
BACKUP_NAME = "gemini-2.5-flash"

print(f"🔌 Initializing Models...")
primary_model = genai.GenerativeModel(PRIMARY_NAME)
backup_model = genai.GenerativeModel(BACKUP_NAME)
print(f"✅ Models Ready: Primary=[{PRIMARY_NAME}], Backup=[{BACKUP_NAME}]")

app = FastAPI()

async def transcribe_with_fallback(audio_path: str, mime_type: str):
    """
    Tries Primary Model. If Overloaded, immediately switches to Backup Model.
    """
    
    # --- ATTEMPT 1: PRIMARY MODEL ---
    try:
        print(f"⚡ Trying Primary Model ({PRIMARY_NAME})...")
        
        # Upload to Google (This happens once per model interaction ideally, 
        # but for simplicity we upload for the specific call)
        gemini_file = genai.upload_file(path=audio_path, mime_type=mime_type)
        
        prompt = "Transcribe this audio exactly word-for-word."
        
        # Try to generate
        response = primary_model.generate_content([gemini_file, prompt])
        return {"text": response.text, "model": PRIMARY_NAME}

    except Exception as e:
        error_msg = str(e)
        print(f"⚠️ Primary Model Failed: {error_msg}")

        # Check if it is an Overload/Availability error
        if "503" in error_msg or "429" in error_msg or "Overloaded" in error_msg:
            print(f"🔄 SWITCHING TO BACKUP MODEL ({BACKUP_NAME})...")
            
            # --- ATTEMPT 2: BACKUP MODEL ---
            try:
                # We need to re-upload or re-use the file. 
                # To be safe and simple, we re-upload for the backup model context.
                gemini_file_backup = genai.upload_file(path=audio_path, mime_type=mime_type)
                
                response = backup_model.generate_content([gemini_file_backup, prompt])
                return {"text": response.text, "model": BACKUP_NAME}
            
            except Exception as e2:
                print(f"❌ Backup Model Also Failed: {e2}")
                raise HTTPException(status_code=503, detail="All models are busy. Please try again later.")
        
        else:
            # If it's not an overload error (e.g., Invalid File), fail immediately.
            raise e

@app.post("/transcribe")
async def handle_transcription(file: UploadFile = File(...)):
    
    if not file.content_type.startswith("audio/"):
        return {"status": "error", "message": "Invalid file type."}

    upload_folder = "temp_processing"
    os.makedirs(upload_folder, exist_ok=True)
    safe_filename = file.filename.replace(" ", "_")
    file_path = f"{upload_folder}/{safe_filename}"
    
    try:
        with open(file_path, "wb+") as buffer:
            shutil.copyfileobj(file.file, buffer)

        # Call the new Fallback Logic
        result = await transcribe_with_fallback(file_path, file.content_type)
        
        return {
            "status": "success",
            "transcription": result["text"],
            "model_used": result["model"] # Shows you which model did the job
        }

    except Exception as e:
        return {"status": "error", "message": str(e)}
        
    finally:
        if os.path.exists(file_path):
            os.remove(file_path)
            print(f"🧹 Cleaned up temp file")'''
import os
import shutil
import asyncio
import google.generativeai as genai
from fastapi import FastAPI, UploadFile, File, HTTPException
from dotenv import load_dotenv

# 1. Load Secrets
load_dotenv()
API_KEY = os.getenv("GEMINI_API_KEY")

if not API_KEY:
    raise ValueError("No API Key found! Please check your .env file.")

genai.configure(api_key=API_KEY)

# 2. Define Model Hierarchy (The Cascade)
PRIMARY_NAME = "gemini-2.5-pro"
SECONDARY_NAME = "gemini-2.5-flash"
TERTIARY_NAME = "gemini-2.5-flash-lite"

print(f"🔌 Initializing Models...")
primary_model = genai.GenerativeModel(PRIMARY_NAME)
secondary_model = genai.GenerativeModel(SECONDARY_NAME)
tertiary_model = genai.GenerativeModel(TERTIARY_NAME)
print(f"✅ Models Ready: [1]{PRIMARY_NAME} -> [2]{SECONDARY_NAME} -> [3]{TERTIARY_NAME}")

app = FastAPI()

async def transcribe_cascade(audio_path: str, mime_type: str):
    """
    Tries models in order: Primary -> Secondary -> Tertiary.
    Fails only if ALL three are overloaded/broken.
    """
    
    prompt = "Transcribe this audio exactly word-for-word."

    # --- LEVEL 1: PRIMARY (PRO) ---
    try:
        print(f"⚡ Trying LEVEL 1 ({PRIMARY_NAME})...")
        file_1 = genai.upload_file(path=audio_path, mime_type=mime_type)
        response = primary_model.generate_content([file_1, prompt])
        return {"text": response.text, "model": PRIMARY_NAME}

    except Exception as e:
        print(f"⚠️ Level 1 Failed: {e}")
        # Only switch if it's an availability issue (Overloaded/Not Found)
        if not ("503" in str(e) or "429" in str(e) or "404" in str(e) or "Overloaded" in str(e)):
            raise e # If it's a logic error (bad file), fail here.

        # --- LEVEL 2: SECONDARY (FLASH) ---
        print(f"🔄 Switching to LEVEL 2 ({SECONDARY_NAME})...")
        try:
            file_2 = genai.upload_file(path=audio_path, mime_type=mime_type)
            response = secondary_model.generate_content([file_2, prompt])
            return {"text": response.text, "model": SECONDARY_NAME}

        except Exception as e2:
            print(f"⚠️ Level 2 Failed: {e2}")
            
            # --- LEVEL 3: TERTIARY (FLASH-LITE) ---
            print(f"🛡️ Switching to LEVEL 3 ({TERTIARY_NAME})...")
            try:
                file_3 = genai.upload_file(path=audio_path, mime_type=mime_type)
                response = tertiary_model.generate_content([file_3, prompt])
                return {"text": response.text, "model": TERTIARY_NAME}
            
            except Exception as e3:
                print(f"❌ CRITICAL: All 3 levels failed.")
                raise HTTPException(status_code=503, detail="System Overloaded. Please try again later.")

@app.get("/")
async def root():
    return {"message": "Transcriber Backend with Triple-Fallback is Running 🚀"}

@app.post("/transcribe")
async def handle_transcription(file: UploadFile = File(...)):
    
    if not file.content_type.startswith("audio/"):
        return {"status": "error", "message": "Invalid file type."}

    upload_folder = "temp_processing"
    os.makedirs(upload_folder, exist_ok=True)
    safe_filename = file.filename.replace(" ", "_")
    file_path = f"{upload_folder}/{safe_filename}"
    
    try:
        with open(file_path, "wb+") as buffer:
            shutil.copyfileobj(file.file, buffer)

        # Use the new Cascade Function
        result = await transcribe_cascade(file_path, file.content_type)
        
        return {
            "status": "success",
            "transcription": result["text"],
            "model_used": result["model"]
        }

    except Exception as e:
        return {"status": "error", "message": str(e)}
        
    finally:
        if os.path.exists(file_path):
            os.remove(file_path)
            print(f"🧹 Cleaned up temp file")