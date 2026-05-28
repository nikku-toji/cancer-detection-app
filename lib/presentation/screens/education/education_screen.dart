import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/constants/app_constants.dart';

const _educationContent = {
  'skin': {
    'overview': 'Skin cancer is the most common form of cancer globally. It develops when skin cells grow uncontrollably, usually due to UV radiation damage.',
    'types': ['Melanoma', 'Basal Cell Carcinoma', 'Squamous Cell Carcinoma', 'Merkel Cell Carcinoma'],
    'symptoms': [
      'New mole or change in existing mole',
      'Irregular borders or asymmetrical shape',
      'Multiple colors within a lesion',
      'Diameter larger than 6mm',
      'Evolving size, shape, or color',
    ],
    'prevention': [
      'Use broad-spectrum SPF 30+ sunscreen',
      'Avoid peak UV hours (10am–4pm)',
      'Wear protective clothing & hats',
      'Avoid tanning beds',
      'Perform monthly self-skin exams',
    ],
  },
  'lung': {
    'overview': 'Lung cancer is the leading cause of cancer death worldwide. Most cases are linked to smoking, but non-smokers can also develop it.',
    'types': ['Non-Small Cell (NSCLC)', 'Small Cell Lung Cancer (SCLC)', 'Adenocarcinoma', 'Squamous Cell'],
    'symptoms': [
      'Persistent cough that worsens',
      'Coughing up blood',
      'Chest pain during breathing',
      'Shortness of breath',
      'Unexplained weight loss',
    ],
    'prevention': [
      'Do not smoke or quit smoking',
      'Avoid secondhand smoke exposure',
      'Test home for radon gas',
      'Avoid carcinogens at work',
      'Eat a healthy diet rich in vegetables',
    ],
  },
  'breast': {
    'overview': 'Breast cancer is one of the most common cancers in women. Early detection through screening significantly improves outcomes.',
    'types': ['Invasive Ductal Carcinoma', 'Invasive Lobular Carcinoma', 'DCIS', 'Triple Negative Breast Cancer'],
    'symptoms': [
      'Lump in breast or underarm',
      'Swelling or thickening of breast tissue',
      'Skin dimpling or puckering',
      'Nipple discharge or inversion',
      'Redness or flaky skin near nipple',
    ],
    'prevention': [
      'Regular mammography screening',
      'Maintain healthy weight',
      'Limit alcohol consumption',
      'Exercise regularly',
      'Know your family history',
    ],
  },
  'brain': {
    'overview': 'Brain tumors can be benign or malignant, arising from brain tissue or spreading from other cancers. Early diagnosis is critical.',
    'types': ['Glioma', 'Meningioma', 'Pituitary Adenoma', 'Medulloblastoma'],
    'symptoms': [
      'Persistent headaches',
      'Seizures (new onset)',
      'Vision, hearing, or speech problems',
      'Memory or personality changes',
      'Balance and coordination issues',
    ],
    'prevention': [
      'Limit exposure to ionizing radiation',
      'Avoid unnecessary head CT scans',
      'Maintain a healthy lifestyle',
      'Regular neurological check-ups if at risk',
      'Genetic counseling for family history',
    ],
  },
};

class EducationScreen extends StatelessWidget {
  final String cancerType;

  const EducationScreen({super.key, required this.cancerType});

  @override
  Widget build(BuildContext context) {
    final content = _educationContent[cancerType]!;
    final name = AppConstants.cancerNames[cancerType]!;

    return Scaffold(
      appBar: AppBar(title: Text('About $name')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Section(
              title: 'Overview',
              child: Text(content['overview'] as String),
              delay: 0,
            ),
            _Section(
              title: 'Types',
              child: Column(
                children: (content['types'] as List<String>)
                    .map((t) => _BulletItem(text: t))
                    .toList(),
              ),
              delay: 100,
            ),
            _Section(
              title: 'Warning Signs',
              child: Column(
                children: (content['symptoms'] as List<String>)
                    .map((s) => _BulletItem(text: s, icon: Icons.error_outline, color: Colors.orange))
                    .toList(),
              ),
              delay: 200,
            ),
            _Section(
              title: 'Prevention',
              child: Column(
                children: (content['prevention'] as List<String>)
                    .map((p) => _BulletItem(text: p, icon: Icons.check_circle_outline, color: Colors.green))
                    .toList(),
              ),
              delay: 300,
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  final int delay;

  const _Section({required this.title, required this.child, required this.delay});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    ).animate().fadeIn(delay: Duration(milliseconds: delay)).slideY(begin: 0.1);
  }
}

class _BulletItem extends StatelessWidget {
  final String text;
  final IconData icon;
  final Color color;

  const _BulletItem({
    required this.text,
    this.icon = Icons.circle,
    this.color = Colors.blue,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
