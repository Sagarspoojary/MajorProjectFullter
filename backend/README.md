# SHEGUARD AI - Real-Time AI Inference Backend

This is the Python-based AI inference server for the **Real-Time Women Distress Detection System**. It hosts a FastAPI WebSocket endpoint that receives live camera feeds from the Flutter client, runs a multi-model prediction fusion pipeline, and returns stable detection results.

---

## 🛠️ Requirements & Setup

### Step 1: Create a Virtual Environment

Navigate to the `backend` directory and initialize a Python 3 virtual environment:

```bash
cd backend
python3 -m venv venv
source venv/bin/activate
```

### Step 2: Install Dependencies

Install the required packages from `requirements.txt`:

```bash
pip install --upgrade pip
pip install -r requirements.txt
```

---

## 📦 Model Deployment Steps

Place your custom ONNX classification models in the `backend/models/` folder:

```text
backend/
├── models/
│   ├── efficientnet_b4_face.onnx     # EfficientNet-B4 Face Gender Classification model
│   └── efficientnet_b4_body.onnx     # EfficientNet-B4 Body Gender Classification model
```

### A. YOLOv8 Person Detection
The pipeline initializes `YOLO("yolov8n.pt")`. Upon first run, the Ultralytics engine will automatically download the YOLOv8 Nano model weights (`yolov8n.pt`) to your project root. No manual download is required.

### B. EfficientNet-B4 Face & Body Models
1. Train your custom gender classification models on your datasets (e.g. CelebA for faces, and full-body frames for body).
2. Export your PyTorch/TensorFlow models to ONNX format with an input resolution shape of **`380x380`** and `3` channels (RGB):
   ```python
   # Example PyTorch Export
   import torch
   torch.onnx.export(model, dummy_input, "efficientnet_b4_face.onnx", input_names=["input"], output_names=["output"])
   ```
3. Rename and place the ONNX models into the `models/` directory. If the models are not present, the pipeline runs a high-fidelity simulated fallback with dynamic prediction noise (which our temporal voting filter cleans up) to allow testing immediately.

### C. MediaPipe Face & Pose Models
The MediaPipe Face Detection and Pose Landmarker libraries are loaded dynamically by the Python wrapper at runtime.

---

## 🚀 Running the Server

Start the FastAPI application using Uvicorn:

```bash
python main.py
```

The server will start on:
* **Address**: `http://localhost:8000`
* **WebSocket Endpoint**: `ws://localhost:8000/ws`

*Note: For testing on a physical mobile device, replace `localhost` with your machine's local IP address (e.g. `ws://192.168.1.10:8000/ws`) on both the Flutter client config and the Python server run command.*
