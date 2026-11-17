# Cómo publicar una versión

Procedimiento para sacar una versión nueva y dejarla disponible en el descargador
(https://usuario01-bit.github.io/kiosco_app/).

El target real es **Android**. La app se instala a mano en el celular, así que lo que se
publica es el APK release.

## Antes de empezar

- `gh` CLI **no está instalado** en esta máquina. El release se crea con la API de GitHub
  usando el token que ya tiene guardado Git Credential Manager (el mismo del `git push`).
  No hace falta pegar ningún token a mano.
- No correr `flutter build windows`: no hay toolchain de Visual Studio y no es el target.
- En PowerShell, `flutter` y `git` escriben warnings por stderr y el pipe devuelve
  `Exit code 1` aunque el comando haya funcionado. **Mirá el mensaje, no el exit code.**

## Paso 1 — Subir la versión en `pubspec.yaml`

```yaml
version: 1.4.9+18
#        ^^^^^ ^^
#        |     versionCode de Android: siempre +1, nunca repetir
#        versionName: lo que ve el usuario
```

Si el `versionCode` no sube, el celular no ofrece la actualización.

## Paso 2 — Compilar el APK

```sh
flutter build apk --release
```

Tarda ~60s. Verificar que diga:

```
√ Built build\app\outputs\flutter-apk\app-release.apk (86.2MB)
```

## Paso 3 — Actualizar la etiqueta de la página

En `docs/index.html`:

```html
<p class="version">v1.4.9</p>
```

## Paso 4 — Commit y push

```sh
git add -A
git commit -m "chore(release): v1.4.9"
git push origin <branch>
```

## Paso 5 — Tag

```sh
git tag v1.4.9
git push origin v1.4.9
```

## Paso 6 — Crear el release con el APK

El botón de la página apunta a
`releases/latest/download/app-release.apk`, así que el asset **tiene que llamarse exactamente
`app-release.apk`**.

```powershell
cd C:\Users\axion\kiosco_app
$raw = "protocol=https`nhost=github.com`n`n" | git credential fill 2>$null
$tok = ($raw | Select-String -Pattern '^password=(.+)$').Matches.Groups[1].Value
$H = @{ Authorization = "Bearer $tok"; "User-Agent" = "kiosco" }

$body = @{
  tag_name = "v1.4.9"
  name     = "v1.4.9"
  body     = "Qué cambió en esta versión."
  draft    = $false
  prerelease = $false
} | ConvertTo-Json

$rel = Invoke-RestMethod -Method Post `
  -Uri "https://api.github.com/repos/Usuario01-bit/kiosco_app/releases" `
  -Headers $H -Body $body -ContentType "application/json"

$up = $rel.upload_url -replace '\{\?name,label\}', '?name=app-release.apk'
$apk = (Resolve-Path "build\app\outputs\flutter-apk\app-release.apk").Path

Invoke-RestMethod -Method Post -Uri $up `
  -Headers @{ Authorization = "Bearer $tok"; "User-Agent" = "kiosco" } `
  -ContentType "application/vnd.android.package-archive" -InFile $apk -TimeoutSec 900
```

Verificar que el release quedó como `latest`:

```powershell
(Invoke-RestMethod -Uri "https://api.github.com/repos/Usuario01-bit/kiosco_app/releases/latest" -Headers $H).tag_name
```

## Paso 7 — Que la página publique la etiqueta nueva

**GitHub Pages sirve `master` / `docs`.** Un commit en otra branch no actualiza la página.
Después de pushear el cambio de `docs/index.html` hay que llevarlo a `master`:

```sh
git checkout master
git pull --ff-only origin master
git merge --ff-only <branch>
git push origin master
git checkout <branch>
```

El release y el APK funcionan aunque este paso falte; lo único que queda viejo es el texto
de la versión en la página.

## Verificación final

```sh
curl.exe -sIL -o NUL -w "%{http_code}`n" "https://github.com/Usuario01-bit/kiosco_app/releases/latest/download/app-release.apk"
```

Tiene que dar **200**. Y abrir https://usuario01-bit.github.io/kiosco_app/ para confirmar
que muestra la versión nueva.
