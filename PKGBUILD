# Maintainer: ali3nated0 <ali3nated0@github>

pkgname=ocrme
pkgver=0.1.0
pkgrel=1
pkgdesc="A multi-platform OCR application for extracting text from images"
arch=('x86_64' 'aarch64')
url="https://github.com/ALi3naTEd0/OCRMe"
license=('MIT')
depends=('tesseract' 'leptonica' 'gtk3' 'libsecret')
makedepends=('flutter' 'ninja' 'clang' 'cmake' 'pkg-config')
source=("git+https://github.com/ALi3naTEd0/OCRMe.git")
sha256sums=('SKIP')
options=('!strip')

prepare() {
  cd "${srcdir}/OCRMe"
  # Clone Flutter submodules if needed
  flutter pub get
}

build() {
  cd "${srcdir}/OCRMe"
  flutter build linux --release
}

package() {
  cd "${srcdir}/OCRMe"

  # Create directories
  install -dm755 "${pkgdir}/usr/lib"
  install -dm755 "${pkgdir}/usr/bin"
  install -dm755 "${pkgdir}/usr/share/applications"
  install -dm755 "${pkgdir}/usr/share/icons/hicolor/scalable/apps"
  install -dm755 "${pkgdir}/usr/share/licenses/${pkgname}"

  # Copy the Flutter build to /usr/lib/ocrme
  cp -r build/linux/x64/release/bundle "${pkgdir}/usr/lib/${pkgname}"

  # Create launcher script
  cat > "${pkgdir}/usr/bin/${pkgname}" << EOF
#!/bin/sh
exec /usr/lib/${pkgname}/ocrme "\$@"
EOF
  chmod 755 "${pkgdir}/usr/bin/${pkgname}"

  # Install desktop file
  cat > "${pkgdir}/usr/share/applications/${pkgname}.desktop" << EOF
[Desktop Entry]
Type=Application
Name=OCRMe
GenericName=OCR Application
Comment=Extract text from images using OCR
Exec=${pkgname}
Icon=${pkgname}
Terminal=false
Categories=Graphics;Utility;TextTools;
Keywords=OCR;Text;Recognition;Extract;
StartupNotify=true
EOF

  # Create SVG icon from assets
  cp "assets/logo.svg" "${pkgdir}/usr/share/icons/hicolor/scalable/apps/${pkgname}.svg"

  # Add license
  install -Dm644 LICENSE "${pkgdir}/usr/share/licenses/${pkgname}/LICENSE"
}
