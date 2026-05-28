# Getting Real ML Models — Quickest Method

## Option 1: Google Colab (RECOMMENDED — free, 5 min, no setup)

1. Go to [colab.research.google.com](https://colab.research.google.com)
2. Click **File → Upload notebook** and upload `scripts/generate_models.ipynb`
3. Set runtime to **GPU** (Runtime → Change runtime type → T4 GPU)
4. Click **Runtime → Run all**
5. The 4 `.tflite` files will auto-download to your `~/Downloads/`
6. Move them to the app:

```bash
mv ~/Downloads/skin_cancer_model.tflite ~/cancer-detection-app/assets/models/
mv ~/Downloads/lung_cancer_model.tflite ~/cancer-detection-app/assets/models/
mv ~/Downloads/breast_cancer_model.tflite ~/cancer-detection-app/assets/models/
mv ~/Downloads/brain_tumor_model.tflite ~/cancer-detection-app/assets/models/
```

7. In the Flutter terminal, press **R** to hot-restart → real inference enabled!

---

## Option 2: Python 3.12 via pyenv (local, ~10 min)

```bash
# Install pyenv and Python 3.12 (TF max supported version)
brew install pyenv
pyenv install 3.12.8
cd ~/cancer-detection-app/scripts
pyenv local 3.12.8

# Create fresh venv with Python 3.12
python -m venv venv312
source venv312/bin/activate
pip install tensorflow

# Generate models
python generate_dummy_models.py
```

---

## Why Python 3.14 doesn't work

TensorFlow only supports Python 3.9–3.12.  
Your system Python is 3.14 — it won't work until TF releases a 3.14 wheel (ETA unknown).

---

## Why the app works fine in demo mode anyway

The app is fully functional with stubs — all UI, history, charts, and
education screens work. The only difference is the result shows
"⚠️ Demo mode" in the recommendation text.

Real inference is enabled the moment you drop valid `.tflite` files
into `assets/models/` and restart.
