
from fastapi import FastAPI

app = FastAPI()

print("BACKEND CLEAN START")

@app.get("/ping")
def ping():
    return {"ping": "pong"}

@app.get("/")
def root():
    return {"status": "alive"}
