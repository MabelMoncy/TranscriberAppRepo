import os
import shutil
import asyncio
import logging
import google.generativeai as genai
from fastapi import FastAPI, UploadFile, File, HTTPException, Header, Depends
from dotenv import load_dotenv

# --- 1. SETUP LOGGING (Professional Standard) ---
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(levelname)s - %(message)s"
)
logger = logging.getLogger("TranscriberBackend")

# --- 2. LOAD SECRETS ---
load_dotenv()
API_KEY = os.getenv("GEMINI_API_KEY")
APP_SECRET = os.getenv("APP_SECRET") 

if not API_KEY:
    logger.error("❌ CRITICAL: GEMINI_API_KEY not found in env!")
    raise ValueError("GEMINI_API_KEY not set.")

if not APP_SECRET:
    logger.warning("⚠️ WARNING: APP_SECRET not set. Security is DISABLED.")

genai.configure(api_key=API_KEY)

# --- 3. MODEL CONFIGURATION (The Triple Safety Net) ---
# Primary: High Intelligence (Pro)
# Secondary: High Speed (Flash) - Your reliable workhorse
# Tertiary: Emergency Backup (Flash-Lite) - Cheap and always available
PRIMARY_NAME = "gemini-2.5-pro" 
SECONDARY_NAME = "gemini-2.5-flash"
TERTIARY_NAME = "gemini-2.5-flash-lite" 

logger.info(f"✅ Models Configured: [1]{PRIMARY_NAME} -> [2]{SECONDARY_NAME} -> [3]{TERTIARY_NAME}")

primary_model = genai.GenerativeModel(PRIMARY_NAME)
secondary_model = genai.GenerativeModel(SECONDARY_NAME)
tertiary_model = genai.GenerativeModel(TERTIARY_NAME)

app = FastAPI()

# --- 4. SECURITY GUARD ---
async def verify_secret(x_app_secret: str = Header(None)):
    """
    Blocks any request that doesn't include the correct Secret Header.
    """
    if not APP_SECRET:
        return # Dev mode (if secret isn't set)

    if x_app_secret != APP_SECRET:
        logger.warning(f"🛑 Security Block: Invalid Secret received: {x_app_secret}")
        raise HTTPException(status_code=401, detail="Unauthorized: Invalid Secret")

# --- 5. GARBAGE AUDIO DETECTOR ---
def is_garbage_audio(text: str) -> bool:
    """
    Detects if the transcription is garbage/accidental recording.
    Returns True if audio should be flagged as garbage.
    """
    if not text or len(text.strip()) == 0:
        return True
    
    text_lower = text.lower().strip()
    
    # Pattern 1: Repetitive characters (like "000000:0000" or ".........")
    if len(set(text_lower.replace(":", "").replace(".", "").replace(" ", ""))) <= 3:
        return True
    
    # Pattern 2: Very short transcription (less than 5 characters)
    if len(text_lower.replace(" ", "")) < 5:
        return True
    
    # Pattern 3: Only numbers and punctuation
    if all(c.isdigit() or c in ":.,-_" or c.isspace() for c in text):
        return True
    
    # Pattern 4: Explicit markers from Gemini
    garbage_markers = [
        "[no audio]",
        "[silence]",
        "[inaudible]",
        "no speech",
        "no audio detected",
        "no clear speech",
        "background noise only",
        "nothing",
        "[music]",
        "[background noise]"
    ]
    
    for marker in garbage_markers:
        if marker in text_lower:
            return True
    
    return False

# --- 6. THE RESILIENT CHEF (Cascade Logic) ---
async def transcribe_cascade(audio_path: str, mime_type: str):
    prompt = "Transcribe this audio exactly word-for-word. If there is no clear speech, respond with: [NO CLEAR SPEECH]"

    # --- LEVEL 1: PRIMARY ---
    try:
        logger.info(f"⚡ Attempting Level 1 ({PRIMARY_NAME})...")
        file_1 = genai.upload_file(path=audio_path, mime_type=mime_type)
        response = primary_model.generate_content([file_1, prompt])
        return {"text": response.text, "model": PRIMARY_NAME}
    except Exception as e:
        logger.warning(f"⚠️ Level 1 Failed: {e}")
        # Only switch for availability errors, not bad files
        if not ("503" in str(e) or "429" in str(e) or "404" in str(e)):
            raise e 

        # --- LEVEL 2: SECONDARY ---
        logger.info(f"🔄 Switching to Level 2 ({SECONDARY_NAME})...")
        try:
            file_2 = genai.upload_file(path=audio_path, mime_type=mime_type)
            response = secondary_model.generate_content([file_2, prompt])
            return {"text": response.text, "model": SECONDARY_NAME}
        except Exception as e2:
            logger.warning(f"⚠️ Level 2 Failed: {e2}")

            # --- LEVEL 3: TERTIARY ---
            logger.info(f"🛡️ Switching to Level 3 ({TERTIARY_NAME})...")
            try:
                file_3 = genai.upload_file(path=audio_path, mime_type=mime_type)
                response = tertiary_model.generate_content([file_3, prompt])
                return {"text": response.text, "model": TERTIARY_NAME}
            except Exception as e3:
                logger.error(f"❌ ALL MODELS FAILED. Logic: {e3}")
                raise HTTPException(status_code=503, detail="Server Overloaded. Please try again.")

# --- 6. THE ENDPOINT ---
@app.get("/")
async def root():
    return {"status": "Online", "security": "Enabled" if APP_SECRET else "Disabled"}

@app.post("/transcribe", dependencies=[Depends(verify_secret)]) 
async def handle_transcription(file: UploadFile = File(...)):
    
    if not file.content_type.startswith("audio/"):
        return {"status": "error", "message": "Invalid file type."}

    upload_folder = "temp_processing"
    os.makedirs(upload_folder, exist_ok=True)
    safe_filename = file.filename.replace(" ", "_")
    file_path = f"{upload_folder}/{safe_filename}"
    
    try:
        # Save bytes to disk
        with open(file_path, "wb+") as buffer:
            shutil.copyfileobj(file.file, buffer)

        # Cook the audio
        result = await transcribe_cascade(file_path, file.content_type)
        transcription_text = result["text"]
        
        # Check if audio is garbage
        if is_garbage_audio(transcription_text):
            logger.warning(f"⚠️ Garbage audio detected: '{transcription_text[:50]}'")
            return {
                "status": "success",
                "transcription": "[GARBAGE_AUDIO] No clear speech detected in this recording.",
                "model_used": result["model"],
                "is_garbage": True
            }
        
        logger.info(f"✅ Success! Used model: {result['model']}")

        return {
            "status": "success",
            "transcription": transcription_text,
            "model_used": result["model"],
            "is_garbage": False
        }

    except Exception as e:
        logger.error(f"🔥 Request Error: {e}")
        return {"status": "error", "message": str(e)}
        
    finally:
        # Cleanup
        if os.path.exists(file_path):
            os.remove(file_path)