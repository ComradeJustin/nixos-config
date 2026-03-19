# Fix btop SVG icon that uses patterns Qt's SVG renderer can't handle
final: prev: {
  btop = prev.btop.overrideAttrs (oldAttrs: {
    postInstall = (oldAttrs.postInstall or "") + ''
      # Replace the complex SVG with a simpler version that Qt can render
      cat > $out/share/icons/hicolor/scalable/apps/btop.svg << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 96 96" width="96" height="96">
  <rect x="2" y="7" width="52" height="83" rx="2" fill="#1a1a2e" stroke="#4a4a6a" stroke-width="2"/>
  <rect x="47" y="23" width="7" height="19" fill="#1a1a2e" stroke="#4a4a6a" stroke-width="1"/>
  <rect x="47" y="42" width="7" height="13" fill="#1a1a2e" stroke="#4a4a6a" stroke-width="1"/>
  <rect x="47" y="55" width="7" height="19" fill="#1a1a2e" stroke="#4a4a6a" stroke-width="1"/>
  <rect x="19" y="26" width="18" height="13" fill="#16c60c" rx="1"/>
  <rect x="19" y="58" width="18" height="13" fill="#3b78ff" rx="1"/>
  <rect x="8" y="15" width="6" height="3" fill="#e74856"/>
  <rect x="16" y="15" width="6" height="3" fill="#f9f1a5"/>
  <rect x="24" y="15" width="6" height="3" fill="#16c60c"/>
</svg>
EOF
    '';
  });
}
