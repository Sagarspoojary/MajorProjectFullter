import cv2
import uvicorn
import numpy as np
from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from pipeline import MultiModelGenderFusionPipeline

app = FastAPI(title="SHEGUARD AI - Real-Time Detection Backend")

# Initialize the pipeline
pipeline = MultiModelGenderFusionPipeline()

@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
  await websocket.accept()
  print("SHEGUARD AI Client Connected via WebSocket.")
  try:
    while True:
      # Receive binary frame payload from Flutter client
      data = await websocket.receive_bytes()
      
      print("New frame received")
      
      if len(data) < 8:
        print("Error: Payload too small")
        continue

      # Read 8-byte header: width (4 bytes), height (4 bytes)
      width = int.from_bytes(data[0:4], byteorder='big')
      height = int.from_bytes(data[4:8], byteorder='big')
      
      pixel_bytes = data[8:]
      expected_size = width * height * 3
      if len(pixel_bytes) != expected_size:
        print(f"Error: Payload size mismatch. Expected {expected_size}, got {len(pixel_bytes)}")
        continue

      # Reshape raw RGB bytes and convert to BGR for OpenCV pipeline compatibility
      frame_rgb = np.frombuffer(pixel_bytes, dtype=np.uint8).reshape((height, width, 3))
      frame = cv2.cvtColor(frame_rgb, cv2.COLOR_RGB2BGR)

      # Run through the multi-model AI pipeline
      detections = pipeline.process_frame(frame)
      
      print(f"Persons detected: {len(detections)}")
      print("Running fresh gender classification")

      # Send the JSON result payload back to the Flutter client
      # Format: [{"rect": [left, top, w, h], "label": "Female", "confidence": 0.97}, ...]
      await websocket.send_json(detections)
      
      print("Updating UI with latest results")
  except WebSocketDisconnect:
    print("SHEGUARD AI Client Disconnected.")
  except Exception as e:
    print(f"Connection error: {e}")

if __name__ == "__main__":
  # Start the server locally on port 8000
  uvicorn.run(app, host="0.0.0.0", port=8000)
