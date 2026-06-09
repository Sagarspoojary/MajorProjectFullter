import os
import cv2
import numpy as np
from collections import deque

# Workaround for PyTorch 2.6+ weights_only load issue with Ultralytics YOLOv8 models
try:
  import torch
  _orig_load = torch.load
  torch.load = lambda *args, **kwargs: _orig_load(*args, **{**kwargs, 'weights_only': False})
except Exception:
  pass

from ultralytics import YOLO

class MultiModelGenderFusionPipeline:
  def __init__(self, weights_dir="models"):
    self.weights_dir = weights_dir
    
    # 1. Initialize YOLOv8s model
    print("[YOLO Loading] Initializing YOLOv8s model (yolov8s.pt)...")
    self.yolo_model = YOLO(os.path.join(weights_dir, "yolov8s.pt"))
    print("[YOLO Loading] YOLOv8s model loaded successfully.")
    
    # 2. Initialize OpenCV DNN Face Detection Caffe model
    print("[Face Model Loading] Initializing Caffe Face Net...")
    self.face_net = cv2.dnn.readNet(
      os.path.join(weights_dir, "res10_300x300_ssd_iter_140000.caffemodel"),
      os.path.join(weights_dir, "deploy.prototxt")
    )
    
    # 3. Initialize OpenCV DNN Gender Classification Caffe model
    print("[Gender Model Loading] Initializing Caffe Gender Net...")
    self.gender_net = cv2.dnn.readNet(
      os.path.join(weights_dir, "gender_net.caffemodel"),
      os.path.join(weights_dir, "gender_deploy.prototxt")
    )
    
    self.GENDER_LIST = ["Male", "Female"]
    
    # Tracking states: {person_id: deque}
    self.history_map = {}
    self.max_buffer_size = 15

  def process_frame(self, frame):
    h_img, w_img, _ = frame.shape
    
    # Run YOLOv8s Person Detector + ByteTrack
    results = self.yolo_model.track(frame, persist=True, classes=[0], tracker="bytetrack.yaml", verbose=False)
    
    if not results or len(results) == 0 or results[0].boxes is None:
      return []

    boxes = results[0].boxes
    output_detections = []
    active_ids = set()

    for box in boxes:
      track_id = int(box.id[0]) if box.id is not None else -1
      xyxy = box.xyxy[0].cpu().numpy()
      x1, y1, x2, y2 = map(int, xyxy)
      
      x1, y1 = max(0, x1), max(0, y1)
      x2, y2 = min(w_img, x2), min(h_img, y2)
      
      if (x2 - x1) <= 0 or (y2 - y1) <= 0:
        continue

      person_id = f"track_{track_id}" if track_id != -1 else f"pos_{x1}_{y1}"
      active_ids.add(person_id)

      person_crop = frame[y1:y2, x1:x2]
      h_crop, w_crop = person_crop.shape[:2]

      gender_label = "Unknown"
      confidence = 1.0

      if person_crop.size > 0:
        # 1. Face detection on cropped person
        blob = cv2.dnn.blobFromImage(
          person_crop,
          1.0,
          (300, 300),
          (104.0, 177.0, 123.0)
        )
        self.face_net.setInput(blob)
        face_detections = self.face_net.forward()

        # Find best face detection
        best_face_idx = -1
        max_face_conf = 0.5
        for i in range(face_detections.shape[2]):
          conf = face_detections[0, 0, i, 2]
          if conf > max_face_conf:
            max_face_conf = conf
            best_face_idx = i

        if best_face_idx != -1:
          fx1 = int(face_detections[0, 0, best_face_idx, 3] * w_crop)
          fy1 = int(face_detections[0, 0, best_face_idx, 4] * h_crop)
          fx2 = int(face_detections[0, 0, best_face_idx, 5] * w_crop)
          fy2 = int(face_detections[0, 0, best_face_idx, 6] * h_crop)

          fx1, fy1 = max(0, fx1), max(0, fy1)
          fx2, fy2 = min(w_crop, fx2), min(h_crop, fy2)

          face_crop = person_crop[fy1:fy2, fx1:fx2]
          if face_crop.size > 0:
            # 2. Gender prediction on face crop
            gender_blob = cv2.dnn.blobFromImage(
              face_crop,
              1.0,
              (227, 227),
              (78.4263377603, 87.7689143744, 114.895847746),
              swapRB=False
            )
            self.gender_net.setInput(gender_blob)
            gender_preds = self.gender_net.forward()
            gender_id = gender_preds[0].argmax()
            gender_label = self.GENDER_LIST[gender_id]
            confidence = float(gender_preds[0][gender_id])

      # Temporal smoothing
      if person_id not in self.history_map:
        self.history_map[person_id] = deque(maxlen=self.max_buffer_size)
      
      self.history_map[person_id].append((gender_label, confidence))

      # Majority vote
      labels = [item[0] for item in self.history_map[person_id]]
      stable_label = max(set(labels), key=labels.count)
      
      # Average confidence for the stable label
      confidences = [item[1] for item in self.history_map[person_id] if item[0] == stable_label]
      avg_confidence = np.mean(confidences) if confidences else 0.0

      # Normalize rect coordinates for Flutter UI
      norm_rect = [
        x1 / w_img,
        y1 / h_img,
        (x2 - x1) / w_img,
        (y2 - y1) / h_img
      ]

      output_detections.append({
        "rect": norm_rect,
        "label": stable_label,
        "confidence": float(avg_confidence)
      })

    # Prune inactive history
    inactive_ids = [pid for pid in self.history_map.keys() if pid not in active_ids]
    for pid in inactive_ids:
      del self.history_map[pid]

    return output_detections
