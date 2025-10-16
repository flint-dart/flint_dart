// lib/flint_ui/preview/html_preview.dart

import 'package:flint_dart/src/flint_ui/core/framework.dart';

class FlintPreview {
  /// Generate a complete HTML file for preview
  static String generatePreviewHtml(FlintWidget content,
      {String title = 'Flint UI Preview'}) {
    return '''
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>$title</title>
    <style>
        ${_getPreviewStyles()}
    </style>
</head>
<body>
    <div class="flint-preview-container">
        <div class="preview-header">
            <h1>📧 Flint UI Template Preview</h1>
            <div class="preview-controls">
                <button onclick="toggleDevice('desktop')">Desktop</button>
                <button onclick="toggleDevice('tablet')">Tablet</button>
                <button onclick="toggleDevice('mobile')">Mobile</button>
                <button onclick="copyHtml()">Copy HTML</button>
                <button onclick="downloadHtml()">Download HTML</button>
            </div>
        </div>
        
        <div class="device-preview" id="devicePreview">
            <div class="device-frame desktop">
                <div class="email-content">
                    ${content.toHtml()}
                </div>
            </div>
        </div>
        
        <div class="preview-footer">
            <div class="html-source">
                <h3>Generated HTML:</h3>
                <pre><code id="htmlCode">${_escapeHtml(content.toHtml())}</code></pre>
            </div>
            <div class="text-source">
                <h3>Plain Text Version:</h3>
                <pre><code id="textCode">${_escapeHtml(content.toText())}</code></pre>
            </div>
        </div>
    </div>

    <script>
        ${_getPreviewScript()}
    </script>
</body>
</html>
''';
  }

  static String _getPreviewStyles() {
    return '''
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: #f5f5f5;
            padding: 20px;
        }
        
        .flint-preview-container {
            max-width: 1200px;
            margin: 0 auto;
            background: white;
            border-radius: 12px;
            box-shadow: 0 4px 20px rgba(0,0,0,0.1);
            overflow: hidden;
        }
        
        .preview-header {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 24px;
            display: flex;
            justify-content: space-between;
            align-items: center;
            flex-wrap: wrap;
            gap: 16px;
        }
        
        .preview-header h1 {
            font-size: 24px;
            font-weight: 600;
        }
        
        .preview-controls {
            display: flex;
            gap: 12px;
            flex-wrap: wrap;
        }
        
        .preview-controls button {
            background: rgba(255,255,255,0.2);
            border: 1px solid rgba(255,255,255,0.3);
            color: white;
            padding: 8px 16px;
            border-radius: 6px;
            cursor: pointer;
            transition: all 0.2s;
            backdrop-filter: blur(10px);
        }
        
        .preview-controls button:hover {
            background: rgba(255,255,255,0.3);
            transform: translateY(-1px);
        }
        
        .device-preview {
            padding: 40px;
            background: #f8f9fa;
            min-height: 600px;
            display: flex;
            justify-content: center;
            align-items: flex-start;
        }
        
        .device-frame {
            background: white;
            border-radius: 12px;
            box-shadow: 0 8px 32px rgba(0,0,0,0.1);
            overflow: hidden;
            transition: all 0.3s ease;
        }
        
        .device-frame.desktop {
            width: 800px;
            max-width: 100%;
        }
        
        .device-frame.tablet {
            width: 600px;
        }
        
        .device-frame.mobile {
            width: 375px;
            border-radius: 24px;
            padding: 20px 0;
            position: relative;
        }
        
        .device-frame.mobile::before {
            content: '';
            position: absolute;
            top: 10px;
            left: 50%;
            transform: translateX(-50%);
            width: 60px;
            height: 4px;
            background: #e0e0e0;
            border-radius: 2px;
        }
        
        .email-content {
            width: 100%;
            min-height: 400px;
        }
        
        .preview-footer {
            padding: 24px;
            background: #f8f9fa;
            border-top: 1px solid #e9ecef;
        }
        
        .html-source, .text-source {
            margin-bottom: 24px;
        }
        
        .html-source h3, .text-source h3 {
            margin-bottom: 12px;
            color: #495057;
            font-size: 16px;
        }
        
        pre {
            background: #2d3748;
            color: #e2e8f0;
            padding: 16px;
            border-radius: 8px;
            overflow-x: auto;
            font-size: 14px;
            line-height: 1.5;
        }
        
        code {
            font-family: 'Monaco', 'Menlo', 'Ubuntu Mono', monospace;
        }
        
        @media (max-width: 768px) {
            .preview-header {
                flex-direction: column;
                text-align: center;
            }
            
            .device-preview {
                padding: 20px;
            }
            
            .device-frame.desktop,
            .device-frame.tablet,
            .device-frame.mobile {
                width: 100%;
            }
        }
    ''';
  }

  static String _getPreviewScript() {
    return '''
        function toggleDevice(device) {
            const preview = document.getElementById('devicePreview');
            const frames = preview.querySelectorAll('.device-frame');
            
            frames.forEach(frame => {
                frame.style.display = 'none';
                frame.classList.remove('active');
            });
            
            const activeFrame = preview.querySelector('.device-frame.' + device);
            if (activeFrame) {
                activeFrame.style.display = 'block';
                activeFrame.classList.add('active');
            }
            
            // Update active button state
            document.querySelectorAll('.preview-controls button').forEach(btn => {
                btn.style.background = btn.textContent.toLowerCase().includes(device) 
                    ? 'rgba(255,255,255,0.4)' 
                    : 'rgba(255,255,255,0.2)';
            });
        }
        
        function copyHtml() {
            const htmlCode = document.getElementById('htmlCode').textContent;
            navigator.clipboard.writeText(htmlCode).then(() => {
                alert('HTML copied to clipboard!');
            });
        }
        
        function downloadHtml() {
            const htmlCode = document.getElementById('htmlCode').textContent;
            const blob = new Blob([htmlCode], { type: 'text/html' });
            const url = URL.createObjectURL(blob);
            const a = document.createElement('a');
            a.href = url;
            a.download = 'flint-template.html';
            document.body.appendChild(a);
            a.click();
            document.body.removeChild(a);
            URL.revokeObjectURL(url);
        }
        
        // Initialize with desktop view
        toggleDevice('desktop');
    ''';
  }

  static String _escapeHtml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;')
        .replaceAll('\n', '<br>')
        .replaceAll(' ', '&nbsp;');
  }
}
