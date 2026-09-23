# Assets

`icon-1024.png` es la fuente maestra del ícono de la app (1024×1024, con alpha real en las
esquinas — no un JPG opaco). `AppIcon.icns` en la raíz del repo se generó a partir de este
PNG con `sips` + `iconutil` (ver `build-app.sh`, o los pasos manuales abajo).

## Cómo se generó

1. Imagen base con MiniMax (`mmx image generate`), prompt pidiendo una gota de agua
   estilizada con líneas de circuito, full-bleed, sin mockup de tarjeta.
2. El modelo igual devolvió un mockup de icono con esquinas redondeadas y margen blanco
   (comportamiento típico de estos modelos para prompts de "app icon"). Se recortó el
   margen blanco y se aplicó una máscara alfa de esquinas redondeadas (squircle) con
   Pillow para dejar las esquinas transparentes de verdad, en vez de blancas.

## Regenerar el `.icns` desde `icon-1024.png`

```sh
cd Assets
mkdir -p icon.iconset
sips -z 16 16     icon-1024.png --out icon.iconset/icon_16x16.png
sips -z 32 32     icon-1024.png --out icon.iconset/icon_16x16@2x.png
sips -z 32 32     icon-1024.png --out icon.iconset/icon_32x32.png
sips -z 64 64     icon-1024.png --out icon.iconset/icon_32x32@2x.png
sips -z 128 128   icon-1024.png --out icon.iconset/icon_128x128.png
sips -z 256 256   icon-1024.png --out icon.iconset/icon_128x128@2x.png
sips -z 256 256   icon-1024.png --out icon.iconset/icon_256x256.png
sips -z 512 512   icon-1024.png --out icon.iconset/icon_256x256@2x.png
sips -z 512 512   icon-1024.png --out icon.iconset/icon_512x512.png
cp icon-1024.png icon.iconset/icon_512x512@2x.png
iconutil -c icns icon.iconset -o ../AppIcon.icns
rm -r icon.iconset
```
