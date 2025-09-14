#!/bin/bash

# Development script to fix TCC permission issues for ScreenRead
echo "🔄 Fixing TCC permissions for ScreenRead development..."

BUNDLE_ID="com.JaneshKapoor.ScreenRead"

# Kill the app if it's running
echo "🛑 Stopping ScreenRead if running..."
pkill -f "ScreenRead" 2>/dev/null || true

# Reset screen capture permission
echo "🔄 Resetting screen capture permissions..."
sudo tccutil reset ScreenCapture $BUNDLE_ID

# Wait a moment
sleep 1

# Try to pre-approve the permission (this might not work on all systems)
echo "🔧 Attempting to pre-approve permission..."
sudo sqlite3 /Library/Application\ Support/com.apple.TCC/TCC.db "INSERT OR REPLACE INTO access VALUES('kTCCServiceScreenCapture','$BUNDLE_ID',0,2,2,1,NULL,NULL,0,'UNUSED',NULL,0,1687276800);" 2>/dev/null || echo "⚠️ Pre-approval failed (this is normal on some systems)"

echo ""
echo "✅ Permissions reset complete!"
echo ""
echo "📋 Next steps:"
echo "1. Run the ScreenRead app"
echo "2. When prompted, grant screen recording permission"
echo "3. The permission should now persist for this build"
echo ""
echo "💡 If the issue persists, you may need to:"
echo "   - Manually remove ScreenRead from System Settings > Privacy & Security > Screen Recording"
echo "   - Restart the app and grant permission again"