#!/bin/zsh
# Réinstalle Veille Monde sur l'iPhone branché (à refaire tous les 7 jours
# avec un compte Apple gratuit). Double-cliquer sur ce fichier pour le lancer.

DIR="${0:A:h}"
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
# Compilé hors de Documents : la synchro iCloud ajoute des attributs que la signature refuse.
BUILD="$HOME/Library/Caches/VeilleMonde-build"
APP="$BUILD/Build/Products/Release-iphoneos/VeilleMonde.app"

finish() {
    echo
    read -k 1 "?Appuie sur une touche pour fermer cette fenêtre…"
    exit $1
}

clear
echo "📰  Réinstallation de Veille Monde"
echo "──────────────────────────────────"
echo

echo "1/3  Recherche de l'iPhone…"
UDID=$(xcrun devicectl list devices 2>/dev/null | grep -i iphone | grep physical | grep connected \
    | grep -oE '[0-9A-F]{8}-[0-9A-F]{16}' | head -1)
if [[ -z "$UDID" ]]; then
    echo "❌  Aucun iPhone détecté."
    echo "    Branche l'iPhone avec le câble, déverrouille-le, puis relance ce fichier."
    finish 1
fi
echo "     ✓ iPhone trouvé"

echo "2/3  Préparation de l'app (1 à 2 minutes)…"
if ! xcodebuild -project "$DIR/VeilleMonde/VeilleMonde.xcodeproj" -scheme VeilleMonde -configuration Release \
        -destination "id=$UDID" -derivedDataPath "$BUILD" \
        -allowProvisioningUpdates -allowProvisioningDeviceRegistration \
        -quiet build > "$BUILD.log" 2>&1; then
    echo "❌  La préparation a échoué. Détails :"
    grep -E "error" "$BUILD.log" | head -5
    echo
    echo "    Vérifie que l'iPhone est déverrouillé et que ton compte Apple"
    echo "    est toujours connecté dans Xcode (Xcode → Settings → Accounts)."
    finish 1
fi
echo "     ✓ App prête"

echo "3/3  Installation sur l'iPhone…"
if ! xcrun devicectl device install app --device "$UDID" "$APP" > /dev/null 2>&1; then
    echo "❌  L'installation a échoué. Garde l'iPhone déverrouillé et réessaie."
    finish 1
fi
xcrun devicectl device process launch --device "$UDID" com.jrbodard.veillemonde > /dev/null 2>&1
echo "     ✓ Installée"

echo
echo "✅  C'est fait ! Veille Monde fonctionne pour 7 jours de plus."
finish 0
