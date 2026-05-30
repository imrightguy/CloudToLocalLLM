# GitHub Secrets à ajouter pour Android Build

Aller sur https://github.com/CloudToLocalLLM-online/CloudToLocalLLM/settings/secrets/actions

Ajouter ces 4 secrets:

| Nom | Valeur |
|-----|--------|
| `ANDROID_KEYSTORE_B64` | Le contenu du fichier (base64 du keystore) — voir ci-dessous |
| `ANDROID_STORE_PASSWORD` | `Cloud2LocalLLM!2026` |
| `ANDROID_KEY_PASSWORD` | `Cloud2LocalLLM!2026` |
| `ANDROID_KEY_ALIAS` | `zoidbot-release` |

## Pour ANDROID_KEYSTORE_B64

Sur RIGHT-PC:
```bash
base64 -w0 ~/CloudToLocalLLM/android/release-keystore.jks | wl-copy  # ou xclip
```

Puis coller dans le champ GitHub.

## Prochain push sur main

Après ça, n'importe quel push sur `main` qui touche `lib/` va trigger le deployment workflow complet — Linux, Windows, **et Android APK** dans les releases.
