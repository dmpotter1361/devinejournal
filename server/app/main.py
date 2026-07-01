from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse
from pathlib import Path
from .routers import auth, entries, photos, voice_memos

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
app.include_router(voice_memos.router, prefix="/api")

@app.get("/api/health")
def health():
    return {"status": "ok", "version": "0.1.0"}

# Serve React/Vite build — assets directory mounted for hashed bundles
static_dir = Path(__file__).parent.parent / "static"
assets_dir = static_dir / "assets"
if assets_dir.exists():
    app.mount("/assets", StaticFiles(directory=str(assets_dir)), name="static-assets")

# SPA catch-all: serve static files that exist, otherwise index.html for client-side routing.
# Must be registered AFTER all /api routes so API paths are never intercepted.
@app.get("/{full_path:path}", include_in_schema=False)
async def serve_spa(full_path: str):
    file_path = static_dir / full_path
    if file_path.exists() and file_path.is_file():
        return FileResponse(file_path)
    index = static_dir / "index.html"
    if index.exists():
        return FileResponse(index)
    return {"error": "frontend not built"}
