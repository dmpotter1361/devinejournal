from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse
from pathlib import Path
from .routers import auth, entries, photos

app = FastAPI(title="DevineJournal", docs_url="/api/docs", redoc_url=None)

app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://localhost:3000",
        "http://localhost:8000",
        "https://journal.devinetarot.net",
    ],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router,    prefix="/api")
app.include_router(entries.router, prefix="/api")
app.include_router(photos.router,  prefix="/api")

@app.get("/api/health")
def health():
    return {"status": "ok", "version": "0.1.0"}

# Serve Flutter web build — must be last
static_dir = Path(__file__).parent.parent / "static"
if static_dir.exists() and any(static_dir.iterdir()):
    app.mount("/", StaticFiles(directory=str(static_dir), html=True), name="static")
