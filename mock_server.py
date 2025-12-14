"""Mock backend API simulating orchestrator progress.

Run with:
    uvicorn mock_server:app --reload --host 0.0.0.0 --port 8000
"""
from __future__ import annotations

import time
import uuid
from typing import Dict

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

app = FastAPI(title="Mock Orchestrator API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


class GenerateRequest(BaseModel):
    description: str


_jobs: Dict[str, float] = {}


@app.post("/generate-feature")
def generate_feature(payload: GenerateRequest) -> Dict[str, str]:
    job_id = str(uuid.uuid4())
    _jobs[job_id] = time.time()
    return {"jobId": job_id}


@app.get("/status/{job_id}")
def get_status(job_id: str):
    if job_id not in _jobs:
        raise HTTPException(status_code=404, detail="Job not found")

    elapsed = time.time() - _jobs[job_id]
    return _build_status(elapsed)


def _build_status(elapsed: float) -> Dict:
    if elapsed < 2:
        steps = {
            "architect": "running",
            "backend": "pending",
            "integration": "pending",
            "review": "pending",
        }
        return {"status": "running", "steps": steps, "files": None, "architecture": None, "review": None}

    if elapsed < 4:
        steps = {
            "architect": "complete",
            "backend": "running",
            "integration": "pending",
            "review": "pending",
        }
        return {"status": "running", "steps": steps, "files": None, "architecture": None, "review": None}

    if elapsed < 6:
        steps = {
            "architect": "complete",
            "backend": "complete",
            "integration": "running",
            "review": "pending",
        }
        architecture = {
            "feature": "Products",
            "model": {"name": "Product", "fields": {"id": "int", "name": "string", "price": "decimal"}},
        }
        return {"status": "running", "steps": steps, "files": None, "architecture": architecture, "review": None}

    steps = {
        "architect": "complete",
        "backend": "complete",
        "integration": "complete",
        "review": "complete",
    }
    architecture = {
        "feature": "Products",
        "model": {"name": "Product", "fields": {"id": "int", "name": "string", "price": "decimal"}},
    }
    files = [
        {"path": "ProductController.cs", "content": "// controller code..."},
        {"path": "ProductModel.cs", "content": "// model code..."},
    ]
    review = "Looks good. Add validations later."
    return {
        "status": "complete",
        "steps": steps,
        "architecture": architecture,
        "files": files,
        "review": review,
    }
