#!/usr/bin/env python3
"""
evaluate_models.py
------------------
Picks 10 sample images per class from your already-downloaded Kaggle datasets,
runs them through the TFLite models, compares predictions vs ground truth,
and generates a detailed accuracy report with a visual confusion matrix.

Usage:
  python evaluate_models.py
  python evaluate_models.py --cancer lung
  python evaluate_models.py --samples 10 --cancer all

Requirements:
  pip install numpy Pillow tqdm matplotlib scikit-learn
  (no TensorFlow needed - uses TFLite runtime directly)
"""

import argparse
import json
import random
import shutil
from datetime import datetime
from pathlib import Path

import numpy as np
from PIL import Image
from tqdm import tqdm

# ------------------------------------------------------------------ #
# Paths
# ------------------------------------------------------------------ #
SCRIPTS_DIR = Path(__file__).parent
PROJECT_DIR = SCRIPTS_DIR.parent
MODELS_DIR  = PROJECT_DIR / 'assets' / 'models'
SAMPLES_DIR = SCRIPTS_DIR / 'test_samples'
REPORTS_DIR = SCRIPTS_DIR / 'reports'

REPORTS_DIR.mkdir(exist_ok=True)
SAMPLES_DIR.mkdir(exist_ok=True)

# ------------------------------------------------------------------ #
# Cancer type config
# ------------------------------------------------------------------ #
CANCER_CONFIG = {
    'lung': {
        'model':   'lung_cancer_model.tflite',
        'labels':  ['Normal', 'Adenocarcinoma', 'Large cell carcinoma', 'Squamous cell carcinoma'],
        'search':  [
            SCRIPTS_DIR / 'tmp_lung',
            SCRIPTS_DIR / 'tmp_lung' / 'Data',
            SCRIPTS_DIR / 'tmp_lung' / 'train',
        ],
        'class_map': {
            # folder name -> label index (handles various dataset naming conventions)
            'normal':              0, 'Normal':              0,
            'adenocarcinoma':      1, 'Adenocarcinoma':      1, 'adenocarcinoma_left.lower.lobe_T2_N0_M0_Ia1': 1,
            'large.cell.carcinoma':2, 'large_cell_carcinoma':2, 'Large cell carcinoma':2,
            'squamous.cell.carcinoma':3,'squamous_cell_carcinoma':3,'Squamous cell carcinoma':3,
        },
    },
    'brain': {
        'model':   'brain_tumor_model.tflite',
        'labels':  ['No Tumor', 'Glioma', 'Meningioma', 'Pituitary'],
        'search':  [
            SCRIPTS_DIR / 'tmp_brain',
            SCRIPTS_DIR / 'tmp_brain' / 'Training',
            SCRIPTS_DIR / 'tmp' / 'Training',
        ],
        'class_map': {
            'notumor':   0, 'no_tumor':  0, 'No Tumor':  0, 'notumor': 0,
            'glioma':    1, 'Glioma':    1, 'glioma_tumor': 1,
            'meningioma':2, 'Meningioma':2, 'meningioma_tumor': 2,
            'pituitary': 3, 'Pituitary': 3, 'pituitary_tumor': 3,
        },
    },
    'skin': {
        'model':   'skin_cancer_model.tflite',
        'labels':  ['Melanocytic nevi','Melanoma','Benign keratosis','Basal cell carcinoma',
                    'Actinic keratoses','Vascular lesions','Dermatofibroma'],
        'search':  [
            SCRIPTS_DIR / 'tmp_skin',
            SCRIPTS_DIR / 'tmp' / 'skin',
        ],
        'class_map': {
            'nv':    0, 'mel':   1, 'bkl':   2, 'bcc':   3,
            'akiec': 4, 'vasc':  5, 'df':    6,
            'Melanocytic nevi':0, 'Melanoma':1, 'Benign keratosis':2,
            'Basal cell carcinoma':3, 'Actinic keratoses':4,
            'Vascular lesions':5, 'Dermatofibroma':6,
        },
    },
    'breast': {
        'model':   'breast_cancer_model.tflite',
        'labels':  ['Normal', 'Benign', 'Malignant'],
        'search':  [
            SCRIPTS_DIR / 'tmp_breast',
            SCRIPTS_DIR / 'tmp' / 'breast',
        ],
        'class_map': {
            'normal':   0, 'Normal':   0,
            'benign':   1, 'Benign':   1,
            'malignant':2, 'Malignant':2,
        },
    },
}

IMG_SIZE = 224


# ------------------------------------------------------------------ #
# TFLite inference (no tensorflow needed)
# ------------------------------------------------------------------ #

def load_interpreter(model_path: Path):
    try:
        import tflite_runtime.interpreter as tflite
        print('  Using tflite_runtime')
    except ImportError:
        try:
            import tensorflow.lite as tflite
            print('  Using tensorflow.lite')
        except ImportError:
            raise ImportError(
                'Install tflite: pip install tflite-runtime  '
                'OR  pip install tensorflow'
            )
    interp = tflite.Interpreter(model_path=str(model_path))
    interp.allocate_tensors()
    return interp


def preprocess(image_path: Path) -> np.ndarray:
    img = Image.open(image_path).convert('RGB').resize((IMG_SIZE, IMG_SIZE))
    arr = np.array(img, dtype=np.float32) / 255.0
    return np.expand_dims(arr, axis=0)


def predict(interp, image_path: Path) -> np.ndarray:
    inp  = interp.get_input_details()
    out  = interp.get_output_details()
    data = preprocess(image_path)
    interp.set_tensor(inp[0]['index'], data)
    interp.invoke()
    return interp.get_tensor(out[0]['index'])[0]


# ------------------------------------------------------------------ #
# Dataset discovery
# ------------------------------------------------------------------ #

def find_dataset(cancer_type: str) -> dict[int, list[Path]]:
    """
    Returns {label_index: [image_paths]} by scanning search dirs.
    """
    cfg      = CANCER_CONFIG[cancer_type]
    class_map = cfg['class_map']
    found    = {i: [] for i in range(len(cfg['labels']))}

    for root in cfg['search']:
        if not root.exists():
            continue
        # Walk every subdir
        for d in sorted(root.rglob('*')):
            if not d.is_dir():
                continue
            label_idx = class_map.get(d.name)
            if label_idx is None:
                continue
            images = (
                list(d.glob('*.jpg')) + list(d.glob('*.jpeg')) +
                list(d.glob('*.png')) + list(d.glob('*.JPG'))
            )
            found[label_idx].extend(images)

    return found


def sample_images(image_map: dict[int, list[Path]], n: int) -> dict[int, list[Path]]:
    """Pick n random images per class (or all if fewer than n)."""
    random.seed(42)
    return {
        idx: random.sample(imgs, min(n, len(imgs)))
        for idx, imgs in image_map.items()
        if imgs
    }


# ------------------------------------------------------------------ #
# Evaluation
# ------------------------------------------------------------------ #

def evaluate(cancer_type: str, n_samples: int) -> dict:
    print(f'\n{══ Evaluating: {cancer_type.upper()} ":"=<}".center(52, "=")}')
    cfg    = CANCER_CONFIG[cancer_type]
    labels = cfg['labels']
    model_path = MODELS_DIR / cfg['model']

    if not model_path.exists() or model_path.stat().st_size < 10_000:
        print(f'  ⚠  Model not found or stub: {model_path}')
        print(f'     Run: python run_app.py --build-only  to ensure models are present')
        return {}

    print(f'  Model : {model_path.name} ({model_path.stat().st_size // 1024} KB)')
    interp = load_interpreter(model_path)

    image_map = find_dataset(cancer_type)
    total_found = sum(len(v) for v in image_map.values())
    if total_found == 0:
        print(f'  ⚠  No images found. Check search paths in CANCER_CONFIG.')
        print(f'     Expected dirs: {[str(s) for s in cfg["search"]]}')
        return {}

    print(f'  Found {total_found} images across {len(image_map)} classes')
    sampled = sample_images(image_map, n_samples)

    # Save sample images for reference
    sample_out = SAMPLES_DIR / cancer_type
    if sample_out.exists():
        shutil.rmtree(sample_out)
    sample_out.mkdir(parents=True)

    results = []
    for true_idx, paths in sampled.items():
        true_label = labels[true_idx]
        print(f'\n  [{true_label}] — {len(paths)} images')
        for img_path in tqdm(paths, desc=f'    Predicting', leave=False):
            try:
                probs = predict(interp, img_path)
                pred_idx   = int(np.argmax(probs))
                pred_label = labels[pred_idx]
                confidence = float(probs[pred_idx])
                correct    = pred_idx == true_idx

                # Copy sample image
                dst = sample_out / true_label.replace(' ', '_')
                dst.mkdir(exist_ok=True)
                shutil.copy(img_path, dst / f'{"CORRECT" if correct else "WRONG"}_{img_path.name}')

                results.append({
                    'image':      img_path.name,
                    'true_label': true_label,
                    'true_idx':   true_idx,
                    'pred_label': pred_label,
                    'pred_idx':   pred_idx,
                    'confidence': confidence,
                    'correct':    correct,
                    'probs':      {labels[i]: float(probs[i]) for i in range(len(labels))},
                })

                mark = '✔' if correct else '✘'
                print(f'      {mark} {img_path.name[:30]:32s} '
                      f'True: {true_label:25s} '
                      f'Pred: {pred_label:25s} '
                      f'({confidence:.1%})')
            except Exception as e:
                print(f'      ⚠ {img_path.name}: {e}')

    return _compute_metrics(cancer_type, labels, results)


def _compute_metrics(cancer_type: str, labels: list, results: list) -> dict:
    if not results:
        return {}

    total   = len(results)
    correct = sum(r['correct'] for r in results)
    accuracy = correct / total

    # Per-class metrics
    per_class = {}
    for i, label in enumerate(labels):
        cls_results = [r for r in results if r['true_idx'] == i]
        if not cls_results:
            continue
        tp = sum(1 for r in cls_results if r['pred_idx'] == i)
        per_class[label] = {
            'total':    len(cls_results),
            'correct':  tp,
            'accuracy': tp / len(cls_results),
            'avg_conf': np.mean([r['confidence'] for r in cls_results if r['pred_idx'] == i] or [0]),
        }

    # Confusion matrix
    n = len(labels)
    cm = np.zeros((n, n), dtype=int)
    for r in results:
        cm[r['true_idx']][r['pred_idx']] += 1

    return {
        'cancer_type': cancer_type,
        'labels':      labels,
        'total':       total,
        'correct':     correct,
        'accuracy':    accuracy,
        'per_class':   per_class,
        'confusion_matrix': cm.tolist(),
        'results':     results,
    }


# ------------------------------------------------------------------ #
# Report generation
# ------------------------------------------------------------------ #

def print_report(metrics: dict):
    if not metrics:
        return
    print(f'\n  RESULTS FOR {metrics["cancer_type"].upper()}')
    print(f'  {"="*48}')
    print(f'  Overall Accuracy : {metrics["accuracy"]:.1%}  '
          f'({metrics["correct"]}/{metrics["total"]})')
    print(f'\n  Per-class breakdown:')
    print(f'  {"Class":<28} {"Correct":>8} {"Total":>6} {"Accuracy":>10} {"Avg Conf":>10}')
    print(f'  {"-"*65}')
    for label, m in metrics['per_class'].items():
        print(f'  {label:<28} {m["correct"]:>8} {m["total"]:>6} '
              f'{m["accuracy"]:>9.1%}  {m["avg_conf"]:>9.1%}')

    print(f'\n  Confusion Matrix (rows=True, cols=Predicted):')
    labels = metrics['labels']
    header = '  ' + ' ' * 26 + ''.join(f'{l[:8]:>10}' for l in labels)
    print(header)
    for i, row in enumerate(metrics['confusion_matrix']):
        print(f'  {labels[i]:<26}' + ''.join(f'{v:>10}' for v in row))


def save_report(all_metrics: list, n_samples: int):
    ts = datetime.now().strftime('%Y%m%d_%H%M%S')
    report_path = REPORTS_DIR / f'evaluation_{ts}.json'
    html_path   = REPORTS_DIR / f'evaluation_{ts}.html'

    # JSON
    report = {
        'generated_at': datetime.now().isoformat(),
        'n_samples_per_class': n_samples,
        'cancer_types': [
            {k: v for k, v in m.items() if k != 'results'}
            for m in all_metrics if m
        ],
    }
    report_path.write_text(json.dumps(report, indent=2))
    print(f'\n  JSON report: {report_path}')

    # HTML report
    html = _build_html_report(all_metrics, n_samples, ts)
    html_path.write_text(html)
    print(f'  HTML report: {html_path}')
    print(f'  Open it: open {html_path}')
    return html_path


def _build_html_report(all_metrics: list, n_samples: int, ts: str) -> str:
    rows = ''
    summary_rows = ''

    for m in all_metrics:
        if not m:
            continue
        ct = m['cancer_type'].title()
        acc = m['accuracy']
        acc_color = '#388E3C' if acc >= 0.7 else '#F57C00' if acc >= 0.5 else '#D32F2F'
        summary_rows += f'''
        <tr>
          <td><b>{ct}</b></td>
          <td>{m["total"]}</td>
          <td>{m["correct"]}</td>
          <td style="color:{acc_color};font-weight:bold">{acc:.1%}</td>
        </tr>'''

        rows += f'<h2 style="color:#1565C0;margin-top:40px">{ct} Cancer</h2>'

        # Per-class table
        rows += '<table><tr><th>Class</th><th>Correct</th><th>Total</th><th>Accuracy</th></tr>'
        for label, pc in m['per_class'].items():
            color = '#388E3C' if pc['accuracy'] >= 0.7 else '#F57C00' if pc['accuracy'] >= 0.5 else '#D32F2F'
            rows += f'<tr><td>{label}</td><td>{pc["correct"]}</td><td>{pc["total"]}</td>'
            rows += f'<td style="color:{color}"><b>{pc["accuracy"]:.1%}</b></td></tr>'
        rows += '</table>'

        # Confusion matrix
        labels = m['labels']
        rows += '<h3>Confusion Matrix</h3><table>'
        rows += '<tr><th>True \ Pred</th>' + ''.join(f'<th>{l}</th>' for l in labels) + '</tr>'
        for i, row in enumerate(m['confusion_matrix']):
            rows += f'<tr><th>{labels[i]}</th>'
            for j, v in enumerate(row):
                bg = '#C8E6C9' if i == j and v > 0 else '#FFCDD2' if i != j and v > 0 else '#FAFAFA'
                rows += f'<td style="background:{bg};text-align:center">{v}</td>'
            rows += '</tr>'
        rows += '</table>'

        # Individual predictions
        rows += '<h3>Individual Predictions</h3><table>'
        rows += '<tr><th>Image</th><th>True Label</th><th>Predicted</th><th>Confidence</th><th>Result</th></tr>'
        for r in m['results']:
            mark = '✔' if r['correct'] else '✘'
            color = '#388E3C' if r['correct'] else '#D32F2F'
            rows += (f'<tr><td>{r["image"][:30]}</td><td>{r["true_label"]}</td>'
                     f'<td>{r["pred_label"]}</td>'
                     f'<td>{r["confidence"]:.1%}</td>'
                     f'<td style="color:{color};font-size:18px">{mark}</td></tr>')
        rows += '</table>'

    return f'''<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<title>Cancer Detection Evaluation Report</title>
<style>
  body {{ font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
          max-width: 1100px; margin: 40px auto; padding: 0 20px; background: #F8F9FA; color: #333; }}
  h1   {{ color: #0D47A1; border-bottom: 3px solid #1565C0; padding-bottom: 10px; }}
  h2   {{ border-left: 4px solid #1565C0; padding-left: 12px; }}
  table{{ border-collapse: collapse; width: 100%; margin: 16px 0; background: white;
          border-radius: 8px; overflow: hidden; box-shadow: 0 2px 8px rgba(0,0,0,.08); }}
  th   {{ background: #1565C0; color: white; padding: 10px 14px; text-align: left; }}
  td   {{ padding: 9px 14px; border-bottom: 1px solid #EEE; }}
  tr:hover td {{ background: #F0F4FF; }}
  .summary-box {{ background: white; border-radius: 12px; padding: 20px;
                  box-shadow: 0 2px 12px rgba(0,0,0,.08); margin-bottom: 32px; }}
  .badge {{ display:inline-block; padding:3px 10px; border-radius:12px;
            font-size:12px; font-weight:bold; }}
</style>
</head>
<body>
<h1>🔬 Cancer Detection AI — Evaluation Report</h1>
<p>Generated: {datetime.now().strftime("%B %d, %Y %H:%M")} · {n_samples} samples per class</p>

<div class="summary-box">
<h2 style="margin-top:0;border:none">Overall Summary</h2>
<table>
  <tr><th>Cancer Type</th><th>Total Images</th><th>Correct</th><th>Accuracy</th></tr>
  {summary_rows}
</table>
</div>

{rows}

<p style="color:#999;font-size:12px;margin-top:40px">
⚠️ This evaluation is for research and educational purposes only.
Models are not clinically validated. Do not use for medical diagnosis.
</p>
</body></html>
'''


# ------------------------------------------------------------------ #
# Matplotlib confusion matrix (optional)
# ------------------------------------------------------------------ #

def plot_confusion_matrix(metrics: dict):
    try:
        import matplotlib.pyplot as plt
        import matplotlib
        matplotlib.use('Agg')
    except ImportError:
        return

    cm     = np.array(metrics['confusion_matrix'])
    labels = metrics['labels']
    ct     = metrics['cancer_type']
    n      = len(labels)

    fig, ax = plt.subplots(figsize=(max(6, n * 1.5), max(5, n * 1.3)))
    im = ax.imshow(cm, interpolation='nearest', cmap='Blues')
    fig.colorbar(im)

    ax.set(xticks=range(n), yticks=range(n),
           xticklabels=labels, yticklabels=labels,
           title=f'{ct.title()} Cancer — Confusion Matrix\nAccuracy: {metrics["accuracy"]:.1%}',
           ylabel='True label', xlabel='Predicted label')

    plt.setp(ax.get_xticklabels(), rotation=30, ha='right')
    thresh = cm.max() / 2
    for i in range(n):
        for j in range(n):
            ax.text(j, i, cm[i, j], ha='center', va='center',
                    color='white' if cm[i, j] > thresh else 'black', fontsize=13)

    fig.tight_layout()
    out = REPORTS_DIR / f'confusion_{ct}.png'
    fig.savefig(out, dpi=150)
    plt.close()
    print(f'  Confusion matrix plot: {out}')


# ------------------------------------------------------------------ #
# Main
# ------------------------------------------------------------------ #

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--cancer',  default='all',
                        help='Cancer type: lung | brain | skin | breast | all')
    parser.add_argument('--samples', type=int, default=10,
                        help='Number of test images per class (default: 10)')
    parser.add_argument('--plot',    action='store_true',
                        help='Save confusion matrix plots (needs matplotlib)')
    args = parser.parse_args()

    types = list(CANCER_CONFIG.keys()) if args.cancer == 'all' else [args.cancer]

    print('\n🔬 Cancer Detection AI — Model Evaluation')
    print(f'   Samples per class : {args.samples}')
    print(f'   Cancer types      : {", ".join(types)}')
    print(f'   Models dir        : {MODELS_DIR}')

    all_metrics = []
    for ct in types:
        m = evaluate(ct, args.samples)
        if m:
            print_report(m)
            if args.plot:
                plot_confusion_matrix(m)
        all_metrics.append(m)

    valid = [m for m in all_metrics if m]
    if valid:
        html_path = save_report(valid, args.samples)
        print(f'\n✅ Evaluation complete!')
        print(f'   Open report: open {html_path}')
    else:
        print('\n⚠  No evaluations completed. Check dataset paths.')
        print('   Run: python evaluate_models.py --cancer lung')
        print('   Make sure tmp_lung/ or tmp_brain/ exist in scripts/')


if __name__ == '__main__':
    main()
